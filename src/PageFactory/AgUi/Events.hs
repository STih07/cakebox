{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module PageFactory.AgUi.Events
  ( AgUiEvent (..)
  , encodeSseEvent
  ) where

-- AG-UI wire events and SSE encoding.

import Data.Aeson (ToJSON (..), Value, object, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Builder as Builder
import GHC.Generics (Generic)

data AgUiEvent
  = RunStarted {threadId :: String, runId :: String}
  | TextMessageStart {messageId :: String, role :: String}
  | TextMessageContent {messageId :: String, delta :: String}
  | TextMessageEnd {messageId :: String}
  | ToolCallStart {toolCallId :: String, toolName :: String}
  | ToolCallEnd {toolCallId :: String, toolName :: String}
  | CustomEvent {eventName :: String, eventValue :: Value}
  | RunFinished {threadId :: String, runId :: String}
  deriving (Eq, Show, Generic)

instance ToJSON AgUiEvent where
  toJSON event =
    case event of
      RunStarted tid rid ->
        object
          [ "type" .= ("RUN_STARTED" :: String)
          , "threadId" .= tid
          , "runId" .= rid
          ]
      TextMessageStart mid roleName ->
        object
          [ "type" .= ("TEXT_MESSAGE_START" :: String)
          , "messageId" .= mid
          , "role" .= roleName
          ]
      TextMessageContent mid chunk ->
        object
          [ "type" .= ("TEXT_MESSAGE_CONTENT" :: String)
          , "messageId" .= mid
          , "delta" .= chunk
          ]
      TextMessageEnd mid ->
        object
          [ "type" .= ("TEXT_MESSAGE_END" :: String)
          , "messageId" .= mid
          ]
      ToolCallStart callId name ->
        object
          [ "type" .= ("TOOL_CALL_START" :: String)
          , "toolCallId" .= callId
          , "toolName" .= name
          ]
      ToolCallEnd callId name ->
        object
          [ "type" .= ("TOOL_CALL_END" :: String)
          , "toolCallId" .= callId
          , "toolName" .= name
          ]
      CustomEvent name value ->
        object
          [ "type" .= ("CUSTOM" :: String)
          , "name" .= name
          , "value" .= value
          ]
      RunFinished tid rid ->
        object
          [ "type" .= ("RUN_FINISHED" :: String)
          , "threadId" .= tid
          , "runId" .= rid
          ]

encodeSseEvent :: AgUiEvent -> Builder.Builder
encodeSseEvent event =
  Builder.stringUtf8 "data: "
    <> Builder.lazyByteString (Aeson.encode event)
    <> Builder.stringUtf8 "\n\n"
