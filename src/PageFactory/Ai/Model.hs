module PageFactory.Ai.Model
  ( AgentEvent (..)
  , MessageId (..)
  , RunId (..)
  , ThreadId (..)
  ) where

-- Internal AI runtime types. These are independent from AG-UI wire events.

import Data.Aeson (Value)

newtype ThreadId = ThreadId {unThreadId :: String}
  deriving (Eq, Show)

newtype RunId = RunId {unRunId :: String}
  deriving (Eq, Show)

newtype MessageId = MessageId {unMessageId :: String}
  deriving (Eq, Show)

data AgentEvent
  = AgentRunStarted ThreadId RunId
  | AgentTextStarted MessageId
  | AgentTextDelta MessageId String
  | AgentTextFinished MessageId
  | AgentToolStarted String String
  | AgentToolFinished String String
  | AgentCustomEvent String Value
  | AgentRunFinished ThreadId RunId
  deriving (Eq, Show)
