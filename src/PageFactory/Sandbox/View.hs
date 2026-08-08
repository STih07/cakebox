module PageFactory.Sandbox.View
  ( sandboxCatalogView
  , sandboxDocumentFragment
  , sandboxDocumentView
  ) where

-- Sandbox document catalog and editor views.

import PageFactory.Engine (Html, tag, text)
import PageFactory.Sandbox.Store (SandboxDoc (..), SandboxDocSummary (..))

sandboxCatalogView :: [SandboxDocSummary] -> Html
sandboxCatalogView docs =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "sandbox")]
    ( tag "section" [("class", "profile sandbox-hero")]
        ( tag "p" [("class", "eyebrow")] (text "Sandbox")
            <> tag "h1" [] (text "Документы")
            <> tag "p" [] (text "Markdown-каталог поверх Haskell middle layer. Документы хранятся в SQLite и доступны экрану и агенту через один extension action contract.")
        )
        <> newDocumentForm
        <> tag "section" [("class", "sandbox-doc-grid")] (foldMap docCard docs)
    )

sandboxDocumentView :: SandboxDoc -> Html
sandboxDocumentView doc =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "sandbox-document-page")]
    ( tag "a" [("class", "back"), ("href", "/sandbox")] (text "← Документы")
        <> sandboxDocumentFragment doc
    )

sandboxDocumentFragment :: SandboxDoc -> Html
sandboxDocumentFragment doc =
  tag
    "section"
    [("class", "panel sandbox-document"), ("data-fragment-slot", "sandbox-document")]
    ( tag "form"
        [ ("class", "sandbox-editor")
        , ("data-extension-action-form", "save_sandbox_doc")
        ]
        ( tag "input" [("type", "hidden"), ("name", "slug"), ("value", docSlug doc)] mempty
            <> tag "label" [] (text "Title")
            <> tag "input" [("name", "title"), ("value", docTitle doc), ("autocomplete", "off")] mempty
            <> tag "label" [] (text "Markdown")
            <> tag "textarea" [("name", "body"), ("rows", "16")] (text (docBody doc))
            <> tag "button" [("type", "submit")] (text "Save")
        )
        <> tag "article" [("class", "sandbox-preview")]
          ( tag "span" [("class", "card-id")] (text ("updated " <> docUpdatedAt doc))
              <> tag "h2" [] (text (docTitle doc))
              <> tag "pre" [] (text (docBody doc))
          )
    )

newDocumentForm :: Html
newDocumentForm =
  tag
    "form"
    [ ("class", "sandbox-create")
    , ("data-extension-action-form", "create_sandbox_doc")
    ]
    ( tag "input" [("name", "slug"), ("placeholder", "document-slug"), ("autocomplete", "off"), ("aria-label", "Document slug")] mempty
        <> tag "input" [("name", "title"), ("placeholder", "Title"), ("autocomplete", "off"), ("aria-label", "Document title")] mempty
        <> tag "textarea" [("name", "body"), ("rows", "3"), ("placeholder", "# Markdown")] mempty
        <> tag "button" [("type", "submit")] (text "Create")
    )

docCard :: SandboxDocSummary -> Html
docCard doc =
  tag
    "a"
    [("class", "sandbox-doc-card"), ("href", "/sandbox/docs/" <> docSummarySlug doc)]
    ( tag "span" [("class", "card-id")] (text (docSummarySlug doc))
        <> tag "strong" [] (text (docSummaryTitle doc))
        <> tag "span" [] (text ("updated " <> docSummaryUpdatedAt doc))
    )
