module PageFactory.Ai.ChatState
  ( ChatMessage (..)
  , ChatState
  , appendAssistantMessage
  , appendUserMessages
  , getThreadMessages
  , newChatState
  ) where

-- In-memory conversation state. Good enough for the prototype; replace with DB later.

import Control.Concurrent.STM (TVar, atomically, modifyTVar', newTVarIO, readTVar)
import qualified Data.Map.Strict as Map
import PageFactory.AgUi.Input (RunMessage (..))

data ChatMessage = ChatMessage
  { chatRole :: String
  , chatContent :: String
  }
  deriving (Eq, Show)

newtype ChatState = ChatState (TVar (Map.Map String [ChatMessage]))

newChatState :: IO ChatState
newChatState = ChatState <$> newTVarIO Map.empty

appendUserMessages :: ChatState -> String -> [RunMessage] -> IO ()
appendUserMessages (ChatState stateVar) threadId messages =
  atomically $
    modifyTVar' stateVar $
      Map.insertWith appendChronologically threadId (map toChatMessage messages)
  where
    appendChronologically newMessages oldMessages = oldMessages <> newMessages

    toChatMessage message =
      ChatMessage
        { chatRole = messageRole message
        , chatContent = messageContent message
        }

appendAssistantMessage :: ChatState -> String -> String -> IO ()
appendAssistantMessage (ChatState stateVar) threadId content =
  atomically $
    modifyTVar' stateVar $
      Map.insertWith
        appendChronologically
        threadId
        [ ChatMessage
            { chatRole = "assistant"
            , chatContent = content
            }
        ]
  where
    appendChronologically newMessages oldMessages = oldMessages <> newMessages

getThreadMessages :: ChatState -> String -> IO [ChatMessage]
getThreadMessages (ChatState stateVar) threadId =
  Map.findWithDefault [] threadId <$> atomically (readTVar stateVar)
