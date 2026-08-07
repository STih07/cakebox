{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Ai.Agent
  ( runAgentStream
  ) where

-- Agent runner boundary: state, provider calls, fragment tools, and AG-UI events.

import Data.Maybe (fromMaybe)
import Data.Aeson (object, (.=))
import PageFactory.AgUi.Input (RunAgentInput (..), RunMessage (..))
import PageFactory.Ai.ChatState (ChatState, appendAssistantMessage, appendUserMessages, getThreadMessages)
import PageFactory.Ai.Model
  ( AgentEvent (..)
  , MessageId (..)
  , RunId (..)
  , ThreadId (..)
  )
import PageFactory.Ai.Provider.Config (loadAiProviderConfig)
import PageFactory.Ai.Provider.OpenAICompat
  ( ToolCall (..)
  , ToolResult (..)
  , chooseToolCalls
  , streamChatCompletion
  )
import PageFactory.Ai.TraceStore (TraceStore, recordChatMessage, recordTraceEvent)
import PageFactory.Ai.Tools.Fragments (ToolExecution (..), executeFragmentTool)
import PageFactory.Clients (Client)
import PageFactory.Trading.State (TradingState)

runAgentStream :: TraceStore -> [Client] -> TradingState -> ChatState -> RunAgentInput -> (AgentEvent -> IO ()) -> IO ()
runAgentStream traceStore clients tradingState chatState input emit = do
  recordTraceEvent traceStore threadIdText runIdText "run.start" (object ["messageCount" .= length (inputMessages input)])
  mapM_ recordInputMessage (inputMessages input)
  appendUserMessages chatState threadIdText (inputMessages input)
  history <- getThreadMessages chatState threadIdText
  recordTraceEvent traceStore threadIdText runIdText "history.loaded" (object ["messageCount" .= length history])
  config <- loadAiProviderConfig

  emit (AgentRunStarted threadId runId)
  emit (AgentTextStarted messageId)

  toolCalls <-
    chooseToolCalls config history >>= \result ->
      case result of
        Left err -> do
          recordTraceEvent traceStore threadIdText runIdText "tool_planning.error" (object ["error" .= err])
          pure []
        Right calls -> do
          recordTraceEvent traceStore threadIdText runIdText "tool_planning.calls" (object ["calls" .= map toolCallTrace calls])
          pure calls

  executions <- mapM executeTool toolCalls
  let toolResults = map toolExecutionResult executions

  streamed <-
    streamChatCompletion
      config
      history
      toolCalls
      toolResults
      (emit . AgentTextDelta messageId)

  finalText <-
    case streamed of
      Right content ->
        pure content
      Left err -> do
        recordTraceEvent traceStore threadIdText runIdText "provider.stream.error" (object ["error" .= err])
        let fallback = "AI provider недоступен: " <> err
        emit (AgentTextDelta messageId fallback)
        pure fallback

  appendAssistantMessage chatState threadIdText finalText
  recordChatMessage traceStore threadIdText runIdText "assistant" finalText
  recordTraceEvent traceStore threadIdText runIdText "run.finish" (object ["assistantTextLength" .= length finalText])
  emit (AgentTextFinished messageId)
  emit (AgentRunFinished threadId runId)
  where
    threadIdText = inputThreadId input
    threadId = ThreadId threadIdText
    runIdText = fromMaybe "run_chat_1" (inputRunId input)
    runId = RunId runIdText
    messageId = MessageId (runIdText <> "_assistant")

    recordInputMessage message =
      recordChatMessage traceStore threadIdText runIdText (messageRole message) (messageContent message)

    toolCallTrace call =
      object
        [ "id" .= toolCallId call
        , "name" .= toolCallName call
        , "arguments" .= toolCallArguments call
        ]

    executeTool call = do
      recordTraceEvent traceStore threadIdText runIdText "tool.start" (toolCallTrace call)
      emit (AgentToolStarted (toolCallId call) (toolCallName call))
      execution <- executeFragmentTool clients tradingState call
      recordTraceEvent
        traceStore
        threadIdText
        runIdText
        "tool.result"
        ( object
            [ "id" .= toolCallId call
            , "name" .= toolCallName call
            , "content" .= toolResultContent (toolExecutionResult execution)
            ]
        )
      mapM_ emitCustom (toolExecutionEvents execution)
      emit (AgentToolFinished (toolCallId call) (toolCallName call))
      pure execution

    emitCustom (eventName, value) = do
      recordTraceEvent traceStore threadIdText runIdText ("custom." <> eventName) value
      emit (AgentCustomEvent eventName value)
