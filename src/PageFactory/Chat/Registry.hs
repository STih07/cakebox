module PageFactory.Chat.Registry
  ( enabledExtensions
  ) where

-- Enabled chat extensions for the current application.

import PageFactory.Chat.Extension (ChatExtension)
import PageFactory.ModelBuilder.Extension (modelBuilderExtension)
import PageFactory.ModelBuilder.Store (ModelStore)
import PageFactory.Sandbox.Extension (sandboxExtension)
import PageFactory.Sandbox.Store (SandboxStore)
import PageFactory.Trading.Extension (tradingExtension)
import PageFactory.Trading.State (TradingState)

enabledExtensions :: TradingState -> SandboxStore -> ModelStore -> [ChatExtension]
enabledExtensions tradingState sandboxStore modelStore =
  [ tradingExtension tradingState
  , sandboxExtension sandboxStore
  , modelBuilderExtension modelStore
  ]
