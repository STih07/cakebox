module PageFactory.Chat.Registry
  ( enabledExtensions
  ) where

-- Enabled chat extensions for the current application.

import PageFactory.Chat.Extension (ChatExtension)
import PageFactory.Sandbox.Extension (sandboxExtension)
import PageFactory.Sandbox.Store (SandboxStore)
import PageFactory.Trading.Extension (tradingExtension)
import PageFactory.Trading.State (TradingState)

enabledExtensions :: TradingState -> SandboxStore -> [ChatExtension]
enabledExtensions tradingState sandboxStore =
  [ tradingExtension tradingState
  , sandboxExtension sandboxStore
  ]
