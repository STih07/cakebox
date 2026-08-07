# Haskell Page Factory

Prototype for **Layered HTML** / **слоеный HTML**.

> The server renders typed fragments. The browser replaces only the requested layer.

Фабрика страниц на Haskell с двумя режимами рендеринга:

- прямой запрос получает полный HTML-документ с контейнером;
- запрос из контейнера получает только нужный HTML-фрагмент.

HTTP-запуск:

```bash
page-factory serve
```

Сервис слушает `127.0.0.1:8098`. Наружу его отдает nginx на `:8099`.

Прямой запрос:

```bash
curl http://127.0.0.1:8098/clients/2
```

Запрос из контейнера:

```bash
curl -H 'X-Render-Mode: fragment' http://127.0.0.1:8098/clients/2
```

Также фрагмент можно запросить через:

```bash
curl 'http://127.0.0.1:8098/clients/2?fragment=1'
```

Вложенный фрагмент второго слоя:

```bash
curl \
  -H 'X-Render-Mode: fragment' \
  -H 'X-Render-Target: client-panel' \
  http://127.0.0.1:8098/clients/2/invoices
```

AG-UI stream demo:

```bash
curl -N http://127.0.0.1:8098/ag-ui/runs
```

AG-UI `RunAgentInput` через POST:

```bash
curl -N -X POST http://127.0.0.1:8098/ag-ui/runs \
  -H 'Content-Type: application/json' \
  --data '{"threadId":"thread_test","runId":"run_test","messages":[{"role":"user","content":"hello layered html"}]}'
```

В браузере это соответствует переходу:

```text
app-container
  topbar                  остается
  client-profile <main>   остается
    tabs                  остаются
    client-panel          заменяется
```

Статическая генерация пока сохранена:

```bash
cabal run page-factory -- generate
```

Идея архитектуры:

- `src/Main.hs` — CLI entrypoint.
- `src/PageFactory/App/Server.hs` — WAI app, `serve`, `generate`, response selection.
- `src/PageFactory/App/Routes.hs` — route parsing.
- `src/PageFactory/AgUi/Input.hs` — минимальный `RunAgentInput` parser.
- `src/PageFactory/AgUi/Events.hs` — AG-UI event JSON/SSE encoding.
- `src/PageFactory/AgUi/Server.hs` — AG-UI HTTP endpoint.
- `src/PageFactory/Ai/*` — внутренний AI event layer и adapter в AG-UI.
- `src/PageFactory/Clients.hs` — facade для клиентских модулей.
- `src/PageFactory/Clients/Model.hs` — client/domain types.
- `src/PageFactory/Clients/Store.hs` — CSV loading.
- `src/PageFactory/Clients/Tabs.hs` — tab slugs, labels, paths.
- `src/PageFactory/Clients/Views.hs` — client/index/panel HTML views.
- `src/PageFactory/Engine.hs` — facade для движка.
- `src/PageFactory/Engine/Html.hs` — tiny HTML DSL.
- `src/PageFactory/Engine/Http.hs` — render mode, target, WAI responses.
- `src/PageFactory/Engine/Layout.hs` — full document and app shell.
- `src/PageFactory/Engine/Assets.hs` — inline CSS and browser fragment navigation.
- встроенный клиентский скрипт перехватывает внутренние ссылки, делает fragment-запрос и заменяет нужный слой с fade/blur переходом.
- ссылки с `data-fragment-target` заменяют вложенный `[data-fragment-slot]`, например вкладки клиента.
- `loadClients` пока читает CSV, но его можно заменить на поток из БД.

Документы:

- `docs/ARCHITECTURE.md`
- `docs/FRAGMENT_CONTRACT.md`
- `docs/AG_UI_INTEGRATION.md`
- `docs/ROADMAP.md`
