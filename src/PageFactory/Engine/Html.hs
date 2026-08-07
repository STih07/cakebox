module PageFactory.Engine.Html
  ( Html (..)
  , raw
  , tag
  , text
  , voidTag
  , writePage
  ) where

-- Minimal HTML DSL: escaping, tags, fragments, and file output.

newtype Html = Html {renderHtml :: String}

instance Semigroup Html where
  Html a <> Html b = Html (a <> b)

instance Monoid Html where
  mempty = Html ""

text :: String -> Html
text = Html . escapeHtml

raw :: String -> Html
raw = Html

tag :: String -> [(String, String)] -> Html -> Html
tag name attrs body =
  raw ("<" <> name <> renderAttrs attrs <> ">")
    <> body
    <> raw ("</" <> name <> ">\n")

voidTag :: String -> [(String, String)] -> Html
voidTag name attrs = raw ("<" <> name <> renderAttrs attrs <> ">\n")

renderAttrs :: [(String, String)] -> String
renderAttrs [] = ""
renderAttrs attrs =
  concatMap (\(key, value) -> " " <> key <> "=\"" <> escapeHtml value <> "\"") attrs

escapeHtml :: String -> String
escapeHtml = concatMap escapeChar
  where
    escapeChar '<' = "&lt;"
    escapeChar '>' = "&gt;"
    escapeChar '&' = "&amp;"
    escapeChar '"' = "&quot;"
    escapeChar '\'' = "&#39;"
    escapeChar c = [c]

writePage :: FilePath -> Html -> IO ()
writePage path = writeFile path . renderHtml

