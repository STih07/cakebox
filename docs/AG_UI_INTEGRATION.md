# AG-UI Integration

AG-UI should not replace Layered HTML. It should become the event channel inside a selected layer.

Layered HTML answers:

```text
What HTML layer should exist here?
```

AG-UI answers:

```text
What agent events are happening inside this layer right now?
```

## Source Notes

The official AG-UI docs describe it as an open, lightweight, event-based protocol for connecting AI agents to user-facing applications. The core architecture is client-server and event-driven, with standard HTTP support for endpoints that accept `RunAgentInput` and stream `BaseEvent` values over SSE.

Important event families:

- lifecycle: run started, run finished, run error;
- text messages: start, content, end;
- tool calls;
- state snapshots and deltas;
- activity events;
- custom events.

## First Bridge

This project exposes:

```text
/ag-ui/runs
```

Current behavior:

```bash
curl -N http://127.0.0.1:8098/ag-ui/runs
```

The endpoint also accepts a minimal `RunAgentInput` over POST:

```bash
curl -N -X POST http://127.0.0.1:8098/ag-ui/runs \
  -H 'Content-Type: application/json' \
  --data '{"threadId":"thread_test","runId":"run_test","messages":[{"role":"user","content":"hello layered html"}]}'
```

Bad JSON returns `400 Bad Request`; unsupported methods return `405 Method Not Allowed`.

The endpoint streams a demo run through the AI backend layer:

```text
AgentEvent
  -> toAgUiEvent
  -> SSE
```

The resulting stream contains AG-UI-style events:

```text
RUN_STARTED
TEXT_MESSAGE_START
TEXT_MESSAGE_CONTENT
TEXT_MESSAGE_END
RUN_FINISHED
```

This is intentionally small. It proves transport, JSON decoding, event shape, and the internal/external event boundary before we connect a real provider.

## Browser Panel

The client page has an `AI` tab:

```text
/clients/:id/ai
```

That tab renders:

```html
<div data-agent-panel="client-assistant" data-agent-stream-url="/ag-ui/runs">
```

The browser script finds `[data-agent-panel]`, opens an `EventSource`, parses streamed AG-UI events, and appends them to the panel log.

This keeps the layering rule intact:

```text
client-profile <main>  stays alive
tabs                   stay alive
client-panel           swaps to AI
agent log              fills from AG-UI events
```

## Desired Layer Shape

Eventually a page can host an agent slot:

```text
app-container
  page layer
    client-panel
      ag-ui-thread
```

The browser receives AG-UI events and updates only the local agent component. It should not own the page route, client model, or fragment contract.

## Haskell Boundary

Useful types to grow next:

```haskell
data AgUiEvent
  = RunStarted ...
  | TextMessageStart ...
  | TextMessageContent ...
  | TextMessageEnd ...
  | RunFinished ...
```

The internal AI module already has a separate event type:

```haskell
data AgentEvent
  = AgentRunStarted ThreadId RunId
  | AgentTextStarted MessageId
  | AgentTextDelta MessageId String
  | AgentTextFinished MessageId
  | AgentRunFinished ThreadId RunId
```

AG-UI remains an adapter:

```haskell
toAgUiEvent :: AgentEvent -> AgUiEvent
```

Later:

```haskell
data AgUiTarget
  = ClientAssistant ClientId
  | TradingIdeaAssistant IdeaId
  | ReportAssistant ReportId
```

The goal is to keep agent interaction typed at the app boundary.

## Next Steps

Done:

- JSON encoding uses Aeson.
- `POST /ag-ui/runs` accepts a minimal `RunAgentInput`.
- The demo AI backend receives `threadId`, optional `runId`, and messages before adapting internal events to AG-UI events.

Next:

1. Add a provider interface under `PageFactory.Ai`.
2. Add custom events that can request a Layered HTML fragment refresh.
3. Connect MCP-backed tools.
4. Connect a real AI provider.
