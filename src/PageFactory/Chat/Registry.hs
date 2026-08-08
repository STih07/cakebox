module PageFactory.Chat.Registry
  ( enabledExtensions
  ) where

-- Enabled chat extensions for the current application.

import PageFactory.Chat.Extension (ChatExtension)
import PageFactory.Trading.Extension (tradingExtension)
import PageFactory.Trading.State (TradingState)

enabledExtensions :: TradingState -> [ChatExtension]
enabledExtensions tradingState =
  [ tradingExtension tradingState
  ]
