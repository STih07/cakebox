module PageFactory.Trading.State
  ( TradingState
  , addTradingTicker
  , defaultTradingSymbols
  , newTradingState
  , readTradingSymbols
  , removeTradingTicker
  ) where

-- Small in-memory backend state for the AI Trading module.

import Control.Concurrent.STM (TVar, atomically, modifyTVar', newTVarIO, readTVar)
import Data.Char (isAlphaNum, toUpper)
import Data.List (nub)

newtype TradingState = TradingState (TVar [String])

defaultTradingSymbols :: [String]
defaultTradingSymbols = ["NVDA", "AMD", "TSLA", "RKLB"]

newTradingState :: IO TradingState
newTradingState = TradingState <$> newTVarIO defaultTradingSymbols

readTradingSymbols :: TradingState -> IO [String]
readTradingSymbols (TradingState symbolsVar) =
  atomically (readTVar symbolsVar)

addTradingTicker :: TradingState -> String -> IO (Either String [String])
addTradingTicker (TradingState symbolsVar) rawSymbol =
  case normalizeSymbol rawSymbol of
    Nothing ->
      pure (Left "Ticker symbol must be 1-8 letters or digits")
    Just symbol ->
      atomically $ do
        symbols <- readTVar symbolsVar
        let nextSymbols = nub (symbols <> [symbol])
        modifyTVar' symbolsVar (const nextSymbols)
        pure (Right nextSymbols)

removeTradingTicker :: TradingState -> String -> IO (Either String [String])
removeTradingTicker (TradingState symbolsVar) rawSymbol =
  case normalizeSymbol rawSymbol of
    Nothing ->
      pure (Left "Ticker symbol must be 1-8 letters or digits")
    Just symbol ->
      atomically $ do
        symbols <- readTVar symbolsVar
        if symbol `elem` symbols
          then do
            let nextSymbols = filter (/= symbol) symbols
            modifyTVar' symbolsVar (const nextSymbols)
            pure (Right nextSymbols)
          else
            pure (Left ("Ticker " <> symbol <> " is not in the watchlist"))

normalizeSymbol :: String -> Maybe String
normalizeSymbol rawSymbol =
  let symbol = map toUpper (filter (/= ' ') rawSymbol)
   in if not (null symbol) && length symbol <= 8 && all isAlphaNum symbol
        then Just symbol
        else Nothing
