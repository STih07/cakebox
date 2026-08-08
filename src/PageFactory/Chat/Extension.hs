{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Chat.Extension
  ( ChatExtension (..)
  , ExtensionExecution (..)
  , PromptContext
  , ToolSchema
  , runExtensionTool
  ) where

-- Extension contract used by the agent chat runtime.

import Data.Aeson (Value)
import PageFactory.Ai.Provider.OpenAICompat (ToolCall)

type PromptContext = String

type ToolSchema = Value

data ExtensionExecution = ExtensionExecution
  { extensionExecutionContent :: String
  , extensionExecutionEvents :: [(String, Value)]
  }
  deriving (Eq, Show)

data ChatExtension = ChatExtension
  { extensionId :: String
  , extensionTitle :: String
  , extensionPromptContext :: IO PromptContext
  , extensionToolSchemas :: [ToolSchema]
  , extensionExecuteTool :: ToolCall -> IO (Maybe ExtensionExecution)
  }

runExtensionTool :: [ChatExtension] -> ToolCall -> IO (Maybe ExtensionExecution)
runExtensionTool [] _ = pure Nothing
runExtensionTool (extension : extensions) call = do
  result <- extensionExecuteTool extension call
  case result of
    Just execution -> pure (Just execution)
    Nothing -> runExtensionTool extensions call
