# CopilotKit + Mastra Lab

Standalone lab next to the Haskell Page Factory.

What it demonstrates:

- CopilotKit runtime v2 in a Next.js API route.
- A local Mastra agent exposed to CopilotKit through AG-UI.
- Mastra memory with thread-scoped working memory.
- Frontend tools that let the agent change page theme and update an order form.

Run:

```bash
nvm use 22
cp .env.example .env
npm install
npm run dev
```

The app listens on `http://127.0.0.1:3100`.
