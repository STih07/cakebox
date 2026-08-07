{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Ai.TraceStore
  ( TraceStore
  , initTraceStore
  , recordChatMessage
  , recordTraceEvent
  ) where

-- Durable AI runtime traces. SQLite keeps the prototype self-contained while
-- giving us indexed, queryable chat and tool history.

import Control.Exception (SomeException, catch)
import Data.Aeson (Value, encode)
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Encoding as LazyText
import Database.SQLite.Simple (Connection, Query, execute, execute_, withConnection)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)
import Data.Time (getCurrentTime)

newtype TraceStore = TraceStore FilePath
  deriving (Eq, Show)

initTraceStore :: FilePath -> IO TraceStore
initTraceStore path = do
  createDirectoryIfMissing True (takeDirectory path)
  withConnection path $ \conn -> do
    execute_ conn "PRAGMA journal_mode=WAL"
    execute_ conn "PRAGMA synchronous=NORMAL"
    execute_ conn createChatMessages
    execute_ conn createTraceEvents
    execute_ conn "CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_id ON chat_messages(thread_id)"
    execute_ conn "CREATE INDEX IF NOT EXISTS idx_trace_events_thread_run ON trace_events(thread_id, run_id)"
    execute_ conn "CREATE INDEX IF NOT EXISTS idx_trace_events_event_name ON trace_events(event_name)"
  pure (TraceStore path)

recordChatMessage :: TraceStore -> String -> String -> String -> String -> IO ()
recordChatMessage store threadId runId role content =
  safely store $ \conn -> do
    now <- getCurrentTime
    execute
      conn
      "INSERT INTO chat_messages (created_at, thread_id, run_id, role, content) VALUES (?, ?, ?, ?, ?)"
      (show now, threadId, runId, role, content)

recordTraceEvent :: TraceStore -> String -> String -> String -> Value -> IO ()
recordTraceEvent store threadId runId eventName payload =
  safely store $ \conn -> do
    now <- getCurrentTime
    execute
      conn
      "INSERT INTO trace_events (created_at, thread_id, run_id, event_name, payload_json) VALUES (?, ?, ?, ?, ?)"
      (show now, threadId, runId, eventName, LazyText.toStrict (LazyText.decodeUtf8 (encode payload)))

safely :: TraceStore -> (Connection -> IO ()) -> IO ()
safely (TraceStore path) action =
  catch
    (withConnection path action)
    (\err -> putStrLn ("TraceStore write failed: " <> show (err :: SomeException)))

createChatMessages :: Query
createChatMessages =
  "CREATE TABLE IF NOT EXISTS chat_messages (\
  \id INTEGER PRIMARY KEY AUTOINCREMENT,\
  \created_at TEXT NOT NULL,\
  \thread_id TEXT NOT NULL,\
  \run_id TEXT NOT NULL,\
  \role TEXT NOT NULL,\
  \content TEXT NOT NULL\
  \)"

createTraceEvents :: Query
createTraceEvents =
  "CREATE TABLE IF NOT EXISTS trace_events (\
  \id INTEGER PRIMARY KEY AUTOINCREMENT,\
  \created_at TEXT NOT NULL,\
  \thread_id TEXT NOT NULL,\
  \run_id TEXT NOT NULL,\
  \event_name TEXT NOT NULL,\
  \payload_json TEXT NOT NULL\
  \)"
