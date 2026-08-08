# Cakebox

[![CI](https://github.com/STih07/cakebox/actions/workflows/ci.yml/badge.svg)](https://github.com/STih07/cakebox/actions/workflows/ci.yml)
[![license MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GHC 9.6.7](https://img.shields.io/badge/GHC-9.6.7-5e5086.svg)](page-factory.cabal)
[![AG--UI stream](https://img.shields.io/badge/AG--UI-stream-2f7d58.svg)](docs/AG_UI_INTEGRATION.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Prototype for **Layered HTML**: typed Haskell-rendered page fragments, a tiny browser swap runtime, and an AI agent that can call UI tools.

The goal is small and practical:

```text
Haskell data/state
  -> typed HTML fragments
  -> SSE / AG-UI events
  -> browser layer swap or UI action
  -> traceable AI tool loop
```

This is not a React app with an AI chat bolted on. The server owns the routes, state, and render contract. The browser is mostly a thin executor.

## What Works

- Full document rendering from Haskell.
- Fragment rendering for page-level and nested slots.
- Browser navigation that swaps only the targeted layer.
- Persistent left-side AI chat.
- AI tools for:
  - `set_theme_color`
  - `open_client_page`
  - `render_client_fragment`
  - `update_order_draft`
- An `AI Trading` demo module with a first `Тикеры` tab.
- SQLite traces for chat messages, tool planning, tool results, UI actions, and provider errors.
- A pulled CopilotKit/Mastra reference app for comparison.

## Why

Modern frontend stacks are powerful, but many internal tools do not need a large client-side runtime for every interaction. This prototype asks a narrower question:

> How far can we get if Haskell renders typed HTML fragments, and the browser only swaps the requested layer?

Once AI is added, the same contract becomes useful as a tool boundary:

```text
user intent
  -> AI tool call
  -> Haskell validates/renders/updates
  -> AG-UI/SSE event
  -> browser applies the result
```

## Performance Snapshot

Measured on the current prototype, local server, August 2026:

| Item | Size / Time |
| --- | ---: |
| Haskell source | ~200 KB |
| Runtime SQLite traces | ~80 KB |
| Full home HTML | 27.8 KB, gzip ~8.0 KB |
| Full client HTML | 28.0 KB, gzip ~8.0 KB |
| Page fragment | 1.25 KB, gzip 574 B |
| Panel fragment | 399 B, gzip 299 B |
| Service memory | ~22 MB |
| Dev binary, unstripped | 90 MB |
| Stripped binary | 48 MB |
| Haskell full page via nginx/curl bench | ~14 ms avg |
| Haskell panel fragment via nginx/curl bench | ~12 ms avg |
| Direct backend full page single request | ~2.5-4 ms |
| Direct backend panel fragment single request | ~0.8-3.6 ms |

The `copilotkit-mastra-lab` folder is a reference app and is intentionally not representative of the Cakebox runtime size. Its local `node_modules` and `.next` artifacts are ignored by git.

## Run

```bash
cabal build
cabal run page-factory -- serve
```

The server listens on:

```text
127.0.0.1:8098
```

`AI Trading` reads live ticker data from Alpaca when these environment variables are present:

```bash
ALPACA_API_KEY_ID=...
ALPACA_API_SECRET_KEY=...
ALPACA_DATA_URL=https://data.alpaca.markets/v2
```

If the market data env is missing or Alpaca returns an error, the tickers tab renders an explicit error state instead of fake fallback prices.

In the current deployed setup, nginx exposes it on:

```text
http://91.98.192.241:8099/
```

## Fragment Requests

Full page:

```bash
curl http://127.0.0.1:8098/clients/1/overview
```

Page fragment:

```bash
curl \
  -H 'X-Render-Mode: fragment' \
  -H 'X-Requested-With: container' \
  http://127.0.0.1:8098/clients/1/overview
```

Nested panel fragment:

```bash
curl \
  -H 'X-Render-Mode: fragment' \
  -H 'X-Requested-With: container' \
  -H 'X-Render-Target: client-panel' \
  http://127.0.0.1:8098/clients/1/invoices
```

## AI / AG-UI Endpoint

```bash
curl -N -X POST http://127.0.0.1:8098/ag-ui/runs \
  -H 'Content-Type: application/json' \
  --data '{"threadId":"thread_test","runId":"run_test","messages":[{"role":"user","content":"Сделай тему спокойной зеленой #2f7d58 через set_theme_color."}]}'
```

The browser consumes the same stream and renders:

- assistant text;
- compact tool activity icons;
- UI actions such as theme changes and navigation;
- fragment previews when explicitly requested.

## Demo Flow

Try these in the left chat rail:

```text
Сделай тему спокойной зеленой #2f7d58 через set_theme_color.
```

```text
открой страницу клиента 1
```

```text
Покажи счета клиента 1 через render_client_fragment.
```

```text
Открой AI Trading тикеры, добавь PLTR и обнови котировки.
```

What to watch:

- the tool icon strip appears before assistant text;
- `open_client_page` navigates the main surface;
- `render_client_fragment` renders a preview inside chat;
- `open_trading_tickers`, `add_trading_ticker`, `remove_trading_ticker`, and `refresh_trading_quotes` mutate backend watchlist state and re-render `trading-panel`;
- screen controls in `trading-panel` call the same extension actions as the agent and apply the same `fragment.rendered` events;
- ticker cards navigate to detail pages such as `/ai-trading/tickers/NVDA`;
- traces land in `var/page-factory.sqlite3`.

## Module Map

```text
src/PageFactory/
  AgUi/       AG-UI input, event encoding, HTTP bridge, sidebar component
  Ai/         agent loop, provider client, chat state, SQLite trace store, tools
  App/        WAI server and route parsing
  Chat/       extension contract and enabled extension registry
  Clients/    demo domain model, CSV store, typed tabs, views
  Engine/     tiny HTML DSL, render modes, layout, CSS/JS assets
  Trading/    Alpaca data source, backend watchlist state, views, and chat extension
```

Domain modules can expose chat extensions: prompt context, tool schemas, and tool execution. The agent runtime collects enabled extensions before planning, so feature modules can add capabilities without hard-coding their tools into the provider client.

## Current Limits

- CSS and JS are inline Haskell strings.
- The HTML DSL is intentionally tiny.
- Client data is CSV.
- Fragment targets are still stringly typed at the HTTP boundary.
- The benchmark harness is simple curl timing, not a rigorous profiler.
- The AI provider path is OpenAI-compatible but still prototype-grade.

## Publish Status

This repo is ready for an early public prototype story, not for a packaged Haskell library release yet.

Good public framing:

> A tiny Haskell experiment in server-rendered UI fragments, AG-UI style streams, and AI tools that mutate real page state instead of hallucinating UI.
