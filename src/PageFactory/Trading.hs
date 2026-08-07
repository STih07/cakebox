module PageFactory.Trading
  ( aiTradingView
  , tradingPanel
  ) where

-- AI Trading module. It starts with one tab: tickers.

import PageFactory.Engine (Html, tag, text)
import PageFactory.Trading.DataSource (TickerQuote (..))

aiTradingView :: Either String [TickerQuote] -> Html
aiTradingView quotesResult =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "ai-trading")]
    ( tag "section" [("class", "profile trading-hero")]
        ( tag "p" [("class", "eyebrow")] (text "AI Trading")
            <> tag "h1" [] (text "Тикеры")
            <> tag "p" [] (text "Первый торговый модуль Cakebox: server-rendered watchlist, готовый для агентских actions, сигналов и будущих фрагментов рынка.")
        )
        <> tradingTabs
        <> tickerPanel quotesResult
    )

tradingTabs :: Html
tradingTabs =
  tag
    "nav"
    [("class", "tabs trading-tabs"), ("aria-label", "AI Trading tabs")]
    (tag "a" [("class", "tab active"), ("href", "/ai-trading/tickers")] (text "Тикеры"))

tickerPanel :: Either String [TickerQuote] -> Html
tickerPanel quotesResult =
  tradingPanel quotesResult

tradingPanel :: Either String [TickerQuote] -> Html
tradingPanel quotesResult =
  tag
    "section"
    [("class", "panel trading-panel"), ("data-fragment-slot", "trading-panel")]
    (case quotesResult of
      Left message -> tradingError message
      Right quotes -> tag "div" [("class", "ticker-grid")] (foldMap tickerCard quotes)
    )

tickerCard :: TickerQuote -> Html
tickerCard quote =
  tag
    "article"
    [("class", "ticker-card")]
    ( tag "span" [("class", "card-id")] (text (quoteTheme quote))
        <> tag "strong" [] (text (quoteSymbol quote))
        <> tag "span" [] (text (quotePrice quote))
        <> tag "em" [("class", statusClass quote)] (text (quoteLabel quote))
    )

statusClass :: TickerQuote -> String
statusClass quote
  | quoteIsLive quote = "status ok"
  | otherwise = "status debt"

tradingError :: String -> Html
tradingError message =
  tag
    "div"
    [("class", "trading-error")]
    ( tag "strong" [] (text "Market data unavailable")
        <> tag "p" [] (text message)
    )
