module PageFactory.Sandbox.View
  ( sandboxCatalogView
  , sandboxDocumentFragment
  , sandboxDocumentView
  ) where

-- Sandbox document catalog and editor views.

import Data.Char (isSpace, toUpper)
import Data.List (stripPrefix)
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
    [("class", "shell sandbox-doc-shell"), ("data-render-part", "sandbox-document-page")]
    (sandboxDocumentFragment doc)

sandboxDocumentFragment :: SandboxDoc -> Html
sandboxDocumentFragment doc =
  tag
    "section"
    [("class", "sandbox-document"), ("data-fragment-slot", "sandbox-document")]
    ( tag "form"
        [ ("class", "sandbox-editor")
        , ("data-extension-action-form", "save_sandbox_doc")
        ]
        ( tag "input" [("type", "hidden"), ("name", "slug"), ("value", docSlug doc)] mempty
            <> tag "header" [("class", "sandbox-doc-toolbar")]
              ( tag "a" [("class", "back"), ("href", "/sandbox")] (text "← Документы")
                  <> tag "input" [("class", "sandbox-title-input"), ("name", "title"), ("value", docTitle doc), ("autocomplete", "off"), ("aria-label", "Document title")] mempty
                  <> tag "span" [("class", "sandbox-doc-updated")] (text ("Updated " <> shortDateTime (docUpdatedAt doc)))
                  <> tag "button" [("type", "button"), ("data-extension-action", "refresh_sandbox_doc"), ("data-slug", docSlug doc)] (text "Refresh")
                  <> tag "button" [("type", "button"), ("data-extension-action", "delete_sandbox_doc"), ("data-slug", docSlug doc)] (text "Delete")
                  <> tag "button" [("type", "submit")] (text "Save")
              )
            <> tag "div" [("class", "sandbox-workspace")]
              ( tag "div" [("class", "sandbox-page-wrap")]
                  (tag "textarea" [("class", "sandbox-page"), ("name", "body"), ("rows", "30"), ("aria-label", "Markdown document body")] (text (docBody doc)))
                  <> tag "aside" [("class", "sandbox-side-panel")]
                    ( tag "div" [("class", "sandbox-side-card")]
                        ( tag "span" [("class", "card-id")] (text (docSlug doc))
                            <> tag "h2" [] (text (docDisplayTitle doc))
                            <> renderMarkdown (docBody doc)
                        )
                    )
              )
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
    ( tag "span" [("class", "sandbox-doc-meta")]
        ( tag "span" [("class", "sandbox-doc-icon"), ("aria-hidden", "true")] (text "md")
            <> tag "span" [("class", "card-id")] (text (docSummarySlug doc))
        )
        <> tag "strong" [] (text (docCardTitle doc))
        <> tag "span" [("class", "sandbox-doc-updated")] (text ("Updated " <> shortDateTime (docSummaryUpdatedAt doc)))
    )

docCardTitle :: SandboxDocSummary -> String
docCardTitle doc =
  let title = docSummaryTitle doc
      slug = docSummarySlug doc
   in if title == "" || title == slug
        then titleizeSlug slug
        else title

docDisplayTitle :: SandboxDoc -> String
docDisplayTitle doc =
  let title = docTitle doc
      slug = docSlug doc
   in if title == "" || title == slug
        then titleizeSlug slug
        else title

titleizeSlug :: String -> String
titleizeSlug slug =
  unwords (map capitalize (splitSlug slug))

splitSlug :: String -> [String]
splitSlug raw =
  case dropWhile (== '-') raw of
    "" -> []
    rest ->
      let (part, more) = break (== '-') rest
       in part : splitSlug more

capitalize :: String -> String
capitalize "" = ""
capitalize (first : rest) = toUpper first : rest

renderMarkdown :: String -> Html
renderMarkdown body =
  tag "div" [("class", "sandbox-rendered")] (renderLines (lines body))

renderLines :: [String] -> Html
renderLines [] = mempty
renderLines (line : rest)
  | isBlank line = renderLines rest
  | Just heading <- stripPrefix "### " line =
      tag "h4" [] (text heading) <> renderLines rest
  | Just heading <- stripPrefix "## " line =
      tag "h3" [] (text heading) <> renderLines rest
  | Just heading <- stripPrefix "# " line =
      tag "h2" [] (text heading) <> renderLines rest
  | isBulletLine line =
      let (items, more) = span isBulletLine (line : rest)
       in tag "ul" [] (foldMap renderBullet items) <> renderLines more
  | otherwise =
      let (paragraph, more) = break startsBlock rest
       in tag "p" [] (text (unwords (line : paragraph))) <> renderLines more

renderBullet :: String -> Html
renderBullet line =
  tag "li" [] (text (drop 2 line))

startsBlock :: String -> Bool
startsBlock line =
  isBlank line
    || isBulletLine line
    || hasPrefix "# " line
    || hasPrefix "## " line
    || hasPrefix "### " line

isBulletLine :: String -> Bool
isBulletLine =
  hasPrefix "- "

hasPrefix :: String -> String -> Bool
hasPrefix prefix value =
  case stripPrefix prefix value of
    Just _ -> True
    Nothing -> False

isBlank :: String -> Bool
isBlank =
  all isSpace

shortDateTime :: String -> String
shortDateTime raw =
  case words raw of
    date : timePart : _ -> date <> " " <> take 5 timePart
    date : _ -> date
    [] -> raw
