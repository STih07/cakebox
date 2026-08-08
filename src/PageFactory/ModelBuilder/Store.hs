{-# LANGUAGE OverloadedStrings #-}

module PageFactory.ModelBuilder.Store
  ( ModelConfig (..)
  , ModelStore
  , deleteModelConfig
  , getModelConfig
  , initModelStore
  , listModelConfigs
  , normalizeModelSlug
  , saveModelConfig
  ) where

-- Durable user/agent-defined entity model configuration.

import Data.Char (isAlphaNum, toLower)
import Data.Maybe (listToMaybe)
import Data.Time (getCurrentTime)
import Database.SQLite.Simple (Connection, FromRow (..), Only (..), Query, execute, execute_, field, query, query_, withConnection)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)

newtype ModelStore = ModelStore FilePath
  deriving (Eq, Show)

data ModelConfig = ModelConfig
  { modelSlug :: String
  , modelName :: String
  , modelColor :: String
  , modelDescription :: String
  , modelUpdatedAt :: String
  }
  deriving (Eq, Show)

instance FromRow ModelConfig where
  fromRow =
    ModelConfig <$> field <*> field <*> field <*> field <*> field

initModelStore :: FilePath -> IO ModelStore
initModelStore path = do
  createDirectoryIfMissing True (takeDirectory path)
  withConnection path $ \conn -> do
    execute_ conn "PRAGMA journal_mode=WAL"
    execute_ conn "PRAGMA synchronous=NORMAL"
    execute_ conn createModels
    execute_ conn "CREATE INDEX IF NOT EXISTS idx_model_configs_updated_at ON model_configs(updated_at)"
    rows <- query_ conn "SELECT COUNT(*) FROM model_configs" :: IO [Only Int]
    case rows of
      [Only 0] -> seedModels conn
      _ -> pure ()
  pure (ModelStore path)

listModelConfigs :: ModelStore -> IO [ModelConfig]
listModelConfigs (ModelStore path) =
  withConnection path $ \conn ->
    query_ conn "SELECT slug, name, color, description, updated_at FROM model_configs ORDER BY updated_at DESC"

getModelConfig :: ModelStore -> String -> IO (Maybe ModelConfig)
getModelConfig (ModelStore path) rawSlug =
  case normalizeModelSlug rawSlug of
    Nothing -> pure Nothing
    Just slug ->
      withConnection path $ \conn -> do
        rows <- query conn "SELECT slug, name, color, description, updated_at FROM model_configs WHERE slug = ?" (Only slug)
        pure (listToMaybe rows)

saveModelConfig :: ModelStore -> String -> String -> String -> String -> IO (Either String ModelConfig)
saveModelConfig (ModelStore path) rawSlug rawName rawColor rawDescription =
  case validateModel rawSlug rawName rawColor rawDescription of
    Left message -> pure (Left message)
    Right (slug, name, color, description) -> do
      now <- show <$> getCurrentTime
      withConnection path $ \conn ->
        execute
          conn
          "INSERT INTO model_configs (slug, name, color, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) \
          \ON CONFLICT(slug) DO UPDATE SET name = excluded.name, color = excluded.color, description = excluded.description, updated_at = excluded.updated_at"
          (slug, name, color, description, now, now)
      pure (Right (ModelConfig slug name color description now))

deleteModelConfig :: ModelStore -> String -> IO (Either String String)
deleteModelConfig (ModelStore path) rawSlug =
  case normalizeModelSlug rawSlug of
    Nothing -> pure (Left "Model slug is invalid")
    Just slug ->
      withConnection path $ \conn -> do
        rows <- query conn "SELECT slug FROM model_configs WHERE slug = ?" (Only slug) :: IO [Only String]
        case rows of
          [] -> pure (Left ("Model not found: " <> slug))
          _ -> do
            execute conn "DELETE FROM model_configs WHERE slug = ?" (Only slug)
            pure (Right slug)

validateModel :: String -> String -> String -> String -> Either String (String, String, String, String)
validateModel rawSlug rawName rawColor rawDescription =
  case (normalizeModelSlug (if null rawSlug then rawName else rawSlug), clean rawName, clean rawColor, clean rawDescription) of
    (Nothing, _, _, _) -> Left "Model name is required"
    (_, "", _, _) -> Left "Model name is required"
    (_, _, "", _) -> Left "Model color is required"
    (_, _, _, "") -> Left "Model description is required"
    (Just slug, name, color, description) -> Right (slug, name, color, description)

normalizeModelSlug :: String -> Maybe String
normalizeModelSlug raw =
  let lowered = map toLower raw
      normalized = collapseHyphens (map slugChar lowered)
      trimmed = trimHyphens normalized
   in if null trimmed then Nothing else Just trimmed

clean :: String -> String
clean =
  trim

slugChar :: Char -> Char
slugChar char
  | isAlphaNum char = char
  | otherwise = '-'

collapseHyphens :: String -> String
collapseHyphens = foldr step []
  where
    step '-' ('-' : rest) = '-' : rest
    step char rest = char : rest

trimHyphens :: String -> String
trimHyphens = reverse . dropWhile (== '-') . reverse . dropWhile (== '-')

trim :: String -> String
trim = reverse . dropWhile (== ' ') . reverse . dropWhile (== ' ')

createModels :: Query
createModels =
  "CREATE TABLE IF NOT EXISTS model_configs (\
  \slug TEXT PRIMARY KEY,\
  \name TEXT NOT NULL,\
  \color TEXT NOT NULL,\
  \description TEXT NOT NULL,\
  \created_at TEXT NOT NULL,\
  \updated_at TEXT NOT NULL)"

seedModels :: Connection -> IO ()
seedModels conn = do
  now <- show <$> getCurrentTime
  insertSeed now ("document", "Document", "#2f7d58", "Markdown document with title, body, and rendered fragment.")
  insertSeed now ("ticker", "Ticker", "#35535b", "Displayed market symbol with quote, status, and refresh operations.")
  where
    insertSeed now (slug, name, color, description) =
      execute conn insertModel (slug :: String, name :: String, color :: String, description :: String, now :: String, now :: String)
    insertModel =
      "INSERT INTO model_configs (slug, name, color, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
