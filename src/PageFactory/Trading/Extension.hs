module PageFactory.Trading.Extension
  ( tradingExtension
  ) where

-- Chat extension definition for the AI Trading module.

import Data.List (intercalate)
import PageFactory.Chat.Extension (ChatExtension (..))
import PageFactory.Chat.Operations (entityOperationContext)
import PageFactory.Trading.Actions (executeTradingTool, tradingToolSchemas)
import PageFactory.Trading.State (TradingState, readTradingSymbols)

tradingExtension :: TradingState -> ChatExtension
tradingExtension tradingState =
  ChatExtension
    { extensionId = "ai-trading"
    , extensionTitle = "AI Trading"
    , extensionPromptContext = tradingPromptContext tradingState
    , extensionToolSchemas = tradingToolSchemas
    , extensionExecuteTool = executeTradingTool tradingState
    }

tradingPromptContext :: TradingState -> IO String
tradingPromptContext tradingState = do
  symbols <- readTradingSymbols tradingState
  pure $
    unlines
      [ "Extension: AI Trading"
      , "Visible route: /ai-trading/tickers"
      , "Fragment slot: trading-panel"
      , "Watchlist: " <> intercalate ", " symbols
      , entityOperationContext "displayed tickers" "/ai-trading/tickers" "trading-panel" ["open_trading_tickers", "add_trading_ticker", "remove_trading_ticker", "refresh_trading_quotes"]
      , "Capabilities: open_trading_tickers, add_trading_ticker, remove_trading_ticker, refresh_trading_quotes"
      ]
