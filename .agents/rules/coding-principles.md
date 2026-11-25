# Coding Standards & Engineering Invariants (Experimental)
> **Component Identifier:** `core-utilities/rule`  
> **Target Path in Target Repository:** `.agents/rules/coding-principles.md`  
> **Development Status:** 🟡 **UNDER IDEA VERIFICATION / EXPERIMENTAL** — Guidelines are subject to empirical testing in active projects.

---

<!-- SECTION:tdd-and-vertical-slices:START -->
## 1. Test-Driven Development & Vertical Slices
- **TDD Red ➔ Green Cycle:**
  1. Write a failing test asserting the expected behavior at a public boundary (Public Seam). Confirm it fails (Red).
  2. Implement the minimum logic required to pass the test (Green).
  3. Refactor cleanly without changing test behavior.
- **Vertical Slice Development:**
  - Build end-to-end functionality per user story (UI ➔ API ➔ Domain ➔ Database).
  - Avoid horizontal batching (e.g. creating 20 empty controllers before implementing logic).
<!-- SECTION:tdd-and-vertical-slices:END -->

---

<!-- SECTION:public-seams-and-adapters:START -->
## 2. Public Seams & Dependency Isolation
- Test behavior through public APIs and interfaces, never private internal implementation.
- Isolate external third-party services (payments, email, third-party AI) behind Interface Adapters to allow millisecond stubs during test runs.
<!-- SECTION:public-seams-and-adapters:END -->

---

<!-- SECTION:code-to-docs-rule:START -->
## 3. Mandatory Code-to-Docs Synchronization
- Whenever implementing a new feature in code, Agent MUST create or update a companion document inside `docs/` for human readers.
- If a feature is only an idea or partially designed:
  - Code must remain an empty stub or placeholder.
  - The document in `docs/` must explicitly state: *"Currently in idea stage, not fully implemented"*.
<!-- SECTION:code-to-docs-rule:END -->

---

<!-- SECTION:referential-integrity:START -->
## 4. Referential Integrity & Cascading Updates
- Whenever moving, renaming, or updating signatures of files, functions, or interfaces:
  - Scan the entire codebase with `Grep` for all references.
  - Update all incoming imports and Markdown links synchronously. Zero broken links permitted.
<!-- SECTION:referential-integrity:END -->
