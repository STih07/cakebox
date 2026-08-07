module PageFactory.Trading
  ( aiTradingView
  ) where

-- Demo AI Trading module. It starts with one tab: tickers.

import PageFactory.Engine (Html, tag, text)

aiTradingView :: Html
aiTradingView =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "ai-trading")]
    ( tag "section" [("class", "profile trading-hero")]
        ( tag "p" [("class", "eyebrow")] (text "AI Trading")
            <> tag "h1" [] (text "Тикеры")
            <> tag "p" [] (text "Первый торговый модуль Cakebox: server-rendered watchlist, готовый для агентских actions, сигналов и будущих фрагментов рынка.")
        )
        <> tradingTabs
        <> tickerPanel
    )

tradingTabs :: Html
tradingTabs =
  tag
    "nav"
    [("class", "tabs trading-tabs"), ("aria-label", "AI Trading tabs")]
    (tag "a" [("class", "tab active"), ("href", "/ai-trading/tickers")] (text "Тикеры"))

tickerPanel :: Html
tickerPanel =
  tag
    "section"
    [("class", "panel trading-panel"), ("data-fragment-slot", "trading-panel")]
    ( tag "div" [("class", "ticker-grid")]
        ( tickerCard "NVDA" "AI compute" "+2.4%" "Momentum"
            <> tickerCard "AMD" "Semis" "+1.1%" "Watch"
            <> tickerCard "TSLA" "Volatility" "-0.7%" "Risk"
            <> tickerCard "RKLB" "Space beta" "+3.8%" "Breakout"
        )
    )

tickerCard :: String -> String -> String -> String -> Html
tickerCard symbol theme move label =
  tag
    "article"
    [("class", "ticker-card")]
    ( tag "span" [("class", "card-id")] (text theme)
        <> tag "strong" [] (text symbol)
        <> tag "span" [] (text move)
        <> tag "em" [("class", "status ok")] (text label)
    )
