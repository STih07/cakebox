{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module PageFactory.AgUi.Input
  ( RunAgentInput (..)
  , RunMessage (..)
  , defaultRunAgentInput
  ) where

-- Minimal AG-UI RunAgentInput parser for POST /ag-ui/runs.

import Data.Aeson (FromJSON (..), withObject, (.:), (.:?), (.!=))
import GHC.Generics (Generic)

data RunMessage = RunMessage
  { messageRole :: String
  , messageContent :: String
  }
  deriving (Eq, Show, Generic)

instance FromJSON RunMessage where
  parseJSON =
    withObject "RunMessage" $ \value ->
      RunMessage
        <$> value .: "role"
        <*> value .: "content"

data RunAgentInput = RunAgentInput
  { inputThreadId :: String
  , inputRunId :: Maybe String
  , inputMessages :: [RunMessage]
  }
  deriving (Eq, Show, Generic)

instance FromJSON RunAgentInput where
  parseJSON =
    withObject "RunAgentInput" $ \value ->
      RunAgentInput
        <$> value .: "threadId"
        <*> value .:? "runId"
        <*> (value .:? "messages" .!= [])

defaultRunAgentInput :: RunAgentInput
defaultRunAgentInput =
  RunAgentInput
    { inputThreadId = "thread_layered_html_demo"
    , inputRunId = Just "run_demo_1"
    , inputMessages = []
    }
