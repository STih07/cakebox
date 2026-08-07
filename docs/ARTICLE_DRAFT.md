# Cakebox: Layered HTML in Haskell with tiny fragments and AI tools

I wanted to test a small idea:

> What if the server owns the UI contract, the browser only swaps named layers, and an AI agent talks to that system through real tools?

The result is a prototype called **Cakebox**. It is not a framework yet. It is a working experiment: Haskell renders full pages and typed HTML fragments, a tiny browser runtime swaps fragments in place, and an AI agent can call tools that change theme, navigate to client pages, update visible state, or render a fragment preview.

## The shape

The pipeline looks like this:

```text
Haskell data/state
  -> typed HTML fragments
  -> SSE / AG-UI events
  -> browser layer swap or UI action
  -> traceable AI tool loop
```

The browser is intentionally boring. It intercepts local links, asks the server for a fragment, finds the matching slot, and replaces it.

A full request returns the document:

```text
app shell
  topbar
  page content
```

A fragment request returns only the replaceable layer:

```text
main[data-render-part="client-profile"]
```

A nested fragment can target a smaller slot:

```text
div[data-fragment-slot="client-panel"]
```

This gives the app a SPA-like feel without making the browser the owner of the domain model.

## Why Haskell?

The useful part is not just server-side rendering. The useful part is naming the pieces with types.

For example, client tabs are not just strings floating through templates:

```haskell
data ClientTab = OverviewTab | InvoicesTab | ActivityTab | AiTab
```

That type can line up routes, labels, URLs, and rendered panels. The current prototype is still small and some boundaries are stringly typed, but the direction is:

```text
typed route
  -> typed domain state
  -> typed render choice
  -> HTML layer
```

## Where the AI agent fits

The AI agent does not invent UI in the browser. It calls tools.

Current tools:

- `set_theme_color`
- `open_client_page`
- `render_client_fragment`
- `update_order_draft`

That distinction matters. `open_client_page` is a navigation tool. It emits a UI action that the browser applies through the same fragment navigation path as a normal click.

`render_client_fragment` is different. It renders a preview fragment inside the chat. Early in the prototype I mixed those ideas and the agent said "I opened the client page" while the page did not actually navigate. The trace made the bug obvious: the wrong tool had been called.

That is the nice thing about forcing AI through tools. When the model is wrong, the failure is inspectable.

## Tracing

Every run writes to SQLite:

- chat messages;
- tool planning calls;
- tool start/result;
- custom UI actions;
- state updates;
- provider errors.

For a theme change, the trace shows:

```json
{"name":"set_theme_color","arguments":"{\"themeColor\":\"#2f7d58\"}"}
```

For client navigation, it shows:

```json
{"action":"navigate","url":"/clients/1/overview"}
```

This made several prototype bugs easy to understand:

- a dangling user turn caused the next run to execute two commands;
- a fragment preview tool was used when navigation was intended;
- UTF-8 payloads were initially written incorrectly to SQLite.

All three were fixed at the tool/state boundary rather than hidden in UI glue.

## Payload size

The current demo is tiny on the wire:

| Item | Size |
| --- | ---: |
| Full home HTML | 27.8 KB, gzip ~8.0 KB |
| Full client HTML | 28.0 KB, gzip ~8.0 KB |
| Page fragment | 1.25 KB, gzip 574 B |
| Panel fragment | 399 B, gzip 299 B |

The Haskell service uses about 22 MB of memory in the current deployment. The dev binary is large, because GHC binaries are large: about 90 MB unstripped, 48 MB stripped. That is backend weight, not frontend payload.

For rough timing, a simple curl benchmark through nginx currently shows:

| Route | Avg |
| --- | ---: |
| Haskell full page | ~14 ms |
| Haskell panel fragment | ~12 ms |
| Health endpoint | ~13 ms |

Direct backend single requests are closer to a few milliseconds. This is not a rigorous benchmark suite, but it is enough to validate the experiment: fragment payloads are small and the render path is fast enough to keep exploring.

## What this is not

It is not a React replacement.

It is not a complete framework.

It is not a claim that inline JavaScript strings are a good long-term packaging format.

It is a small working sketch of a different contract:

```text
server owns render/state/tools
browser executes layer swaps
AI calls typed-ish tools
traces explain what happened
```

That contract feels promising for internal tools, dashboards, admin surfaces, and AI-assisted workflows where correctness and inspectability matter more than frontend maximalism.

## Next

The next phase is to extract the reusable core:

- typed fragment targets;
- a cleaner asset pipeline;
- a real benchmark harness;
- a better component style guide;
- MCP-backed tools;
- a real domain module beyond demo clients.

For now, the prototype is small enough to understand and real enough to poke.
