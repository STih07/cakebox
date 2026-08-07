{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Trading.DataSource
  ( TickerQuote (..)
  , loadTickerQuotes
  ) where

-- Market data providers for the AI Trading module.

import Control.Exception (SomeException, try)
import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:))
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import Network.HTTP.Client
  ( Request (..)
  , Response (..)
  , httpLbs
  , parseRequest
  , requestHeaders
  , responseBody
  , responseStatus
  )
import Network.HTTP.Client.TLS (newTlsManager)
import Network.HTTP.Types.Status (statusCode)
import System.Environment (lookupEnv)
import Text.Printf (printf)

data TickerQuote = TickerQuote
  { quoteSymbol :: String
  , quoteTheme :: String
  , quotePrice :: String
  , quoteLabel :: String
  , quoteIsLive :: Bool
  }
  deriving (Eq, Show)

loadTickerQuotes :: [String] -> IO (Either String [TickerQuote])
loadTickerQuotes symbols = do
  maybeConfig <- alpacaConfig
  case maybeConfig of
    Nothing -> pure (Left "Alpaca env is not configured: ALPACA_API_KEY_ID, ALPACA_API_SECRET_KEY, ALPACA_DATA_URL")
    Just config -> do
      result <- fetchAlpacaTrades config symbols
      pure (mergeLive symbols <$> result)

data AlpacaConfig = AlpacaConfig
  { alpacaKeyId :: String
  , alpacaSecretKey :: String
  , alpacaDataUrl :: String
  }

alpacaConfig :: IO (Maybe AlpacaConfig)
alpacaConfig = do
  keyId <- lookupEnv "ALPACA_API_KEY_ID"
  secretKey <- lookupEnv "ALPACA_API_SECRET_KEY"
  dataUrl <- lookupEnv "ALPACA_DATA_URL"
  pure $ AlpacaConfig <$> keyId <*> secretKey <*> fmap normalizeBaseUrl dataUrl

normalizeBaseUrl :: String -> String
normalizeBaseUrl url =
  reverse (dropWhile (== '/') (reverse url))

data AlpacaTradesResponse = AlpacaTradesResponse (Map.Map String AlpacaTrade)

instance FromJSON AlpacaTradesResponse where
  parseJSON =
    withObject "AlpacaTradesResponse" $ \value ->
      AlpacaTradesResponse <$> value .: "trades"

data AlpacaTrade = AlpacaTrade
  { tradePrice :: Double
  }

instance FromJSON AlpacaTrade where
  parseJSON =
    withObject "AlpacaTrade" $ \value ->
      AlpacaTrade <$> value .: "p"

fetchAlpacaTrades :: AlpacaConfig -> [String] -> IO (Either String (Map.Map String AlpacaTrade))
fetchAlpacaTrades config symbols = do
  manager <- newTlsManager
  baseRequest <- parseRequest url
  let request =
        baseRequest
          { requestHeaders =
              [ ("APCA-API-KEY-ID", BS8.pack (alpacaKeyId config))
              , ("APCA-API-SECRET-KEY", BS8.pack (alpacaSecretKey config))
              ]
          }
  result <- try (httpLbs request manager) :: IO (Either SomeException (Response LBS.ByteString))
  pure $
    case result of
      Left err -> Left (show err)
      Right response
        | statusCode (responseStatus response) >= 300 ->
            Left ("Alpaca returned HTTP " <> show (statusCode (responseStatus response)))
        | otherwise ->
            case eitherDecode (responseBody response) of
              Left err -> Left err
              Right (AlpacaTradesResponse trades) -> Right trades
  where
    url = alpacaDataUrl config <> "/stocks/trades/latest?symbols=" <> intercalate "," symbols

mergeLive :: [String] -> Map.Map String AlpacaTrade -> [TickerQuote]
mergeLive symbols trades =
  map quoteFor symbols
  where
    quoteFor symbol =
      case Map.lookup symbol trades of
        Just trade ->
          TickerQuote symbol (tickerTheme symbol) (formatUsd (tradePrice trade)) "Live" True
        Nothing ->
          TickerQuote symbol (tickerTheme symbol) "No trade" "Unavailable" False

tickerTheme :: String -> String
tickerTheme symbol =
  case symbol of
    "NVDA" -> "AI compute"
    "AMD" -> "Semis"
    "TSLA" -> "Volatility"
    "RKLB" -> "Space beta"
    "PLTR" -> "AI data"
    "AAPL" -> "Mega cap"
    "MSFT" -> "Cloud"
    _ -> "Watchlist"

formatUsd :: Double -> String
formatUsd value = "$" <> printf "%.2f" value
