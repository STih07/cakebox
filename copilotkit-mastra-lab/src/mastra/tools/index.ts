import { createTool } from "@mastra/core/tools";
import { z } from "zod";

// Server-side Mastra tools. Frontend tools live in the React page.

export const orderPolicyTool = createTool({
  id: "order-policy",
  description:
    "Return fulfillment policy hints for a demo order checkout or refund flow.",
  inputSchema: z.object({
    country: z.string().describe("Destination country"),
    total: z.number().describe("Order total in USD"),
  }),
  outputSchema: z.object({
    shipping: z.string(),
    refundWindow: z.string(),
    requiresReview: z.boolean(),
  }),
  execute: async ({ country, total }) => ({
    shipping:
      country.toLowerCase().includes("germany") || country.toLowerCase().includes("de")
        ? "EU express, 2-4 business days"
        : "Standard international, 5-9 business days",
    refundWindow: total > 500 ? "14 days, manual review" : "30 days, instant approval",
    requiresReview: total > 500,
  }),
});
