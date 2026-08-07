import { MastraAgent } from "@ag-ui/mastra";
import type { AbstractAgent } from "@ag-ui/client";
import { mastra } from "@/mastra";

// Expose local Mastra agents to CopilotKit runtime through AG-UI.

export function createLocalAgents(): Record<string, AbstractAgent> {
  return MastraAgent.getLocalAgents({
    mastra,
    resourceId: "demo-user",
  }) as unknown as Record<string, AbstractAgent>;
}
