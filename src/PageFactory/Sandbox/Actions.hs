{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Sandbox.Actions
  ( executeSandboxTool
  , sandboxToolSchemas
  ) where

-- Agent and screen capabilities for Sandbox documents.

import Data.Aeson (FromJSON (..), Value, eitherDecode, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.List (stripPrefix)
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Chat.Extension (ExtensionExecution (..), ToolSchema)
import PageFactory.Chat.Operations (OperationArg (..), fragmentRenderedEvent, navigateEvent, operationToolSchema, stateUpdatedEvent)
import PageFactory.Engine.Html (renderHtml)
import PageFactory.Sandbox.Store (SandboxStore, deleteSandboxDoc, getSandboxDoc, saveSandboxDoc)
import PageFactory.Sandbox.View (sandboxDocumentFragment)

data SandboxDocArgs = SandboxDocArgs
  { sandboxSlug :: String
  , sandboxTitle :: String
  , sandboxBody :: String
  }
  deriving (Eq, Show)

data SandboxOpenArgs = SandboxOpenArgs
  { sandboxOpenSlug :: String
  }
  deriving (Eq, Show)

instance FromJSON SandboxDocArgs where
  parseJSON =
    withObject "SandboxDocArgs" $ \value ->
      SandboxDocArgs
        <$> value .: "slug"
        <*> value .:? "title" .!= ""
        <*> value .:? "body" .!= ""

instance FromJSON SandboxOpenArgs where
  parseJSON =
    withObject "SandboxOpenArgs" $ \value ->
      SandboxOpenArgs <$> value .: "slug"

sandboxToolSchemas :: [ToolSchema]
sandboxToolSchemas =
  [ openSandboxTool
  , openSandboxDocTool
  , createSandboxDocTool
  , saveSandboxDocTool
  , deleteSandboxDocTool
  , refreshSandboxDocTool
  ]

executeSandboxTool :: SandboxStore -> ToolCall -> IO (Maybe ExtensionExecution)
executeSandboxTool store call
  | toolCallName call == "open_sandbox" =
      Just <$> openSandbox
  | toolCallName call == "open_sandbox_doc" =
      Just <$> openSandboxDoc
  | toolCallName call == "create_sandbox_doc" =
      Just <$> saveDoc True
  | toolCallName call == "save_sandbox_doc" =
      Just <$> saveDoc False
  | toolCallName call == "delete_sandbox_doc" =
      Just <$> deleteDoc
  | toolCallName call == "refresh_sandbox_doc" =
      Just <$> refreshDoc
  | otherwise =
      pure Nothing
  where
    openSandbox =
      pureExecution
        "OK: Opened Sandbox document catalog"
        [navigateEvent "/sandbox" "Sandbox / Документы" "OK: Opened Sandbox document catalog"]

    openSandboxDoc =
      case parseOpenArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad open_sandbox_doc arguments: " <> err) []
        Right args ->
          case sandboxOpenSlug args of
            "" -> pureExecution "ERROR: Document slug is required" []
            slug -> do
              maybeDoc <- getSandboxDoc store slug
              case maybeDoc of
                Nothing -> pureExecution ("ERROR: Sandbox document not found: " <> slug) []
                Just _ ->
                  let url = "/sandbox/docs/" <> sandboxOpenSlug args
                   in pureExecution ("OK: Opened Sandbox document " <> sandboxOpenSlug args) [navigateEvent url (sandboxOpenSlug args) ("OK: Opened Sandbox document " <> sandboxOpenSlug args)]

    refreshDoc =
      case parseOpenArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad refresh_sandbox_doc arguments: " <> err) []
        Right args -> do
          maybeDoc <- getSandboxDoc store (sandboxOpenSlug args)
          case maybeDoc of
            Nothing -> pureExecution ("ERROR: Sandbox document not found: " <> sandboxOpenSlug args) []
            Just doc ->
              let note = "OK: Refreshed Sandbox document " <> sandboxOpenSlug args
               in pureExecution note [fragmentRenderedEvent "sandbox-document" (sandboxOpenSlug args) (renderHtml (sandboxDocumentFragment doc)), stateEvent note]

    deleteDoc =
      case parseOpenArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad delete_sandbox_doc arguments: " <> err) []
        Right args -> do
          result <- deleteSandboxDoc store (sandboxOpenSlug args)
          case result of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right slug ->
              let note = "OK: Deleted Sandbox document " <> slug
               in pureExecution note [navigateEvent "/sandbox" "Sandbox / Документы" note, stateEvent note]

    saveDoc shouldNavigate =
      case parseDocArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad " <> toolCallName call <> " arguments: " <> err) []
        Right args -> do
          result <- saveSandboxDoc store (sandboxSlug args) (sandboxTitle args) (sandboxBody args)
          case result of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right doc ->
              let note = "OK: Saved Sandbox document " <> sandboxSlug args
                  fragmentEvent =
                    fragmentRenderedEvent "sandbox-document" (sandboxSlug args) (renderHtml (sandboxDocumentFragment doc))
                  events =
                    if shouldNavigate
                      then [navigateEvent ("/sandbox/docs/" <> sandboxSlug args) (sandboxTitle args) note]
                      else [fragmentEvent, stateEvent note]
               in pureExecution note events

    pureExecution content events =
      pure
        ExtensionExecution
          { extensionExecutionContent = content
          , extensionExecutionEvents = events
          }

parseDocArgs :: String -> Either String SandboxDocArgs
parseDocArgs raw =
  case eitherDecode (LBS.pack raw) of
    Right args -> Right args
    Left _ ->
      case eitherDecode (LBS.pack (escapeStringControls raw)) of
        Right args -> Right args
        Left err ->
          case parseDocArgsLoose raw of
            Just args -> Right args
            Nothing -> Left err

parseOpenArgs :: String -> Either String SandboxOpenArgs
parseOpenArgs =
  eitherDecode . LBS.pack

escapeStringControls :: String -> String
escapeStringControls = go False False
  where
    go _ _ [] = []
    go inString escaped (char : rest)
      | escaped = char : go inString False rest
      | char == '\\' = char : go inString True rest
      | char == '"' = char : go (not inString) False rest
      | inString && char == '\n' = '\\' : 'n' : go inString False rest
      | inString && char == '\r' = '\\' : 'r' : go inString False rest
      | inString && char == '\t' = '\\' : 't' : go inString False rest
      | otherwise = char : go inString False rest

parseDocArgsLoose :: String -> Maybe SandboxDocArgs
parseDocArgsLoose raw = do
  slug <- lookupJsonString "slug" raw
  body <- lookupJsonString "body" raw
  let title = maybe "" id (lookupJsonString "title" raw)
  pure (SandboxDocArgs slug title body)

lookupJsonString :: String -> String -> Maybe String
lookupJsonString key raw = do
  afterKey <- findNeedle ("\"" <> key <> "\"") raw
  afterColon <- dropThrough ':' afterKey
  afterQuote <- dropThrough '"' afterColon
  Just (takeQuoted afterQuote)

findNeedle :: String -> String -> Maybe String
findNeedle needle value
  | Just rest <- stripPrefix needle value = Just rest
findNeedle needle (_ : rest) = findNeedle needle rest
findNeedle _ [] = Nothing

dropThrough :: Char -> String -> Maybe String
dropThrough wanted (char : rest)
  | char == wanted = Just rest
  | otherwise = dropThrough wanted rest
dropThrough _ [] = Nothing

takeQuoted :: String -> String
takeQuoted = go False
  where
    go _ [] = []
    go escaped (char : rest)
      | escaped = unescapeChar char : go False rest
      | char == '\\' = go True rest
      | char == '"' = []
      | otherwise = char : go False rest

unescapeChar :: Char -> Char
unescapeChar 'n' = '\n'
unescapeChar 'r' = '\r'
unescapeChar 't' = '\t'
unescapeChar char = char

stateEvent :: String -> (String, Value)
stateEvent note =
  stateUpdatedEvent ["currentModule" .= ("Sandbox" :: String), "note" .= note]

openSandboxTool :: ToolSchema
openSandboxTool =
  operationToolSchema "open_sandbox" "Open the Sandbox markdown document catalog." []

openSandboxDocTool :: ToolSchema
openSandboxDocTool =
  operationToolSchema "open_sandbox_doc" "Open a displayed or stored Sandbox markdown document by slug." [slugArg]

createSandboxDocTool :: ToolSchema
createSandboxDocTool =
  docTool "create_sandbox_doc" "Create a Sandbox markdown document, persist it, and navigate to the document page."

saveSandboxDocTool :: ToolSchema
saveSandboxDocTool =
  docTool "save_sandbox_doc" "Save a Sandbox markdown document and re-render the visible document fragment."

deleteSandboxDocTool :: ToolSchema
deleteSandboxDocTool =
  operationToolSchema "delete_sandbox_doc" "Delete a Sandbox markdown document by slug and navigate back to the document catalog." [slugArg]

refreshSandboxDocTool :: ToolSchema
refreshSandboxDocTool =
  operationToolSchema "refresh_sandbox_doc" "Refresh the currently displayed Sandbox document fragment from SQLite storage." [slugArg]

docTool :: String -> String -> ToolSchema
docTool name description =
  operationToolSchema name description [slugArg, OperationArg "title" "Document title." False, OperationArg "body" "Markdown document body." True]

slugArg :: OperationArg
slugArg =
  OperationArg "slug" "Sandbox document slug." True
