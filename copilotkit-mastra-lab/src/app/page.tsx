"use client";

import {
  CopilotChatConfigurationProvider,
  CopilotSidebar,
  useAgent,
  useConfigureSuggestions,
  useFrontendTool,
} from "@copilotkit/react-core/v2";
import { useMemo, useState } from "react";
import { z } from "zod";
import type { AgentState, OrderDraft } from "@/lib/types";
import styles from "./page.module.css";

const initialOrder: OrderDraft = {
  orderId: "PF-7130",
  customer: "Alice Carter",
  country: "Germany",
  total: 286,
  shippingMethod: "EU express",
  status: "Draft",
};

export default function Page() {
  return (
    <CopilotChatConfigurationProvider agentId="orderAgent">
      <OrderWorkspace />
    </CopilotChatConfigurationProvider>
  );
}

function OrderWorkspace() {
  const [themeColor, setThemeColor] = useState("#315a63");
  const [order, setOrder] = useState<OrderDraft>(initialOrder);
  const [actionNotes, setActionNotes] = useState<string[]>([]);

  const { agent } = useAgent({ agentId: "orderAgent" });
  const state = ((agent.state as AgentState | undefined) ?? {
    notes: [],
    preferredTheme: themeColor,
  }) as AgentState;

  useFrontendTool({
    name: "setThemeColor",
    description: "Change the page theme accent color.",
    parameters: z.object({
      themeColor: z.string().describe("CSS color, preferably hex."),
    }),
    handler: async ({ themeColor }) => {
      setThemeColor(themeColor);
      setActionNotes((notes) => [`Theme changed to ${themeColor}`, ...notes].slice(0, 6));
      agent.setState({
        ...state,
        preferredTheme: themeColor,
        notes: [...(state.notes ?? []), `Theme changed to ${themeColor}`],
      });
      return `Theme changed to ${themeColor}`;
    },
  });

  useFrontendTool({
    name: "updateOrderDraft",
    description: "Update fields in the visible order form.",
    parameters: z.object({
      orderId: z.string().optional(),
      customer: z.string().optional(),
      country: z.string().optional(),
      total: z.number().optional(),
      shippingMethod: z.string().optional(),
      status: z.string().optional(),
      note: z.string().optional(),
    }),
    handler: async (patch) => {
      setOrder((current) => ({
        ...current,
        ...Object.fromEntries(
          Object.entries(patch).filter(
            ([key, value]) => key !== "note" && value !== undefined && value !== null,
          ),
        ),
      }));
      setActionNotes((notes) =>
        [
          patch.note || `Order draft updated${patch.customer ? ` for ${patch.customer}` : ""}`,
          ...notes,
        ].slice(0, 6),
      );
      agent.setState({
        ...state,
        lastOrderId: patch.orderId ?? order.orderId,
        notes: patch.note ? [...(state.notes ?? []), patch.note] : state.notes ?? [],
      });
      return "Order draft updated";
    },
  });

  useConfigureSuggestions({
    available: "always",
    suggestions: [
      {
        title: "Смени тему",
        message: "Сделай тему спокойной зеленой.",
      },
      {
        title: "Заполни заказ",
        message: "Заполни заказ для Maria Ivanova из Germany на сумму 640, статус Needs review.",
      },
      {
        title: "Проверь правила",
        message: "Проверь fulfillment policy для Germany и total 640.",
      },
      {
        title: "Память",
        message: "Запомни, что я предпочитаю EU express для немецких заказов.",
      },
    ],
  });

  const pageStyle = useMemo(
    () =>
      ({
        "--accent": themeColor,
        "--accent-soft": `${themeColor}22`,
      }) as React.CSSProperties,
    [themeColor],
  );

  return (
    <main className={styles.page} style={pageStyle}>
      <div className={styles.workspace}>
        <header className={styles.topbar}>
          <div className={styles.brand}>
            <strong>CopilotKit + Mastra Lab</strong>
            <span>Frontend tools, Mastra memory, AG-UI runtime</span>
          </div>
          <span className={styles.status}>{order.status}</span>
        </header>

        <section className={styles.panel}>
          <h1>Order Control Surface</h1>
          <p>
            Агент может менять цвет интерфейса, обновлять форму заказа,
            пользоваться backend tool Mastra и помнить thread-scoped заметки.
          </p>
        </section>

        <section className={styles.mainGrid}>
          <OrderCard order={order} setOrder={setOrder} />
          <StatePanel state={state} themeColor={themeColor} actionNotes={actionNotes} />
        </section>
      </div>

      <CopilotSidebar
        defaultOpen
        labels={{
          modalHeaderTitle: "Order Agent",
          welcomeMessageText:
            "Спроси меня поменять цвет страницы, заполнить заказ или проверить policy.",
        }}
      />
    </main>
  );
}

function OrderCard({
  order,
  setOrder,
}: {
  order: OrderDraft;
  setOrder: (next: OrderDraft) => void;
}) {
  const update = (field: keyof OrderDraft, value: string) => {
    setOrder({
      ...order,
      [field]: field === "total" ? Number(value || 0) : value,
    });
  };

  return (
    <article className={styles.orderCard}>
      <h2 className={styles.sectionTitle}>Order draft</h2>
      <div className={styles.fields}>
        <Field label="Order ID" value={order.orderId} onChange={(value) => update("orderId", value)} />
        <Field label="Customer" value={order.customer} onChange={(value) => update("customer", value)} />
        <Field label="Country" value={order.country} onChange={(value) => update("country", value)} />
        <Field label="Total" value={String(order.total)} onChange={(value) => update("total", value)} />
        <Field
          label="Shipping"
          value={order.shippingMethod}
          onChange={(value) => update("shippingMethod", value)}
        />
        <Field label="Status" value={order.status} onChange={(value) => update("status", value)} />
      </div>
      <div className={styles.actions}>
        <button className={styles.button} onClick={() => update("status", "Approved")}>
          Approve
        </button>
        <button className={`${styles.button} ${styles.secondary}`} onClick={() => update("status", "Needs review")}>
          Review
        </button>
      </div>
    </article>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className={styles.field}>
      <label>{label}</label>
      <input value={value} onChange={(event) => onChange(event.target.value)} />
    </div>
  );
}

function StatePanel({
  state,
  themeColor,
  actionNotes,
}: {
  state: AgentState;
  themeColor: string;
  actionNotes: string[];
}) {
  const notes = [...actionNotes, ...(state.notes ?? [])];

  return (
    <aside className={styles.statePanel}>
      <h2 className={styles.sectionTitle}>Agent memory</h2>
      <p className={styles.muted}>Theme: {state.preferredTheme || themeColor}</p>
      <p className={styles.muted}>Last order: {state.lastOrderId || "none"}</p>
      <ul className={styles.notes}>
        {(notes.length ? notes : ["No memory notes yet"]).map((note, index) => (
          <li key={`${note}-${index}`}>{note}</li>
        ))}
      </ul>
    </aside>
  );
}
