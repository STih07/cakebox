{-# LANGUAGE OverloadedStrings #-}

module PageFactory.AgUi.Server
  ( agUiRunResponse
  ) where

-- AG-UI HTTP bridge. It streams AI runtime events through the AG-UI adapter.

import Data.Aeson (eitherDecode)
import qualified Data.ByteString.Builder as Builder
import Network.HTTP.Types (hCacheControl, hContentType, methodGet, methodPost, status200, status400, status405)
import Network.Wai (Request, Response, requestMethod, responseLBS, responseStream, strictRequestBody)
import PageFactory.AgUi.Input (RunAgentInput, defaultRunAgentInput)
import PageFactory.Ai (ChatState, TraceStore, runAgentStream, toAgUiEvent)
import PageFactory.Clients (Client)
import PageFactory.ModelBuilder.Store (ModelStore)
import PageFactory.Sandbox.Store (SandboxStore)
import PageFactory.Trading.State (TradingState)
import PageFactory.AgUi.Events
  ( AgUiEvent
  , encodeSseEvent
  )

agUiRunResponse :: TraceStore -> ChatState -> TradingState -> SandboxStore -> ModelStore -> [Client] -> Request -> IO Response
agUiRunResponse traceStore chatState tradingState sandboxStore modelStore clients req
  | requestMethod req == methodGet =
      pure (streamRun traceStore chatState tradingState sandboxStore modelStore clients defaultRunAgentInput)
  | requestMethod req == methodPost = do
      body <- strictRequestBody req
      pure $
        case eitherDecode body of
          Right input -> streamRun traceStore chatState tradingState sandboxStore modelStore clients input
          Left err -> badRequest ("Bad RunAgentInput JSON: " <> err <> "\n")
  | otherwise =
      pure methodNotAllowed

streamRun :: TraceStore -> ChatState -> TradingState -> SandboxStore -> ModelStore -> [Client] -> RunAgentInput -> Response
streamRun traceStore chatState tradingState sandboxStore modelStore clients input =
  responseStream
    status200
    [ (hContentType, "text/event-stream; charset=utf-8")
    , (hCacheControl, "no-cache")
    , ("X-Accel-Buffering", "no")
    ]
    $ \send flush -> do
      runAgentStream traceStore clients tradingState sandboxStore modelStore chatState input (sendEvent send flush . toAgUiEvent)

sendEvent :: (Builder.Builder -> IO ()) -> IO () -> AgUiEvent -> IO ()
sendEvent send flush event = do
  send (encodeSseEvent event)
  flush

badRequest :: String -> Response
badRequest body =
  responseLBS
    status400
    [(hContentType, "text/plain; charset=utf-8")]
    (Builder.toLazyByteString (Builder.stringUtf8 body))

methodNotAllowed :: Response
methodNotAllowed =
  responseLBS
    status405
    [(hContentType, "text/plain; charset=utf-8")]
    "Method not allowed\n"
