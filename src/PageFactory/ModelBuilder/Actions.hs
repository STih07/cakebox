{-# LANGUAGE OverloadedStrings #-}

module PageFactory.ModelBuilder.Actions
  ( executeModelBuilderTool
  , modelBuilderToolSchemas
  ) where

-- Agent/screen operations for model configuration.

import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:), (.:?), (.!=), (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS
import PageFactory.Ai.Provider.OpenAICompat (ToolCall (..))
import PageFactory.Chat.Extension (ExtensionExecution (..), ToolSchema)
import PageFactory.Chat.Operations (OperationArg (..), fragmentRenderedEvent, navigateEvent, operationToolSchema, stateUpdatedEvent)
import PageFactory.Engine.Html (renderHtml)
import PageFactory.ModelBuilder.Store (ModelStore, deleteModelConfig, listModelConfigs, saveModelConfig)
import PageFactory.ModelBuilder.View (modelBuilderPanel)

data ModelArgs = ModelArgs
  { modelArgSlug :: String
  , modelArgName :: String
  , modelArgColor :: String
  , modelArgDescription :: String
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
        <$> value .:? "slug" .!= ""
        <*> value .: "name"
        <*> value .: "color"
        <*> value .: "description"

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
      Just <$> saveModel "created"
  | toolCallName call == "update_model" =
      Just <$> saveModel "updated"
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

    saveModel verb =
      case parseModelArgs (toolCallArguments call) of
        Left err -> pureExecution ("ERROR: Bad " <> toolCallName call <> " arguments: " <> err) []
        Right args -> do
          result <- saveModelConfig store (modelArgSlug args) (modelArgName args) (modelArgColor args) (modelArgDescription args)
          case result of
            Left message -> pureExecution ("ERROR: " <> message) []
            Right _ ->
              refreshModels ("OK: Model " <> modelArgName args <> " " <> verb)

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
parseModelArgs =
  eitherDecode . LBS.pack

parseSlugArgs :: String -> Either String ModelSlugArgs
parseSlugArgs =
  eitherDecode . LBS.pack

openModelsTool :: ToolSchema
openModelsTool =
  operationToolSchema "open_models" "Open the Model Builder tab that configures entity models." []

createModelTool :: ToolSchema
createModelTool =
  modelTool "create_model" "Create a new entity model with required name, color, and short description."

updateModelTool :: ToolSchema
updateModelTool =
  modelTool "update_model" "Update an existing entity model and refresh the displayed model list."

deleteModelTool :: ToolSchema
deleteModelTool =
  operationToolSchema "delete_model" "Delete an entity model by slug and refresh the displayed model list." [slugArg]

refreshModelsTool :: ToolSchema
refreshModelsTool =
  operationToolSchema "refresh_models" "Refresh the displayed Model Builder fragment from SQLite storage." []

modelTool :: String -> String -> ToolSchema
modelTool name description =
  operationToolSchema
    name
    description
    [ OperationArg "slug" "Optional model slug. If omitted, it is derived from the name." False
    , OperationArg "name" "Required model name." True
    , OperationArg "color" "Required model color, preferably a CSS hex color like #2f7d58." True
    , OperationArg "description" "Required short model description." True
    ]

slugArg :: OperationArg
slugArg =
  OperationArg "slug" "Model slug." True
