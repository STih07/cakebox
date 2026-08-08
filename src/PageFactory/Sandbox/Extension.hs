module PageFactory.Sandbox.Extension
  ( sandboxExtension
  ) where

-- Chat extension definition for Sandbox markdown documents.

import PageFactory.Chat.Extension (ChatExtension (..))
import PageFactory.Chat.Operations (entityOperationContext)
import PageFactory.Sandbox.Actions (executeSandboxTool, sandboxToolSchemas)
import PageFactory.Sandbox.Store (SandboxDocSummary (..), SandboxStore, listSandboxDocs)

sandboxExtension :: SandboxStore -> ChatExtension
sandboxExtension store =
  ChatExtension
    { extensionId = "sandbox"
    , extensionTitle = "Sandbox"
    , extensionPromptContext = sandboxPromptContext store
    , extensionToolSchemas = sandboxToolSchemas
    , extensionExecuteTool = executeSandboxTool store
    }

sandboxPromptContext :: SandboxStore -> IO String
sandboxPromptContext store = do
  docs <- listSandboxDocs store
  pure $
    unlines
      [ "Extension: Sandbox"
      , "Visible route: /sandbox"
      , "Document routes: /sandbox/docs/{slug}"
      , "Storage: SQLite markdown documents"
      , "Documents: " <> docList docs
      , entityOperationContext "displayed markdown documents" "/sandbox/docs/{slug}" "sandbox-document" ["open_sandbox", "open_sandbox_doc", "create_sandbox_doc", "save_sandbox_doc", "delete_sandbox_doc", "refresh_sandbox_doc"]
      , "Capabilities: open_sandbox, open_sandbox_doc, create_sandbox_doc, save_sandbox_doc, delete_sandbox_doc, refresh_sandbox_doc"
      ]

docList :: [SandboxDocSummary] -> String
docList [] = "none"
docList docs =
  unwords (map docSummarySlug docs)
