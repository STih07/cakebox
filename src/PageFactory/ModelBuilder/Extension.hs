module PageFactory.ModelBuilder.Extension
  ( modelBuilderExtension
  ) where

-- Chat extension for configurable entity models.

import PageFactory.Chat.Extension (ChatExtension (..))
import PageFactory.Chat.Operations (entityOperationContext)
import PageFactory.ModelBuilder.Actions (executeModelBuilderTool, modelBuilderToolSchemas)
import PageFactory.ModelBuilder.Store (ModelConfig (..), ModelStore, listModelConfigs)

modelBuilderExtension :: ModelStore -> ChatExtension
modelBuilderExtension store =
  ChatExtension
    { extensionId = "model-builder"
    , extensionTitle = "Model Builder"
    , extensionPromptContext = modelBuilderPromptContext store
    , extensionToolSchemas = modelBuilderToolSchemas
    , extensionExecuteTool = executeModelBuilderTool store
    }

modelBuilderPromptContext :: ModelStore -> IO String
modelBuilderPromptContext store = do
  models <- listModelConfigs store
  pure $
    unlines
      [ "Extension: Model Builder"
      , "Visible route: /models"
      , "Fragment slot: model-builder-panel"
      , "Purpose: configure entity models. A model can represent anything."
      , "Required model fields: name, color, short description."
      , "When the user asks for vague style changes like brighter, calmer, warmer, or more modern colors, choose suitable colors yourself and call update_model for the visible models. Do not ask the user to pick exact colors unless they explicitly want to choose."
      , "update_model is a patch operation: identify the model by slug or current name, and send only fields that should change."
      , "Models: " <> modelList models
      , entityOperationContext "displayed entity models" "/models" "model-builder-panel" ["open_models", "create_model", "update_model", "delete_model", "refresh_models"]
      , "Capabilities: open_models, create_model, update_model, delete_model, refresh_models"
      ]

modelList :: [ModelConfig] -> String
modelList [] = "none"
modelList models =
  unwords (map modelSlug models)
