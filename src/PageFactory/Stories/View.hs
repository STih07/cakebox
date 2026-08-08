module PageFactory.Stories.View
  ( storyIndexView
  , storyView
  ) where

-- Native component gallery for Haskell-rendered UI pieces.

import PageFactory.Engine (Html, tag, text)
import PageFactory.Sandbox.Store (SandboxDoc (..), SandboxDocSummary (..))
import PageFactory.Sandbox.View (sandboxCatalogView, sandboxDocumentFragment)
import PageFactory.Trading.DataSource (TickerQuote (..))
import PageFactory.Trading.View (tickerDetailView, tradingPanel)

storyIndexView :: Html
storyIndexView =
  storyShell
    "Cakebook"
    "Component stories"
    ( tag "section" [("class", "story-grid")]
        ( storyLink "/stories/sandbox" "Sandbox" "Catalog cards and document editor"
            <> storyLink "/stories/trading" "AI Trading" "Ticker panel, error state, and detail card"
            <> storyLink "/stories/agent" "Agent rail" "Chat messages, tool strip, prompts, and input"
        )
    )

storyView :: String -> Html
storyView slug =
  case slug of
    "sandbox" -> sandboxStories
    "trading" -> tradingStories
    "agent" -> agentStories
    _ -> storyIndexView

sandboxStories :: Html
sandboxStories =
  storyShell
    "Sandbox"
    "Markdown documents"
    ( storyFrame "Catalog"
        (sandboxCatalogView sampleDocs)
        <> storyFrame "Document editor"
          (sandboxDocumentFragment sampleDoc)
    )

tradingStories :: Html
tradingStories =
  storyShell
    "AI Trading"
    "Ticker fragments"
    ( storyFrame "Watchlist"
        (tradingPanel (Right sampleQuotes))
        <> storyFrame "Error state"
          (tradingPanel (Left "Alpaca credentials are missing. Configure ALPACA_API_KEY_ID and ALPACA_API_SECRET_KEY."))
        <> storyFrame "Ticker detail"
          (tickerDetailView "NVDA" (Right [head sampleQuotes]))
    )

agentStories :: Html
agentStories =
  storyShell
    "Agent Rail"
    "Persistent assistant UI states"
    ( storyFrame "Conversation"
        ( tag "section" [("class", "agent-panel story-agent-panel")]
            ( tag "div" [("class", "agent-log")]
                ( tag "div" [("class", "agent-event assistant")]
                    (tag "p" [] (text "I can create Sandbox documents, update fragments, and navigate the Haskell-rendered UI."))
                    <> tag "div" [("class", "agent-event user")]
                      (tag "p" [] (text "Create a roadmap document."))
                    <> tag "div" [("class", "agent-event tool-strip")]
                      ( toolIcon "start"
                          <> toolIcon "ui"
                          <> toolIcon "state"
                          <> toolIcon "done"
                      )
                    <> tag "div" [("class", "agent-event assistant")]
                      (tag "p" [] (text "Done. I created roadmap and opened it in Sandbox."))
                )
                <> tag "div" [("class", "agent-prompts")]
                  ( tag "button" [("type", "button")] (text "Sandbox")
                      <> tag "button" [("type", "button")] (text "Tickers")
                      <> tag "button" [("type", "button")] (text "Theme")
                  )
                <> tag "form" [("class", "agent-form")]
                  ( tag "textarea" [("rows", "3"), ("placeholder", "Message... Cmd+Enter")] mempty
                      <> tag "button" [("type", "button")] (text "↑")
                  )
            )
        )
    )

storyShell :: String -> String -> Html -> Html
storyShell title subtitle body =
  tag
    "main"
    [("class", "shell story-shell"), ("data-render-part", "stories")]
    ( tag "section" [("class", "profile story-hero")]
        ( tag "p" [("class", "eyebrow")] (text "Cakebook")
            <> tag "h1" [] (text title)
            <> tag "p" [] (text subtitle)
            <> storyNav
        )
        <> body
    )

storyNav :: Html
storyNav =
  tag
    "nav"
    [("class", "tabs story-tabs"), ("aria-label", "Story navigation")]
    ( tag "a" [("class", "tab"), ("href", "/stories")] (text "Index")
        <> tag "a" [("class", "tab"), ("href", "/stories/sandbox")] (text "Sandbox")
        <> tag "a" [("class", "tab"), ("href", "/stories/trading")] (text "Trading")
        <> tag "a" [("class", "tab"), ("href", "/stories/agent")] (text "Agent")
    )

storyLink :: String -> String -> String -> Html
storyLink href title caption =
  tag
    "a"
    [("class", "story-card"), ("href", href)]
    ( tag "strong" [] (text title)
        <> tag "span" [] (text caption)
    )

storyFrame :: String -> Html -> Html
storyFrame label content =
  tag
    "section"
    [("class", "story-frame")]
    ( tag "header" [] (tag "h2" [] (text label))
        <> tag "div" [("class", "story-stage")] content
    )

toolIcon :: String -> Html
toolIcon name =
  tag "span" [("class", "tool-icon is-active"), ("data-story-icon", name)] (text "✓")

sampleDocs :: [SandboxDocSummary]
sampleDocs =
  [ SandboxDocSummary "roadmap" "Roadmap" "2026-08-08 19:04:00 UTC"
  , SandboxDocSummary "agent-notes" "Agent Notes" "2026-08-08 19:05:00 UTC"
  , SandboxDocSummary "design-system" "Design System" "2026-08-08 19:06:00 UTC"
  ]

sampleDoc :: SandboxDoc
sampleDoc =
  SandboxDoc
    { docSlug = "roadmap"
    , docTitle = "Roadmap"
    , docBody = "# Roadmap\n\n## Next\n\n- Add Cakebook stories\n- Build reusable Haskell UI components\n- Let the agent assemble safe fragments"
    , docUpdatedAt = "2026-08-08 19:06:00 UTC"
    }

sampleQuotes :: [TickerQuote]
sampleQuotes =
  [ TickerQuote "NVDA" "AI infrastructure" "$184.22" "Live quote" True
  , TickerQuote "AAPL" "Consumer hardware" "$229.35" "Live quote" True
  , TickerQuote "PLTR" "Data platforms" "$72.10" "Delayed" False
  ]
