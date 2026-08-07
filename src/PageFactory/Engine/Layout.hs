module PageFactory.Engine.Layout
  ( document
  , renderFor
  ) where

-- Application shell: full HTML document, persistent container, and topbar.

import PageFactory.AgUi.Sidebar (globalAgentSidebar)
import PageFactory.Engine.Assets (appScript, css)
import PageFactory.Engine.Html (Html, raw, tag, text, voidTag)
import PageFactory.Engine.Http (RenderMode (..))

doctype :: Html
doctype = raw "<!doctype html>\n"

document :: String -> Html -> Html
document title body =
  doctype
    <> tag
      "html"
      [("lang", "ru")]
      ( tag
          "head"
          []
          ( voidTag "meta" [("charset", "utf-8")]
              <> voidTag "meta" [("name", "viewport"), ("content", "width=device-width, initial-scale=1")]
              <> tag "title" [] (text title)
              <> tag "style" [] (raw css)
          )
          <> tag "body" [] (container body <> tag "script" [] (raw appScript))
      )

container :: Html -> Html
container body =
  tag
    "div"
    [("class", "app-container"), ("data-page-container", "client-factory")]
    ( tag
        "div"
        [("class", "app-shell")]
        ( globalAgentSidebar
            <> tag
              "div"
              [("class", "content-shell")]
              (topbar <> body)
        )
    )

topbar :: Html
topbar =
  tag
    "nav"
    [("class", "topbar")]
    ( tag "a" [("href", "/"), ("class", "brand")] (text "Cakebox")
        <> tag
          "div"
          [("class", "nav-meta")]
          ( tag "span" [("class", "renderer-label")] (text "Haskell renderer")
              <> tag "span" [("class", "nav-spinner"), ("aria-hidden", "true")] mempty
          )
    )

renderFor :: RenderMode -> String -> Html -> Html
renderFor FullDocument title body = document title body
renderFor FragmentOnly _ body = body
