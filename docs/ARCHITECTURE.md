# Architecture

This project explores **Layered HTML**: the server renders typed HTML fragments, and the browser replaces only the layer that a navigation action targets.

## Core Idea

The page is not treated as one replaceable document. It is a stack of stable layers:

```text
app shell
  page layer
    local page layer
      panel layer
```

A direct browser request receives the full document:

```text
<!doctype html>
html
  head
  body
    app-container
      topbar
      page content
```

A container request receives only the requested fragment:

```text
main[data-render-part="client-profile"]
```

A deeper request can target an inner slot:

```text
div[data-fragment-slot="client-panel"]
```

## Responsibilities

The browser keeps the currently loaded shell alive. It intercepts local links, sends a fragment request, and replaces the selected layer.

The server decides what is legal to render. Routes, tabs, and fragment targets are represented by Haskell types where possible.

The current demo uses a small inline JavaScript navigator, but the rendering contract is server-first. The JS layer is transport and swap behavior, not the owner of the domain model.

## Module Map

```text
src/
  Main.hs
  PageFactory/
    App/
      Routes.hs
      Server.hs
    Clients/
      Model.hs
      Store.hs
      Tabs.hs
      Views.hs
    Engine/
      Assets.hs
      Html.hs
      Http.hs
      Layout.hs
    Clients.hs
    Engine.hs
```

`PageFactory.Engine` is the rendering foundation:

- `Html.hs` contains the tiny HTML DSL.
- `Http.hs` detects full vs fragment requests.
- `Layout.hs` builds the full document and app shell.
- `Assets.hs` contains inline CSS and the fragment navigation script.

`PageFactory.Clients` is the first domain module:

- `Model.hs` defines client and tab types.
- `Store.hs` loads client data from CSV.
- `Tabs.hs` maps typed tabs to URL slugs.
- `Views.hs` renders index, profile, tabs, and panel fragments.

`PageFactory.App` wires the domain and engine to HTTP.

## Why Haskell

The useful part is not just server rendering. The useful part is naming the pieces:

```haskell
data ClientTab = OverviewTab | InvoicesTab | ActivityTab
```

Once a tab is a type instead of an arbitrary string, the compiler can help keep routes, URLs, labels, and rendered panels aligned.

This is the shape we want:

```text
typed route
  -> typed domain state
  -> typed render choice
  -> HTML layer
```

## Current Limitations

- CSS and JS are inline strings.
- The client data store is CSV.
- Fragment targets are still stringly typed at the HTTP boundary.
- There is no benchmark suite yet.
- The HTML DSL is intentionally tiny and not a public API yet.

These are acceptable for the prototype. The next phase is extracting a reusable core.

