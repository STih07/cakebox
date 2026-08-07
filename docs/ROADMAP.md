# Roadmap

## 1. Stabilize the Core

Turn the current prototype into a small reusable core:

- typed routes;
- typed render modes;
- full document rendering;
- page fragments;
- nested fragment targets;
- layer swap script;
- deployment recipe for nginx and systemd.

Candidate names:

- `Layered HTML`
- `PageFactory`
- `Typed Fragments`

## 2. Build One Real Internal Module

Use the core on a real task before polishing the public story.

Good candidates:

- trading idea monitor;
- portfolio status wall;
- event/activity dashboard;
- research note index;
- small admin panel for generated reports.

The goal is to force the fragment model through real data, filters, tables, status panels, and periodic updates.

## 3. Add Metrics

Measure whether this approach is actually light.

Track:

- full render latency;
- fragment render latency;
- bytes transferred;
- JS payload size;
- server CPU time;
- memory footprint;
- nginx and Warp request timing;
- browser swap time.

Compare against a small React/Next-style equivalent later.

## 4. Improve Frontend Components

The current browser layer is intentionally small.

Next frontend work:

- move CSS and JS out of Haskell strings;
- define a component style guide;
- add richer table/list components;
- integrate AG-UI events inside fragment slots.

Current AG-UI bridge:

- `PageFactory.AgUi.Events`
- `PageFactory.AgUi.Input`
- `PageFactory.AgUi.Server`
- `PageFactory.Ai.Model`
- `PageFactory.Ai.Agent`
- `PageFactory.Ai.AgUiAdapter`
- `GET /ag-ui/runs` for browser/EventSource demo compatibility
- `POST /ag-ui/runs` with minimal `RunAgentInput`
- `/clients/:id/ai`
- browser `EventSource` panel

Next backend work:

- provider interface under `PageFactory.Ai`;
- richer AG-UI event coverage;
- custom events for Layered HTML fragment refresh;
- MCP-backed tools;
- real AI provider.

## 5. AI-Assisted Factory

Only after the core and components are stable:

- let AI generate new typed routes;
- let AI generate view modules;
- let Haskell compile checks catch missing cases;
- keep fragment contracts explicit.

The point is not to generate arbitrary pages. The point is to generate inside typed rails.
