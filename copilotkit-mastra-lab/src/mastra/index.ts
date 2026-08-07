import { Mastra } from "@mastra/core/mastra";
import { ConsoleLogger } from "@mastra/core/logger";
import { LibSQLStore } from "@mastra/libsql";
import { orderAgent } from "@/mastra/agents";

// Local Mastra runtime used by the Next.js CopilotKit route.

export const mastra = new Mastra({
  agents: {
    orderAgent,
  },
  storage: new LibSQLStore({
    id: "mastra-storage",
    url: "file:./mastra-storage.db",
  }),
  logger: new ConsoleLogger({
    level: "info",
  }),
});
