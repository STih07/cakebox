{-# LANGUAGE OverloadedStrings #-}

module PageFactory.ModelBuilder.Actions
  ( executeModelBuilderTool
  , modelBuilderToolSchemas
  ) where

-- Agent/screen operations for model configuration.

import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:), (.:?), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.List (stripPrefix)
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Chat.Extension (ExtensionExecution (..), ToolSchema)
import PageFactory.Chat.Operations (OperationArg (..), fragmentRenderedEvent, navigateEvent, operationToolSchema, stateUpdatedEvent)
import PageFactory.Engine.Html (renderHtml)
import PageFactory.ModelBuilder.Store (ModelConfig (..), ModelStore, deleteModelConfig, getModelConfig, listModelConfigs, normalizeModelSlug, saveModelConfig)
import PageFactory.ModelBuilder.View (modelBuilderPanel)

data ModelArgs = ModelArgs
  { modelArgSlug :: Maybe String
  , modelArgName :: Maybe String
  , modelArgColor :: Maybe String
  , modelArgDescription :: Maybe String
  }
  deriving (Eq, Show)

data ModelSlugArgs = ModelSlugArgs
  { modelSlugArg :: String
  }
  deriving (Eq, Show)

instance FromJSON ModelArgs where
  parseJSON =
    withObject "ModelArgs" $ \value ->
      ModelArgs
        <$> value .:? "slug"
        <*> value .:? "name"
        <*> value .:? "color"
        <*> value .:? "description"

instance FromJSON ModelSlugArgs where
  parseJSON =
    withObject "ModelSlugArgs" $ \value ->
      ModelSlugArgs <$> value .: "slug"

modelBuilderToolSchemas :: [ToolSchema]
modelBuilderToolSchemas =
  [ openModelsTool
  , createModelTool
  , updateModelTool
  , deleteModelTool
  , refreshModelsTool
  ]

executeModelBuilderTool :: ModelStore -> ToolCall -> IO (Maybe ExtensionExecution)
executeModelBuilderTool store call
  | toolCallName call == "open_models" =
      Just <$> openModels
  | toolCallName call == "refresh_models" =
      Just <$> refreshModels "OK: Refreshed Model Builder"
  | toolCallName call == "create_model" =
      Just <$> createModel
  | toolCallName call == "update_model" =
      Just <$> updateModel
  | toolCallName call == "delete_model" =
      Just <$> deleteModel
  | otherwise =
      pure Nothing
  where
    openModels =
      pureExecution
        "OK: Opened Model Builder"
        [ navigateEvent "/models" "Model Builder / Модели" "OK: Opened Model Builder"
        , stateUpdatedEvent ["currentModule" .= ("Model Builder" :: String), "note" .= ("OK: Opened Model Builder" :: String)]
        ]

    createModel =
      case parseModelArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad " <> toolCallName call <> " arguments: " <> err) []
        Right args -> do
          result <- saveModelConfig store (orEmpty (modelArgSlug args)) (orEmpty (modelArgName args)) (orEmpty (modelArgColor args)) (orEmpty (modelArgDescription args))
          case result of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right _ ->
              refreshModels ("OK: Model " <> orEmpty (modelArgName args) <> " created")

    updateModel =
      case parseModelArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad update_model arguments: " <> err) []
        Right args -> do
          let maybeSlug = modelArgSlug args <> (normalizeModelSlug =<< modelArgName args)
          case maybeSlug of
            Nothing -> pureExecution "ERROR: update_model requires slug or name" []
            Just slug -> do
              existing <- getModelConfig store slug
              case existing of
                Nothing -> pureExecution ("ERROR: Model not found: " <> slug) []
                Just model -> do
                  let nextName = nonBlankOr (modelName model) (modelArgName args)
                      nextColor = nonBlankOr (modelColor model) (modelArgColor args)
                      nextDescription = nonBlankOr (modelDescription model) (modelArgDescription args)
                  result <- saveModelConfig store slug nextName nextColor nextDescription
                  case result of
                    Left message -> pureExecution ("ERROR: " <> message) []
                    Right _ -> refreshModels ("OK: Model " <> nextName <> " updated")

    deleteModel =
      case parseSlugArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad delete_model arguments: " <> err) []
        Right args -> do
          result <- deleteModelConfig store (modelSlugArg args)
          case result of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right slug -> refreshModels ("OK: Deleted model " <> slug)

    refreshModels note = do
      models <- listModelConfigs store
      pureExecution
        note
        [ fragmentRenderedEvent "model-builder-panel" "Model Builder / Модели" (renderHtml (modelBuilderPanel models))
        , stateUpdatedEvent ["currentModule" .= ("Model Builder" :: String), "modelCount" .= length models, "note" .= note]
        ]

    pureExecution content events =
      pure
        ExtensionExecution
          { extensionExecutionContent = content
          , extensionExecutionEvents = events
          }

