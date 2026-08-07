# Fragment Contract

Layered HTML works because client and server agree on a small contract.

## Request Modes

### Full Document

A normal request has no special headers:

```bash
curl http://127.0.0.1:8098/clients/2
```

The server returns a complete HTML document.

### Page Fragment

A container request asks for the main page layer:

```bash
curl \
  -H 'X-Render-Mode: fragment' \
  -H 'X-Requested-With: container' \
  http://127.0.0.1:8098/clients/2
```

The server returns:

```html
<main data-render-part="client-profile">...</main>
```

### Nested Fragment

A deeper layer can be addressed with `X-Render-Target`:

```bash
curl \
  -H 'X-Render-Mode: fragment' \
  -H 'X-Render-Target: client-panel' \
  http://127.0.0.1:8098/clients/2/invoices
```

The server returns:

```html
<div data-fragment-slot="client-panel">...</div>
```

## Selectors

Page-level fragments use:

```html
data-render-part
```

Nested fragments use:

```html
data-fragment-slot
```

Links can request a nested target:

```html
<a href="/clients/2/invoices" data-fragment-target="client-panel">
  Счета
</a>
```

## Browser Swap Rules

When `data-fragment-target` is absent, the browser replaces:

```text
[data-render-part]
```

When `data-fragment-target="client-panel"` is present, the browser replaces:

```text
[data-fragment-slot="client-panel"]
```

The browser also:

- updates `history.pushState`;
- updates active tab classes for targeted links;
- keeps parent layers alive;
- applies the fade/blur transition around the replaced layer.

## Server Guarantees

For a successful fragment request, the returned HTML must contain exactly one matching replacement element.

For example, if the request asks for:

```http
X-Render-Target: client-panel
```

then the response must contain:

```html
data-fragment-slot="client-panel"
```

If the browser cannot find a matching element in the response or in the current DOM, it falls back to a normal page navigation.

## Typed Routes

The client tabs are represented as Haskell values:

```haskell
data ClientTab = OverviewTab | InvoicesTab | ActivityTab
```

The URL layer maps to and from that type:

```haskell
clientTabPath :: Client -> ClientTab -> String
clientTabFromSlug :: String -> Maybe ClientTab
```

This keeps URL generation, route parsing, and rendering aligned.

