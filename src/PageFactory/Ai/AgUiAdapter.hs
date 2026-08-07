module PageFactory.Ai.AgUiAdapter
  ( toAgUiEvent
  ) where

-- Adapter from internal AI events to AG-UI wire events.

import PageFactory.AgUi.Events
  ( AgUiEvent (CustomEvent, RunFinished, RunStarted, TextMessageContent, TextMessageEnd, TextMessageStart, ToolCallEnd, ToolCallStart)
  )
import PageFactory.Ai.Model
  ( AgentEvent (..)
  , unMessageId
  , unRunId
  , unThreadId
  )

toAgUiEvent :: AgentEvent -> AgUiEvent
toAgUiEvent event =
  case event of
    AgentRunStarted tid rid ->
      RunStarted (unThreadId tid) (unRunId rid)
    AgentTextStarted mid ->
      TextMessageStart (unMessageId mid) "assistant"
    AgentTextDelta mid chunk ->
      TextMessageContent (unMessageId mid) chunk
    AgentTextFinished mid ->
      TextMessageEnd (unMessageId mid)
    AgentToolStarted callId name ->
      ToolCallStart callId name
    AgentToolFinished callId name ->
      ToolCallEnd callId name
    AgentCustomEvent name value ->
      CustomEvent name value
    AgentRunFinished tid rid ->
      RunFinished (unThreadId tid) (unRunId rid)
