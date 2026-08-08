module PageFactory.AgUi.Sidebar
  ( globalAgentSidebar
  ) where

-- Persistent AG-UI chat sidebar component.

import PageFactory.Engine.Html (Html, tag, text)

globalAgentSidebar :: Html
globalAgentSidebar =
  tag
    "aside"
    [("class", "global-agent-sidebar"), ("data-fragment-slot", "global-agent-sidebar")]
    ( tag
        "button"
        [ ("class", "sidebar-tab")
        , ("type", "button")
        , ("data-sidebar-toggle", "global-agent-sidebar")
        , ("aria-label", "Свернуть чат")
        , ("title", "Свернуть чат")
        ]
        (text "‹")
        <> tag
        "div"
        [ ("class", "agent-panel sidebar-agent-panel")
        , ("data-agent-panel", "global-assistant")
        , ("data-agent-stream-url", "/ag-ui/runs")
        , ("data-agent-thread-id", "global-assistant")
        ]
        ( tag "div" [("class", "agent-status"), ("data-agent-status", "idle")] mempty
            <> tag
              "div"
              [("class", "agent-log"), ("data-agent-log", "global-assistant")]
              ( tag
                  "div"
                  [("class", "agent-event assistant welcome")]
                  (tag "p" [] (text "Привет. Я могу вести диалог, менять UI через tools и рендерить Haskell-фрагменты без перезагрузки страницы."))
              )
            <> tag
              "div"
              [("class", "agent-fragment-preview is-empty"), ("data-fragment-slot", "agent-tool-fragment")]
              mempty
            <> tag
              "div"
              [("class", "agent-prompts")]
              ( promptButton "Тема" "Сделай тему спокойной зеленой #2f7d58 через set_theme_color."
                  <> promptButton "Тикеры" "Открой AI Trading тикеры, добавь PLTR и обнови котировки."
                  <> promptButton "Sandbox" "Открой Sandbox и создай markdown документ ideas с коротким планом."
                  <> promptButton "Заказ" "Заполни заказ для Alice Carter из Germany на сумму 640, статус Needs review через update_order_draft."
                  <> promptButton "Счета" "Покажи счета клиента 1 через render_client_fragment."
              )
            <> tag
              "form"
              [("class", "agent-form"), ("data-agent-form", "global-assistant")]
              ( tag
                  "textarea"
                  [ ("name", "message")
                  , ("rows", "3")
                  , ("placeholder", "Сообщение... Cmd+Enter")
                  ]
                  mempty
                  <> tag "button" [("type", "submit"), ("aria-label", "Отправить"), ("title", "Отправить")] (text "↑")
              )
        )
    )

promptButton :: String -> String -> Html
promptButton label message =
  tag
    "button"
    [("type", "button"), ("data-agent-prompt", message)]
    (text label)
