{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Trading.Actions
  ( executeTradingTool
  ) where

-- Agent-addressable capabilities exposed by the AI Trading fragment.

import Data.Aeson (FromJSON (..), Value, eitherDecode, object, withObject, (.:), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Engine.Html (renderHtml)
import PageFactory.Trading.DataSource (loadTickerQuotes)
import PageFactory.Trading.State (TradingState, addTradingTicker, readTradingSymbols)
import PageFactory.Trading.View (tradingPanel)

data TradingTickerArgs = TradingTickerArgs
  { tradingSymbol :: String
  }
  deriving (Eq, Show)

instance FromJSON TradingTickerArgs where
  parseJSON =
    withObject "TradingTickerArgs" $ \value ->
      TradingTickerArgs <$> value .: "symbol"

executeTradingTool :: TradingState -> ToolCall -> Maybe (IO (String, [(String, Value)]))
executeTradingTool tradingState call
  | toolCallName call == "open_trading_tickers" =
      Just (pure openedTradingTickers)
  | toolCallName call == "refresh_trading_quotes" =
      Just (refreshTradingPanel "OK: Refreshed AI Trading tickers")
  | toolCallName call == "add_trading_ticker" =
      Just addTicker
  | otherwise =
      Nothing
  where
    addTicker =
      case parseTradingTickerArgs (toolCallArguments call) of
        Left err -> pure ("ERROR: Bad add_trading_ticker arguments: " <> err, [])
        Right args -> do
          updateResult <- addTradingTicker tradingState (tradingSymbol args)
          case updateResult of
            Left message -> pure ("ERROR: " <> message, [])
            Right _ -> refreshTradingPanel ("OK: Added " <> tradingSymbol args <> " to AI Trading tickers")

    openedTradingTickers =
      let finalNote = "OK: Opened AI Trading tickers"
       in ( finalNote
          ,
            [ ( "ui.action"
              , object
                  [ "action" .= ("navigate" :: String)
                  , "url" .= ("/ai-trading/tickers" :: String)
                  , "label" .= ("AI Trading / Тикеры" :: String)
                  , "note" .= finalNote
                  ]
              )
            , ( "state.updated"
              , object
                  [ "currentModule" .= ("AI Trading" :: String)
                  , "currentTab" .= ("Тикеры" :: String)
                  , "note" .= finalNote
                  ]
              )
            ]
          )

    refreshTradingPanel finalNote = do
      symbols <- readTradingSymbols tradingState
      quotesResult <- loadTickerQuotes symbols
      let html = renderHtml (tradingPanel quotesResult)
          content =
            case quotesResult of
              Left message -> "ERROR: " <> message
              Right _ -> finalNote
      pure
        ( content
        ,
          [ ( "fragment.rendered"
            , object
                [ "target" .= ("trading-panel" :: String)
                , "label" .= ("AI Trading / Тикеры" :: String)
                , "html" .= html
                ]
            )
          , ( "state.updated"
            , object
                [ "tradingSymbols" .= symbols
                , "note" .= content
                ]
            )
          ]
        )

parseTradingTickerArgs :: String -> Either String TradingTickerArgs
parseTradingTickerArgs =
  eitherDecode . LBS.pack
