module PageFactory.Clients.Views
  ( clientFileName
  , clientPanel
  , clientView
  , indexView
  ) where

-- HTML views for client index, profile, and nested client panels.

import Data.Char (isAlphaNum)
import PageFactory.Clients.Model (Client (..), ClientTab (..))
import PageFactory.Clients.Tabs (clientTabPath, clientTabTitle, clientTabs)
import PageFactory.Engine (Html, tag, text)

clientView :: Client -> ClientTab -> Html
clientView client activeTab =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "client-profile")]
    ( tag "a" [("class", "back"), ("href", "/")] (text "Все клиенты")
        <> tag "section" [("class", "profile")]
          ( tag "p" [("class", "eyebrow")] (text ("ID " <> show (clientId client)))
              <> tag "h1" [] (text (clientName client))
              <> tag "dl" [("class", "facts")]
                ( fact "Email" (clientEmail client)
                    <> fact "Баланс" (show (clientBalance client))
                    <> fact "Статус" (statusText client)
                )
          )
        <> clientWorkspace client activeTab
    )

clientWorkspace :: Client -> ClientTab -> Html
clientWorkspace client activeTab =
  tag
    "section"
    [("class", "client-workspace"), ("data-layer", "client")]
    ( tag "div" [("class", "tabs"), ("role", "tablist")] (mconcat (map (clientTabLink client activeTab) clientTabs))
        <> clientPanel client activeTab
    )

clientTabLink :: Client -> ClientTab -> ClientTab -> Html
clientTabLink client activeTab tabName =
  tag
    "a"
    [ ("href", clientTabPath client tabName)
    , ("class", if tabName == activeTab then "tab active" else "tab")
    , ("data-fragment-target", "client-panel")
    ]
    (text (clientTabTitle tabName))

clientPanel :: Client -> ClientTab -> Html
clientPanel client activeTab =
  tag
    "div"
    [("class", "panel"), ("data-fragment-slot", "client-panel")]
    ( case activeTab of
        OverviewTab ->
          tag "h2" [] (text "Обзор")
            <> tag "p" [] (text ("Клиент " <> clientName client <> " сейчас находится в статусе: " <> statusText client <> "."))
            <> tag "div" [("class", "metrics")]
              (metric "LTV" ("$" <> show (abs (clientBalance client) * 14 + 4200)) <> metric "Риск" (riskLabel client))
        InvoicesTab ->
          tag "h2" [] (text "Счета")
            <> tag "p" [] (text "Это вложенный фрагмент: при переключении вкладок меняется только эта панель.")
            <> tag "ul" [("class", "invoice-list")]
              ( invoice ("INV-" <> show (clientId client) <> "01") "Оплачен"
                  <> invoice ("INV-" <> show (clientId client) <> "02") (if clientBalance client < 0 then "Просрочен" else "Ожидает оплаты")
              )
        ActivityTab ->
          tag "h2" [] (text "Активность")
            <> tag "ol" [("class", "timeline")]
              ( activity "Профиль открыт через Haskell renderer"
                  <> activity "Контейнер сохранил header без перезагрузки"
                  <> activity "Внутренняя вкладка загрузилась отдельным фрагментом"
              )
        AiTab ->
          tag "h2" [] (text "AI")
            <> tag "p" [] (text "Глобальный чат теперь живет слева в persistent sidebar. Эта вкладка остается рабочей surface-зоной для state, frontend actions и сегментарного render.")
            <> tag
              "section"
              [("class", "haskell-control-surface"), ("data-haskell-surface", "order")]
              ( tag
                  "div"
                  [("class", "order-card"), ("data-order-draft", "true")]
                  ( tag "h3" [] (text "Order draft")
                      <> orderField "orderId" "Order ID" ("PF-" <> show (clientId client) <> "130")
                      <> orderField "customer" "Customer" (clientName client)
                      <> orderField "country" "Country" "Germany"
                      <> orderField "total" "Total" (show (abs (clientBalance client) + 286))
                      <> orderField "shippingMethod" "Shipping" "EU express"
                      <> orderField "status" "Status" "Draft"
                  )
                  <> tag
                    "aside"
                    [("class", "agent-memory"), ("data-agent-memory", "true")]
                    ( tag "h3" [] (text "Agent state")
                        <> tag "p" [] (tag "span" [] (text "Theme: ") <> tag "strong" [("data-state-field", "preferredTheme")] (text "#35535b"))
                        <> tag "p" [] (tag "span" [] (text "Last order: ") <> tag "strong" [("data-state-field", "lastOrderId")] (text "none"))
                        <> tag "ul" [("data-state-notes", "true")] (tag "li" [] (text "No state notes yet"))
                    )
              )
    )

