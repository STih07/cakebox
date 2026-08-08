{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Trading.Actions
  ( executeTradingTool
  , tradingToolSchemas
  ) where

-- Agent-addressable capabilities exposed by the AI Trading fragment.

import Data.Aeson (FromJSON (..), eitherDecode, object, withObject, (.:), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Chat.Extension (ExtensionExecution (..), ToolSchema)
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

tradingToolSchemas :: [ToolSchema]
tradingToolSchemas =
  [ openTradingTickersTool
  , addTradingTickerTool
  , refreshTradingQuotesTool
  ]

executeTradingTool :: TradingState -> ToolCall -> IO (Maybe ExtensionExecution)
executeTradingTool tradingState call
  | toolCallName call == "open_trading_tickers" =
      Just <$> openedTradingTickers
  | toolCallName call == "refresh_trading_quotes" =
      Just <$> refreshTradingPanel "OK: Refreshed AI Trading tickers"
  | toolCallName call == "add_trading_ticker" =
      Just <$> addTicker
  | otherwise =
      pure Nothing
  where
    addTicker =
      case parseTradingTickerArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad add_trading_ticker arguments: " <> err) []
        Right args -> do
          updateResult <- addTradingTicker tradingState (tradingSymbol args)
          case updateResult of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right _ -> refreshTradingPanel ("OK: Added " <> tradingSymbol args <> " to AI Trading tickers")

    openedTradingTickers =
      let finalNote = "OK: Opened AI Trading tickers"
       in pureExecution
            finalNote
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

    refreshTradingPanel finalNote = do
      symbols <- readTradingSymbols tradingState
      quotesResult <- loadTickerQuotes symbols
      let html = renderHtml (tradingPanel quotesResult)
          content =
            case quotesResult of
              Left message -> "ERROR: " <> message
              Right _ -> finalNote
      pureExecution
        content
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

    pureExecution content events =
      pure
        ExtensionExecution
          { extensionExecutionContent = content
          , extensionExecutionEvents = events
          }

parseTradingTickerArgs :: String -> Either String TradingTickerArgs
parseTradingTickerArgs =
  eitherDecode . LBS.pack

openTradingTickersTool :: ToolSchema
openTradingTickersTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("open_trading_tickers" :: String)
          , "description" .= ("Open the AI Trading tickers module in the main Haskell page surface." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties" .= object []
                , "additionalProperties" .= False
                ]
          ]
    ]

addTradingTickerTool :: ToolSchema
addTradingTickerTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("add_trading_ticker" :: String)
          , "description" .= ("Add a ticker symbol to the AI Trading watchlist and re-render the trading panel." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties"
                    .= object
                      [ "symbol" .= object ["type" .= ("string" :: String), "description" .= ("Ticker symbol, for example PLTR, AAPL, MSFT." :: String)]
                      ]
                , "required" .= (["symbol"] :: [String])
                , "additionalProperties" .= False
                ]
          ]
    ]

refreshTradingQuotesTool :: ToolSchema
refreshTradingQuotesTool =
  object
    [ "type" .= ("function" :: String)
    , "function"
        .= object
          [ "name" .= ("refresh_trading_quotes" :: String)
          , "description" .= ("Refresh live Alpaca quotes for the current AI Trading watchlist and re-render the trading panel." :: String)
          , "parameters"
              .= object
                [ "type" .= ("object" :: String)
                , "properties" .= object []
                , "additionalProperties" .= False
                ]
          ]
    ]
