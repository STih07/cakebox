{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Trading.Actions
  ( executeTradingTool
  , tradingToolSchemas
  ) where

-- Agent-addressable capabilities exposed by the AI Trading fragment.

import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Chat.Extension (ExtensionExecution (..), ToolSchema)
import PageFactory.Chat.Operations (OperationArg (..), fragmentRenderedEvent, navigateEvent, operationToolSchema, stateUpdatedEvent)
import PageFactory.Engine.Html (renderHtml)
import PageFactory.Trading.DataSource (loadTickerQuotes)
import PageFactory.Trading.State (TradingState, addTradingTicker, readTradingSymbols, removeTradingTicker)
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
  , removeTradingTickerTool
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
  | toolCallName call == "remove_trading_ticker" =
      Just <$> removeTicker
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

    removeTicker =
      case parseTradingTickerArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad remove_trading_ticker arguments: " <> err) []
        Right args -> do
          updateResult <- removeTradingTicker tradingState (tradingSymbol args)
          case updateResult of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right _ -> refreshTradingPanel ("OK: Removed " <> tradingSymbol args <> " from AI Trading tickers")

    openedTradingTickers =
      let finalNote = "OK: Opened AI Trading tickers"
       in pureExecution
            finalNote
            [ navigateEvent "/ai-trading/tickers" "AI Trading / Тикеры" finalNote
            , stateUpdatedEvent ["currentModule" .= ("AI Trading" :: String), "currentTab" .= ("Тикеры" :: String), "note" .= finalNote]
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
          [ fragmentRenderedEvent "trading-panel" "AI Trading / Тикеры" html
          , stateUpdatedEvent ["tradingSymbols" .= symbols, "note" .= content]
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
  operationToolSchema "open_trading_tickers" "Open the AI Trading tickers module in the main Haskell page surface." []

addTradingTickerTool :: ToolSchema
addTradingTickerTool =
  operationToolSchema "add_trading_ticker" "Add a ticker symbol to the displayed AI Trading watchlist and re-render the trading panel." [symbolArg]

removeTradingTickerTool :: ToolSchema
removeTradingTickerTool =
  operationToolSchema "remove_trading_ticker" "Remove a ticker symbol from the displayed AI Trading watchlist and re-render the trading panel." [symbolArg]

refreshTradingQuotesTool :: ToolSchema
refreshTradingQuotesTool =
  operationToolSchema "refresh_trading_quotes" "Refresh the displayed AI Trading ticker fragment from the current backend watchlist." []

symbolArg :: OperationArg
symbolArg =
  OperationArg "symbol" "Ticker symbol, for example PLTR, AAPL, MSFT." True
