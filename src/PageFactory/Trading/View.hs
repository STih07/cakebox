module PageFactory.Trading.View
  ( aiTradingView
  , tickerDetailView
  , tradingPanel
  ) where

-- AI Trading views and fragment renderers.

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
        <> tradingPanel quotesResult
    )

tradingTabs :: Html
tradingTabs =
  tag
    "nav"
    [("class", "tabs trading-tabs"), ("aria-label", "AI Trading tabs")]
    (tag "a" [("class", "tab active"), ("href", "/ai-trading/tickers")] (text "Тикеры"))

tradingPanel :: Either String [TickerQuote] -> Html
tradingPanel quotesResult =
  tag
    "section"
    [("class", "panel trading-panel"), ("data-fragment-slot", "trading-panel")]
    ( tradingControls
        <> case quotesResult of
          Left message -> tradingError message
          Right quotes -> tag "div" [("class", "ticker-grid")] (foldMap tickerCard quotes)
    )

tradingControls :: Html
tradingControls =
  tag
    "form"
    [ ("class", "trading-controls")
    , ("data-extension-action-form", "add_trading_ticker")
    ]
    ( tag
        "input"
        [ ("name", "symbol")
        , ("placeholder", "Ticker")
        , ("autocomplete", "off")
        , ("aria-label", "Ticker symbol")
        ]
        mempty
        <> tag "button" [("type", "submit")] (text "Add")
        <> tag
          "button"
          [ ("type", "button")
          , ("data-extension-action", "refresh_trading_quotes")
          , ("aria-label", "Refresh quotes")
          , ("title", "Refresh quotes")
          ]
          (text "Refresh")
    )

tickerCard :: TickerQuote -> Html
tickerCard quote =
  tag
    "article"
    [("class", "ticker-card")]
    ( tag
        "a"
        [ ("class", "ticker-card-link")
        , ("href", "/ai-trading/tickers/" <> quoteSymbol quote)
        ]
        ( tag "span" [("class", "card-id")] (text (quoteTheme quote))
            <> tag "strong" [] (text (quoteSymbol quote))
            <> tag "span" [] (text (quotePrice quote))
            <> tag "em" [("class", statusClass quote)] (text (quoteLabel quote))
        )
        <> tag
          "button"
          [ ("type", "button")
          , ("class", "ticker-remove")
          , ("data-extension-action", "remove_trading_ticker")
          , ("data-symbol", quoteSymbol quote)
          , ("aria-label", "Remove " <> quoteSymbol quote)
          , ("title", "Remove " <> quoteSymbol quote)
          ]
          (text "Remove")
    )

tickerDetailView :: String -> Either String [TickerQuote] -> Html
tickerDetailView symbol quotesResult =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "ai-trading-ticker")]
    ( tag "a" [("class", "back"), ("href", "/ai-trading/tickers")] (text "← Тикеры")
        <> tag "section" [("class", "profile trading-hero")]
          ( tag "p" [("class", "eyebrow")] (text "AI Trading")
              <> tag "h1" [] (text symbol)
              <> tag "p" [] (text "Большая карточка тикера: live quote из Alpaca, состояние доступности и быстрые действия с watchlist.")
          )
        <> tickerDetailPanel symbol quotesResult
    )

tickerDetailPanel :: String -> Either String [TickerQuote] -> Html
tickerDetailPanel symbol quotesResult =
  tag
    "section"
    [("class", "panel ticker-detail-panel"), ("data-fragment-slot", "ticker-detail-panel")]
    (case quotesResult of
      Left message -> tradingError message
      Right (quote : _) -> tickerDetailCard quote
      Right [] -> tradingError ("Ticker " <> symbol <> " returned no quote")
    )

tickerDetailCard :: TickerQuote -> Html
tickerDetailCard quote =
  tag
    "article"
    [("class", "ticker-detail-card")]
    ( tag "span" [("class", "card-id")] (text (quoteTheme quote))
        <> tag "strong" [] (text (quoteSymbol quote))
        <> tag "span" [("class", "ticker-detail-price")] (text (quotePrice quote))
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
