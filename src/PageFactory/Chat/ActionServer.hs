{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Chat.ActionServer
  ( extensionActionResponse
  ) where

-- HTTP endpoint for screen controls that call the same extension capabilities as the agent.

import Data.Aeson (FromJSON (..), Value, eitherDecode, encode, object, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import Network.HTTP.Types (Status, hContentType, methodPost, status200, status400, status405)
import Network.Wai (Request, Response, requestMethod, responseLBS, strictRequestBody)
import PageFactory.Ai.Provider.OpenAICompat (ToolCall, mkLocalToolCall)
import PageFactory.Chat.Extension (ExtensionExecution (..), runExtensionTool)
import PageFactory.Chat.Registry (enabledExtensions)
import PageFactory.Trading.State (TradingState)

data ExtensionActionInput = ExtensionActionInput
  { actionName :: String
  , actionArguments :: Value
  }
  deriving (Eq, Show)

instance FromJSON ExtensionActionInput where
  parseJSON =
    withObject "ExtensionActionInput" $ \value ->
      ExtensionActionInput
        <$> value .: "action"
        <*> value .:? "arguments" .!= object []

extensionActionResponse :: TradingState -> Request -> IO Response
extensionActionResponse tradingState req
  | requestMethod req /= methodPost =
      pure methodNotAllowed
  | otherwise = do
      body <- strictRequestBody req
      case eitherDecode body of
        Left err ->
          pure (jsonResponse status400 (object ["ok" .= False, "error" .= ("Bad action JSON: " <> err)]))
        Right input -> do
          let extensions = enabledExtensions tradingState
              toolCall = actionToolCall input
          result <- runExtensionTool extensions toolCall
          pure $
            case result of
              Nothing ->
                jsonResponse status400 (object ["ok" .= False, "error" .= ("Unknown extension action: " <> actionName input)])
              Just execution ->
                jsonResponse
                  status200
                  ( object
                      [ "ok" .= not (startsWithError (extensionExecutionContent execution))
                      , "content" .= extensionExecutionContent execution
                      , "events" .= map eventJson (extensionExecutionEvents execution)
                      ]
                  )

actionToolCall :: ExtensionActionInput -> ToolCall
actionToolCall input =
  mkLocalToolCall "screen_action" (actionName input) (LBS.unpack (encode (actionArguments input)))

eventJson :: (String, Value) -> Value
eventJson (name, value) =
  object
    [ "type" .= ("CUSTOM" :: String)
    , "name" .= name
    , "value" .= value
    ]

startsWithError :: String -> Bool
startsWithError value =
  take 6 value == "ERROR:"

jsonResponse :: Status -> Value -> Response
jsonResponse status value =
  responseLBS status [(hContentType, "application/json; charset=utf-8")] (encode value)

methodNotAllowed :: Response
methodNotAllowed =
  responseLBS status405 [(hContentType, "text/plain; charset=utf-8")] "Method not allowed\n"
