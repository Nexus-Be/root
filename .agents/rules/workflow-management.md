# Component: High-Rigor Engineering Workflows & Playbooks
> **Companion File (Vietnamese):** [`default.vi.md`](default.vi.md)  
> **Authoritative English Baseline Specification**

<!-- SECTION:feature-playbook:START -->
## 1. Feature Playbook (Data Shape First & Vertical Slices)
- **Step 1: Model the Domain First:** Before writing any implementation logic, explicitly define core data structures, state machines, and interface contracts. Prohibit scattering shape assumptions across conditionals.
- **Step 2: Failing Test First (TDD Red):** Author an automated test or verification script that asserts the desired new behavior and observe it fail for the right reason.
- **Step 3: Vertical Slice Implementation (TDD Green):** Author the minimal cohesive implementation across the vertical stack to pass the test. Commit surgical changes.
- **Step 4: Proof Verification:** Execute the test suite and confirm 100% passing results with verbatim command output.
<!-- SECTION:feature-playbook:END -->

---

<!-- SECTION:bug-fix-playbook:START -->
## 2. Bug-Fix Playbook (Repro First & Root-Cause Elimination)
- **Step 1: Reproduce Before Fixing:** Never write a fix without first proving the defect with a reproducible failing test, script, or concrete command output.
- **Step 2: Trace Root Causes:** Trace the defect to the exact origin where system invariants were violated. Prohibit superficial nil checks or cosmetic band-aids unless the edge state is formally legitimate.
- **Step 3: Surgical Fix & Zero Regression:** Implement the minimal fix directly at the root cause. Verify that the reproduction test now passes and the full regression suite remains green.
<!-- SECTION:bug-fix-playbook:END -->

---

<!-- SECTION:refactoring-playbook:START -->
## 3. Refactoring Playbook (Behavior-Preserving & Zero Broken Links)
- **Step 1: Invariant Locking:** Ensure comprehensive test coverage exists before altering existing structures.
- **Step 2: Atomic Decomposition:** Break refactoring into small, discrete steps (Rename ➔ Extract ➔ Migrate Callers ➔ Delete Legacy).
- **Step 3: Cascading References Audit:** Grep 100% of the codebase to update all callers, imports, and documentation, leaving zero broken references.
<!-- SECTION:refactoring-playbook:END -->

---

<!-- SECTION:core-principles:START -->
## 4. Non-Negotiable Engineering Principles
- **Prove It Works:** Verify against real artifacts and live command outputs; conversational assertions or "it compiles" do not satisfy acceptance.
- **Subtract Before You Add:** Eliminate dead code, unused parameters, and obsolete abstractions before building additions.
- **Make Operations Idempotent:** Ensure all commands, lifecycle steps, and initialization scripts converge to the correct state regardless of prior partial runs.
- **Guard the Context Window:** Pass compact file pointers and summaries to parent orchestrators; route large logs to temporary disk files.
<!-- SECTION:core-principles:END -->
