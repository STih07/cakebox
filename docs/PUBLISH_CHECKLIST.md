# Publish Checklist

## Repository

- Pick a public repo name:
  - `cakebox`
  - `cakebox-haskell`
  - `layered-html-haskell`
- Add a short description:
  - `Cakebox: typed Haskell-rendered HTML fragments with an AG-UI style AI tool loop.`
- Add topics:
  - `haskell`
  - `server-rendered-html`
  - `html-fragments`
  - `ag-ui`
  - `ai-agents`
  - `wai`
  - `warp`
  - `sqlite`
- Push `main`.
- Add a license before serious public sharing.
  - Suggested: `MIT` for a small prototype.
- Add screenshots or a short demo GIF.
- Keep runtime files ignored:
  - `var/`
  - `dist-newstyle/`
  - `.next/`
  - `node_modules/`

## README Before Public Link

- Confirm public server URL still works.
- Confirm AI provider secrets are not committed.
- Run:

```bash
git status --short
cabal build
curl -sS http://127.0.0.1:8098/health
```

- Re-run payload size checks:

```bash
curl -sS -o /tmp/page-home.html http://127.0.0.1:8098/
curl -sS -o /tmp/page-client.html http://127.0.0.1:8098/clients/1/overview
gzip -c /tmp/page-home.html | wc -c
gzip -c /tmp/page-client.html | wc -c
```

## Article

Suggested title:

```text
Cakebox: Layered HTML in Haskell with tiny fragments and AI tools
```

Suggested subtitle:

```text
A small experiment in server-rendered UI fragments where an AI agent mutates real page state through typed Haskell tools.
```

Core claims to keep honest:

- This is a prototype, not a framework.
- The browser runtime is small and imperative by design.
- Haskell owns render/state/tool contracts.
- AI tool calls are traced in SQLite.
- Fragment payloads are tiny.
- GHC binary size is not tiny, but it is not frontend payload.

## Demo Script

1. Open the app.
2. Click or type:

```text
Сделай тему спокойной зеленой #2f7d58 через set_theme_color.
```

3. Show the compact tool icon strip.
4. Type:

```text
открой страницу клиента 1
```

5. Show main page navigation to `/clients/1/overview`.
6. Type:

```text
Покажи счета клиента 1 через render_client_fragment.
```

7. Show fragment preview inside chat.
8. Show SQLite trace rows for the run.