parseModelArgs :: String -> Either String ModelArgs
parseModelArgs raw =
  case eitherDecode (LBS.pack raw) of
    Right args -> Right args
    Left _ ->
      case eitherDecode (LBS.pack (escapeStringControls raw)) of
        Right args -> Right args
        Left err ->
          case parseModelArgsLoose raw of
            Just args -> Right args
            Nothing -> Left err

parseSlugArgs :: String -> Either String ModelSlugArgs
parseSlugArgs =
  eitherDecode . LBS.pack

openModelsTool :: ToolSchema
openModelsTool =
  operationToolSchema "open_models" "Open the Model Builder tab that configures entity models." []

createModelTool :: ToolSchema
createModelTool =
  operationToolSchema
    "create_model"
    "Create a new entity model with required name, color, and short description."
    [ OperationArg "slug" "Optional model slug. If omitted, it is derived from the name." False
    , OperationArg "name" "Required model name." True
    , OperationArg "color" "Required model color, preferably a CSS hex color like #2f7d58." True
    , OperationArg "description" "Required short model description." True
    ]

updateModelTool :: ToolSchema
updateModelTool =
  operationToolSchema
    "update_model"
    "Patch an existing entity model and refresh the displayed model list. Use slug or current name to identify it; send only fields that should change."
    [ OperationArg "slug" "Optional model slug. Use this when known." False
    , OperationArg "name" "Optional model name. Can identify the model when slug is omitted, or rename it when slug is present." False
    , OperationArg "color" "Optional replacement model color, preferably a CSS hex color like #ff5733." False
    , OperationArg "description" "Optional replacement short model description." False
    ]

deleteModelTool :: ToolSchema
deleteModelTool =
  operationToolSchema "delete_model" "Delete an entity model by slug and refresh the displayed model list." [slugArg]

refreshModelsTool :: ToolSchema
refreshModelsTool =
  operationToolSchema "refresh_models" "Refresh the displayed Model Builder fragment from SQLite storage." []

slugArg :: OperationArg
slugArg =
  OperationArg "slug" "Model slug." True

orEmpty :: Maybe String -> String
orEmpty =
  maybe "" id

nonBlankOr :: String -> Maybe String -> String
nonBlankOr fallback Nothing = fallback
nonBlankOr fallback (Just value)
  | all (`elem` (" \n\r\t" :: String)) value = fallback
  | otherwise = value

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

parseModelArgsLoose :: String -> Maybe ModelArgs
parseModelArgsLoose raw =
  let slug = lookupJsonString "slug" raw
      name = lookupJsonString "name" raw
      color = lookupJsonString "color" raw
      description = lookupJsonString "description" raw
   in if any isJustString [slug, name, color, description]
        then Just (ModelArgs slug name color description)
        else Nothing

isJustString :: Maybe String -> Bool
isJustString (Just _) = True
isJustString Nothing = False

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
