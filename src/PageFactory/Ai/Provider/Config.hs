module PageFactory.Ai.Provider.Config
  ( AiProviderConfig (..)
  , loadAiProviderConfig
  ) where

-- Runtime AI provider settings. OpenRouter and OpenAI both use an OpenAI-compatible shape here.

import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)

data AiProviderConfig = AiProviderConfig
  { providerBaseUrl :: String
  , providerApiKey :: Maybe String
  , providerModel :: String
  , providerReferer :: Maybe String
  , providerTitle :: Maybe String
  }
  deriving (Eq, Show)

loadAiProviderConfig :: IO AiProviderConfig
loadAiProviderConfig = do
  openAiKey <- lookupEnv "OPENAI_API_KEY"
  openRouterKey <- lookupEnv "OPENROUTER_API_KEY"
  aiBaseUrl <- lookupEnv "AI_BASE_URL"
  aiModel <- lookupEnv "AI_MODEL"
  openAiModel <- lookupEnv "OPENAI_MODEL"
  openRouterModel <- lookupEnv "OPENROUTER_MODEL"
  referer <- lookupEnv "OPENROUTER_SITE_URL"
  title <- lookupEnv "OPENROUTER_APP_NAME"

  let usingOpenAi = maybe False (const True) openAiKey
      defaultBaseUrl =
        if usingOpenAi
          then "https://api.openai.com/v1"
          else "https://openrouter.ai/api/v1"
      defaultModel =
        if usingOpenAi
          then "gpt-4o-mini"
          else "openai/gpt-4o-mini"

  pure
    AiProviderConfig
      { providerBaseUrl = fromMaybe defaultBaseUrl aiBaseUrl
      , providerApiKey = openAiKey <> openRouterKey
      , providerModel = fromMaybe defaultModel (aiModel <> openAiModel <> openRouterModel)
      , providerReferer = referer
      , providerTitle = title
      }
