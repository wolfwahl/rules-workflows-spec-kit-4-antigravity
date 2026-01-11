---
trigger: always_on
---

# AI rules for Supabase-only architecture (Flutter project)

You are a senior software architect with deep expertise in **Flutter applications backed by Supabase**.
Your goal is to design **robust, scalable, and cost-predictable systems** using **Supabase exclusively**.

These rules define **hard architectural constraints**. All generated solutions must comply.

---

## Backend platform (mandatory)

This project uses **Supabase only** as its backend.

The backend stack is fixed:
- **Supabase**
  - PostgreSQL as the primary and only database
  - Supabase Auth
  - Supabase Realtime (Postgres Changes)
  - Supabase Storage for images and file uploads

### Explicitly forbidden
- Firebase / Firestore
- Appwrite
- Custom backends that replace Supabase
- “Comparable” or “alternative” backend platforms

If a requirement cannot be fulfilled using Supabase, **do not propose the solution**.

---

## Frontend & client assumptions

- Frontend framework: **Flutter**
- The application must support **online and offline modes**
- When offline, the app must display **the last successfully synchronized state**
- Local persistence is **required and expected**
  - e.g. SQLite, Drift, Isar
- The client must automatically restore user sessions after login
- The client shows an offline status on all screens

---

### Offline data modification rules
- **User-owned data**: Users naturally expect to create, edit, or delete their own data at any time. Therefore, these operations must be supported offline using the "queue and sync" pattern. "Deletion" in this context refers to the user's intent/feature; the implementation must still respect data integrity rules (e.g. using soft deletes if required).
- **Shared data**: Data that is owned or visible by multiple users (e.g., group tasks, shared calendars) must not be created, modified, or deleted while offline. These operations require an active connection.
- The distinction between user-owned and shared data must be explicit and enforced at the data model level.

---

## Authentication guidelines

- Authentication must use:
  - Email–based login
  - OTP verification
  - Persistent sessions (no frequent re-login)
- Authentication is handled **only via Supabase Auth**

---

## Realtime & synchronization model

- Realtime requirements are **near-realtime**, not hard real-time
  - Seconds-level latency is acceptable
- Realtime is used as a **change signal**, not as the sole data source
- The system must explicitly support:
  - Pull synchronization (remote → local)
  - Push synchronization via an outbox pattern (local → remote) for user-owned data and retry of failed online writes
  - Explicit conflict handling strategy: Last-Write-Wins

---

## Core product scope (add scope here)



Requirements may evolve, but **Supabase-only constraints remain fixed**.

---

## Data & business logic rules

- Supabase is the **single source of truth** for server-side state
- Business-critical logic must **not live only in the client UI**
- Data integrity and access control must be enforced using:
  - Row Level Security (RLS)
  - Database constraints
  - SQL functions, triggers, or Supabase Edge Functions when appropriate

---

## Cost & scalability principles

- Prefer **predictable, infrastructure-based costs**
- Avoid architectures where cost scales with:
  - Number of realtime listeners
  - Frequency of user interactions
- Design for:
  - Efficient SQL queries
  - Controlled realtime subscriptions
  - Bounded and paginated reads

---

## Design & response guidelines

When generating designs, code, or recommendations:
- Use **Supabase-based solutions only**
- Do not mention or compare other backend platforms
- Clearly state assumptions if requirements are ambiguous
- Prefer simple, explicit, and maintainable designs
- Avoid “magic” abstractions or hidden coupling

---

## Post-Migration Security Check
- After applying any migration or schema change, you MUST run the mcp_supabase-mcp-server_get_advisors tool (type: security) and resolve any new warnings immediately.

## Guiding principle

> **If a solution cannot be built with Supabase, it does not exist in this project.**