metric :: String -> String -> Html
metric label value =
  tag "div" [("class", "metric")] (tag "span" [] (text label) <> tag "strong" [] (text value))

invoice :: String -> String -> Html
invoice invoiceId state =
  tag "li" [] (tag "strong" [] (text invoiceId) <> tag "span" [] (text state))

orderField :: String -> String -> String -> Html
orderField name label value =
  tag
    "label"
    [("class", "order-field")]
    ( tag "span" [] (text label)
        <> tag "input" [("name", name), ("value", value), ("data-order-field", name)] mempty
    )

activity :: String -> Html
activity item = tag "li" [] (text item)

riskLabel :: Client -> String
riskLabel client
  | clientBalance client < 0 = "повышенный"
  | otherwise = "низкий"

indexView :: [Client] -> Html
indexView clients =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "client-index")]
    ( tag "section" [("class", "intro")]
        ( tag "p" [("class", "eyebrow")] (text "Haskell page factory")
            <> tag "h1" [] (text "Клиентские страницы")
            <> tag "p" [] (text "Один рендерер умеет отдавать полный документ напрямую и фрагмент для внешнего контейнера.")
            <> demoLinks
        )
        <> tag "section" [("class", "grid")] (mconcat (map clientCard clients))
    )

demoLinks :: Html
demoLinks =
  tag
    "nav"
    [("class", "demo-links"), ("aria-label", "Cakebox demo links")]
    ( demoLink "/ai-trading/tickers" "AI Trading" "Ticker watchlist module"
        <> demoLink "/models" "Models" "Entity model builder"
        <> demoLink "/sandbox" "Sandbox" "Markdown document catalog"
        <> demoLink "/stories" "Cakebook" "Haskell component gallery"
        <> demoLink "/clients/1/overview" "Client page" "Full page fragment navigation"
        <> demoLink "/clients/1/ai" "AI surface" "State and tool actions"
        <> demoLink "/clients/1/invoices" "Nested panel" "Swap only one slot"
    )

demoLink :: String -> String -> String -> Html
demoLink href label caption =
  tag
    "a"
    [("class", "demo-link"), ("href", href)]
    (tag "strong" [] (text label) <> tag "span" [] (text caption))

clientCard :: Client -> Html
clientCard client =
  tag
    "a"
    [("class", "card"), ("href", "/clients/" <> show (clientId client))]
    ( tag "span" [("class", "card-id")] (text ("#" <> show (clientId client)))
        <> tag "strong" [] (text (clientName client))
        <> tag "span" [] (text (clientEmail client))
        <> tag "em" [("class", statusClass client)] (text (statusText client))
    )

fact :: String -> String -> Html
fact label value =
  tag "div" [] (tag "dt" [] (text label) <> tag "dd" [] (text value))

statusText :: Client -> String
statusText client
  | clientBalance client < 0 = "Есть задолженность"
  | otherwise = "Баланс в порядке"

statusClass :: Client -> String
statusClass client
  | clientBalance client < 0 = "status debt"
  | otherwise = "status ok"

clientFileName :: Client -> FilePath
clientFileName client = "client-" <> show (clientId client) <> "-" <> slugify (clientName client) <> ".html"

slugify :: String -> String
slugify input =
  let chars = map normalize input
      collapsed = collapseDashes chars
   in trimDash collapsed
  where
    normalize c
      | isAlphaNum c = c
      | otherwise = '-'

    collapseDashes [] = []
    collapseDashes ('-' : '-' : xs) = collapseDashes ('-' : xs)
    collapseDashes (x : xs) = x : collapseDashes xs

    trimDash = reverse . dropWhile (== '-') . reverse . dropWhile (== '-')
