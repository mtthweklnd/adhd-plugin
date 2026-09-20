---
name: trace-workflow
description: >-
  Trace or flatten a delegation chain across multiple custom functions or files
  (A -> B -> C -> D) to prevent mental stack overflow. For nesting inside a single
  function, use simplify instead. Triggers on: "trace this workflow", "trace the
  call tree", "flatten this call chain", "too many function hops", "untangle
  nested functions", "map the workflow", "trace this function".
---

# Trace Workflow

## Purpose

Prevent mental stack overflow caused by deep function delegation (A -> B -> C -> D). Maps multi-tier call hierarchies onto a single visual plane and provides a structured approach for flattening nested delegation into linear orchestration.

## Operational Modes

### Mode 1: Trace (Single-Plane Visualization)

Use when understanding or debugging existing multi-step workflows across files or deep call trees:

1. **Call Hierarchy Tree:**
   Generate an ASCII or Mermaid call tree mapping only custom application functions (exclude standard library or framework primitives unless critical):
   ```text
   handleRequest()
   └── validatePayload()
       └── checkPermissions()
   └── processOrder()
       └── calculateTotals()
           └── applyDiscount()
       └── submitTransaction()
   ```

2. **Linear Transformation Timeline:**
   Detail what happens to the core data structure at each hop without requiring the reader to jump between function definitions:
   - `Step 1 (handleRequest)`: Receives raw JSON payload, parses into typed request object.
   - `Step 2 (validatePayload -> checkPermissions)`: Verifies user session and roles; aborts with error if unauthorized.
   - `Step 3 (processOrder -> calculateTotals)`: Computes subtotal, applies active discounts, computes tax.
   - `Step 4 (submitTransaction)`: Emits payment event, saves receipt to database, returns transaction ID.

3. **Side-Effect & State Mutation Audit:**
   Explicitly list any state mutations or I/O operations occurring down the stack:
   - Highlight which function performs database writes, disk I/O, or network requests.
   - Flag any mutations to shared outer-scope or module-level variables.

**Done when:** every custom function in the chain appears exactly once in the tree, and every hop has a Timeline entry.

### Mode 2: Flatten (Linear Orchestration Refactoring)

Use when refactoring deep delegation chains to reduce cognitive stack depth. Apply the AST Hygiene standard from `rules/AGENTS.md` (inline passthrough wrappers, flat sequential pipelines over internal delegation):

1. **Invert Delegation to Top-Level Orchestration:**
   Transform nested delegation (A calls B, which calls C, which calls D) into linear orchestration where coordinator A sequentially invokes independent units:
   - **Before (Nested Delegation):**
     ```typescript
     function handleOrder(order) {
       return processPayment(order); // processPayment calls notifyUser, which calls auditLog
     }
     ```
   - **After (Linear Orchestration):**
     ```typescript
     function handleOrder(order) {
       const validated = validateOrder(order);
       const paymentReceipt = executePayment(validated);
       notifyCustomer(paymentReceipt);
       recordAuditLog(paymentReceipt);
       return paymentReceipt;
     }
     ```

2. **Surface Implicit State:**
   Convert closure-captured or implicit outer variables into explicit function arguments and return types.

3. **Verify Contracts & Error Propagation:**
   Ensure error handling, return value shapes, and asynchronous control flows remain identical to the original behavior.

**Done when:** no non-recursive hop in the chain is more than 2 calls deep, and step 3's contract check passes.

## Rules

- Keep the visualization strictly on a single plane; the reader should never have to mentally hold multiple function contexts simultaneously.
- Always distinguish between pure data transformations and functions with side effects.
- In flattening refactors, preserve complete error handling and transactional integrity.
