import {
  CopilotRuntime,
  createCopilotEndpoint,
  InMemoryAgentRunner,
} from "@copilotkit/runtime/v2";
import { createLocalAgents } from "@/agent";
import { handle } from "hono/vercel";

// CopilotKit runtime endpoint. It hosts local Mastra agents in this Next process.

const runtime = new CopilotRuntime({
  agents: createLocalAgents(),
  runner: new InMemoryAgentRunner(),
});

const app = createCopilotEndpoint({
  runtime,
  basePath: "/api/copilotkit",
});

export const GET = handle(app);
export const POST = handle(app);
export const PATCH = handle(app);
export const DELETE = handle(app);
