export type AgentState = {
  notes: string[];
  preferredTheme: string;
  lastOrderId?: string;
};

export type OrderDraft = {
  orderId: string;
  customer: string;
  country: string;
  total: number;
  shippingMethod: string;
  status: string;
};
