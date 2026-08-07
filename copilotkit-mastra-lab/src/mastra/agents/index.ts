import { createOpenAI } from "@ai-sdk/openai";
import { Agent } from "@mastra/core/agent";
import { LibSQLStore } from "@mastra/libsql";
import { Memory } from "@mastra/memory";
import { z } from "zod";
import { orderPolicyTool } from "@/mastra/tools";

// Mastra agent with thread-scoped working memory.

const modelProvider = createOpenAI({
  apiKey: process.env.OPENAI_API_KEY || process.env.OPENROUTER_API_KEY,
  baseURL: process.env.OPENAI_API_KEY ? undefined : "https://openrouter.ai/api/v1",
  headers: process.env.OPENROUTER_API_KEY
    ? {
        "HTTP-Referer": process.env.OPENROUTER_SITE_URL || "http://127.0.0.1:3100",
        "X-Title": process.env.OPENROUTER_APP_NAME || "CopilotKit Mastra Lab",
      }
    : undefined,
});

export const AgentState = z.object({
  notes: z.array(z.string()).default([]),
  preferredTheme: z.string().default("#315a63"),
  lastOrderId: z.string().optional(),
});

export const orderAgent = new Agent({
  id: "order-agent",
  name: "Order Canvas Agent",
  model: modelProvider(
    process.env.OPENAI_MODEL ||
      process.env.OPENROUTER_MODEL ||
      (process.env.OPENAI_API_KEY ? "gpt-4o-mini" : "openai/gpt-4o-mini"),
  ),
  tools: { orderPolicyTool },
  instructions: [
    "You are an in-app order assistant for a CopilotKit + Mastra lab.",
    "Answer in Russian unless the user asks otherwise.",
    "You can use backend policy tools and frontend tools.",
    "When the user asks to change the UI theme, call the frontend tool setThemeColor.",
    "When the user asks to fill or update the order form, call the frontend tool updateOrderDraft.",
    "Remember useful user preferences in working memory notes when relevant.",
  ].join(" "),
  memory: new Memory({
    storage: new LibSQLStore({
      id: "order-agent-memory",
      url: "file:./mastra-memory.db",
    }),
    options: {
      workingMemory: {
        enabled: true,
        schema: AgentState,
        scope: "thread",
      },
    },
  }),
});
