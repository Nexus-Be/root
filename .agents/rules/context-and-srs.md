# Workspace Harness Component: Business Context & Standardized SRS Slotting
> **Component Identifier:** `core-utilities/context`  
> **Target Path in Target Repository:** `.agents/contexts/business-context.md` (or `.agents/specs/spec.md`)

---

<!-- SECTION:srs-header-format:START -->
## 1. Standardized 7-Header Business & SRS Format
Whenever capturing business context or software requirements, Agent MUST format and organize information under these 7 canonical headers:

### Header 1: Problem Statement & User Personas
- **Target Audience / Actors:** Who interacts with the system? (Roles, permissions, hierarchy).
- **Core Pain Point:** What operational bottleneck or human friction does this feature eliminate?

### Header 2: Business Scope & Non-Goals
- **In-Scope:** Exact functional boundaries included in the current iteration.
- **Non-Goals (MANDATORY):** Explicit list of items the system will STRICTLY NOT do in this version to eliminate scope creep.

### Header 3: Core Business Flows & Scenarios
- **Step-by-Step Sequences:** User actions and system reactions.
- **Given-When-Then Scenarios:** BDD-style behavioral contracts for every user story.
- **Visual Flowcharts:** Mermaid.js sequence or swimlane diagrams illustrating actor boundaries.

### Header 4: Domain Data Model & Entity Dictionary
- **Business Entities:** Core nouns (e.g., Tenant, Employee, ApprovalRequest).
- **Field-level Attributes:** Required properties, data types, and primary key relationships.

### Header 5: Business Rules & Invariants
- **Validation Constraints:** Business equations, date checks, mathematical formulas, and authorization policies.
- **System Invariants:** Conditions that must hold true before and after any state transition.

### Header 6: Edge Cases & Exception Handling
- **Network & Infrastructure Failures:** Timeouts, concurrency clashes, duplicate submissions.
- **Graceful Degradation:** Error payloads, user-facing error messages, and rollback semantics.

### Header 7: Open Questions & Pending Doubts
- **Unsettled Decisions:** Items where human clarification is required.
- **Ambiguities:** Definitions needing user confirmation before implementation.
<!-- SECTION:srs-header-format:END -->

---

<!-- SECTION:automated-slotting-engine:START -->
## 2. Automated Header Slotting Engine
When the user speaks conversationally about a feature or business logic, Agent MUST NOT dump unstructured text. Agent MUST parse and slot the input into the matching header:

| User Conversation Signal | Target Header Destination |
| :--- | :--- |
| Mentions roles, permissions, user types, or who does what | **Header 1: Problem Statement & User Personas** |
| Mentions out-of-scope items, things not to do, or version boundaries | **Header 2: Business Scope & Non-Goals** |
| Mentions step-by-step clicks, user journeys, or workflow steps | **Header 3: Core Business Flows & Scenarios** |
| Mentions fields, database columns, entities, or data shapes | **Header 4: Domain Data Model & Entity Dictionary** |
| Mentions constraints ("must be > 18", "needs manager approval") | **Header 5: Business Rules & Invariants** |
| Mentions errors, network loss, edge cases, or exception behavior | **Header 6: Edge Cases & Exception Handling** |
| Mentions unresolved options, questions, or undecided logic | **Header 7: Open Questions & Pending Doubts** |
<!-- SECTION:automated-slotting-engine:END -->

---

<!-- SECTION:ubiquitous-language-sync:START -->
## 3. Ubiquitous Language & Glossary Synchronization
1. When encountering an ambiguous, overloaded, or undefined business term:
   - Agent MUST HALT immediately and prompt the user for a two-way definition.
2. Once clarified:
   - The term and its exact definition are committed directly to `.agents/rules/GLOSSARY.md`.
   - All code entities, DTOs, and UI labels must map verbatim to this glossary.
<!-- SECTION:ubiquitous-language-sync:END -->
