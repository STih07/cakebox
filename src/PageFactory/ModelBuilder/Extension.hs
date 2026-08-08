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
      , "Models: " <> modelList models
      , entityOperationContext "displayed entity models" "/models" "model-builder-panel" ["open_models", "create_model", "update_model", "delete_model", "refresh_models"]
      , "Capabilities: open_models, create_model, update_model, delete_model, refresh_models"
      ]

modelList :: [ModelConfig] -> String
modelList [] = "none"
modelList models =
  unwords (map modelSlug models)
