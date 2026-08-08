{-# LANGUAGE OverloadedStrings #-}

module PageFactory.Sandbox.Store
  ( SandboxDoc (..)
  , SandboxDocSummary (..)
  , SandboxStore
  , deleteSandboxDoc
  , getSandboxDoc
  , initSandboxStore
  , listSandboxDocs
  , normalizeSlug
  , saveSandboxDoc
  ) where

-- Durable markdown document storage for the Sandbox module.

import Data.Char (isAlphaNum, toLower)
import Data.Maybe (listToMaybe)
import Data.Time (getCurrentTime)
import Database.SQLite.Simple (Connection, FromRow (..), Only (..), Query, execute, execute_, field, query, query_, withConnection)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)

newtype SandboxStore = SandboxStore FilePath
  deriving (Eq, Show)

data SandboxDocSummary = SandboxDocSummary
  { docSummarySlug :: String
  , docSummaryTitle :: String
  , docSummaryUpdatedAt :: String
  }
  deriving (Eq, Show)

data SandboxDoc = SandboxDoc
  { docSlug :: String
  , docTitle :: String
  , docBody :: String
  , docUpdatedAt :: String
  }
  deriving (Eq, Show)

instance FromRow SandboxDocSummary where
  fromRow =
    SandboxDocSummary <$> field <*> field <*> field

instance FromRow SandboxDoc where
  fromRow =
    SandboxDoc <$> field <*> field <*> field <*> field

initSandboxStore :: FilePath -> IO SandboxStore
initSandboxStore path = do
  createDirectoryIfMissing True (takeDirectory path)
  withConnection path $ \conn -> do
    execute_ conn "PRAGMA journal_mode=WAL"
    execute_ conn "PRAGMA synchronous=NORMAL"
    execute_ conn createSandboxDocuments
    execute_ conn "CREATE INDEX IF NOT EXISTS idx_sandbox_documents_updated_at ON sandbox_documents(updated_at)"
    rows <- query_ conn "SELECT COUNT(*) FROM sandbox_documents" :: IO [Only Int]
    case rows of
      [Only 0] -> seedSandboxDocs conn
      _ -> pure ()
  pure (SandboxStore path)

listSandboxDocs :: SandboxStore -> IO [SandboxDocSummary]
listSandboxDocs (SandboxStore path) =
  withConnection path $ \conn ->
    query_ conn "SELECT slug, title, updated_at FROM sandbox_documents ORDER BY updated_at DESC"

getSandboxDoc :: SandboxStore -> String -> IO (Maybe SandboxDoc)
getSandboxDoc (SandboxStore path) rawSlug =
  case normalizeSlug rawSlug of
    Nothing -> pure Nothing
    Just slug ->
      withConnection path $ \conn -> do
        rows <- query conn "SELECT slug, title, body, updated_at FROM sandbox_documents WHERE slug = ?" (Only slug)
        pure (listToMaybe rows)

deleteSandboxDoc :: SandboxStore -> String -> IO (Either String String)
deleteSandboxDoc (SandboxStore path) rawSlug =
  case normalizeSlug rawSlug of
    Nothing -> pure (Left "Document slug is invalid")
    Just slug ->
      withConnection path $ \conn -> do
        rows <- query conn "SELECT slug FROM sandbox_documents WHERE slug = ?" (Only slug) :: IO [Only String]
        case rows of
          [] -> pure (Left ("Sandbox document not found: " <> slug))
          _ -> do
            execute conn "DELETE FROM sandbox_documents WHERE slug = ?" (Only slug)
            pure (Right slug)

saveSandboxDoc :: SandboxStore -> String -> String -> String -> IO (Either String SandboxDoc)
saveSandboxDoc (SandboxStore path) rawSlug rawTitle body =
  case normalizeSlug rawSlug of
    Nothing ->
      pure (Left "Document slug must contain letters, digits, or hyphens")
    Just slug -> do
      now <- show <$> getCurrentTime
      let title = if null rawTitle then slug else rawTitle
      withConnection path $ \conn ->
        execute
          conn
          "INSERT INTO sandbox_documents (slug, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?) \
          \ON CONFLICT(slug) DO UPDATE SET title = excluded.title, body = excluded.body, updated_at = excluded.updated_at"
          (slug, title, body, now, now)
      pure (Right (SandboxDoc slug title body now))

normalizeSlug :: String -> Maybe String
normalizeSlug rawSlug =
  let lowered = map toLower rawSlug
      normalized = collapseHyphens (map slugChar lowered)
      trimmed = trimHyphens normalized
   in if null trimmed then Nothing else Just trimmed

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

createSandboxDocuments :: Query
createSandboxDocuments =
  "CREATE TABLE IF NOT EXISTS sandbox_documents (\
  \slug TEXT PRIMARY KEY,\
  \title TEXT NOT NULL,\
  \body TEXT NOT NULL,\
  \created_at TEXT NOT NULL,\
  \updated_at TEXT NOT NULL\
  \)"

seedSandboxDocs :: Connection -> IO ()
seedSandboxDocs conn = do
  now <- show <$> getCurrentTime
  insertSeed now ("welcome", "Welcome", "# Welcome\n\nSandbox stores markdown documents in SQLite.\n\nBoth the user interface and agent tools can edit the same document records.")
  insertSeed now ("agent-notes", "Agent Notes", "# Agent Notes\n\nUse this space to describe what the agent should learn to build next.")
  where
    insertSeed now (slug, title, body) =
      execute conn insertDoc (slug :: String, title :: String, body :: String, now :: String, now :: String)

    insertDoc =
      "INSERT INTO sandbox_documents (slug, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
