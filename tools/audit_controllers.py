#!/usr/bin/env python3
"""Static audit of every REST controller in the Nexus microservices.

Emits per-controller markdown checklists under src/Services/fix/<Service>/
and prints a one-line tally. Each unchecked box is a real, statically detected
violation of specs/06_ARCHITECTURAL_INVARIANTS_AND_CONTRACT_SPECIFICATION.md.

Re-runnable. No network, no build required.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICES_DIR = ROOT / "src" / "Services"
FIX_DIR = SERVICES_DIR / "fix"
GATEWAY_CONFIG = SERVICES_DIR / "Gateway" / "Gateway" / "appsettings.json"

SERVICES = [
    "User",
    "Catalog",
    "Commerce",
    "Log",
    "Auction",
    "Fulfillment",
    "Notification",
    "Wallet",
    "CheckHeal",
]

ALLOWED_SINGULAR = {
    "me",
    "auth",
    "admin",
    "internal",
    "health",
    "healthcheck",
}
ALLOWED_FILTER_SEGMENTS = {
    "me",
    "self",
    "mine",
    "current",
    "active",
    "buyer",
    "seller",
    "user",
    "owner",
    "tracking",
    "order",
    "status",
    "history",
    "search",
    "batch",
    "bulk-toggle",
    "toggle",
    "check",
    "event-types",
    "devices",
    "preferences",
    "transactions",
    "transfers",
    "withdrawals",
    "topups",
    "adjustments",
    "registration",
    "profile",
    "roles",
    "sessions",
    "init",
    "initialize",
    "checkout",
    "direct",
    "ipn",
    "return",
    "read",
    "otp",
    "verify",
    "resend",
    "login",
    "logout",
    "logout-all",
    "refresh",
    "register",
    "password",
    "forgot",
    "reset",
    "files",
    "upload",
    "reputation",
    "penalties",
    "reports",
    "reviews",
    "documents",
    "approve",
    "reject",
    "ban",
    "unban",
    "incidents",
    "audit-logs",
    "configs",
    "permissions",
    "send",
    "vnpay",
    "broker",
    "seller-registrations",
    "applications",
}
OWNERSHIP_TOKENS = (
    "GetUserId",
    "TryGetUserId",
    "HasRole",
    "GetUserRole",
    "EnsureOwnership",
    "EnsureSelfOrAdmin",
    "EnsureAdmin",
    "IsAdmin",
    "IsStaff",
)
MUTATING_VERBS = {"POST", "PUT", "PATCH", "DELETE"}

# Reference collections that are bounded by nature (enum-like lookup tables, small
# navigation trees). Paginating them would add an envelope nobody needs.
BOUNDED_REFERENCE_ACTIONS = {
    "Catalog:CategoriesController:ListAll",
    "Fulfillment:WarehousesController:ListActive",
    "Log:LogController:ListLogEventTypes",
    "User:AdminUsersController:ListRoles",
    "User:AdminRolesController:ListRoles",
}

# Controllers whose mutating actions are authorized by a service-level API key
# middleware instead of JWT roles.
API_KEY_PROTECTED_CONTROLLERS = {
    "CheckHeal:HealthCheckController",
}

# WalletService is the single documented CQRS exception: its controllers dispatch
# through MediatR `ISender` instead of injecting a feature service. See root
# AGENTS.md rule 8 and specs/06 section 3 rule 4.
CQRS_DISPATCHER_CONTROLLERS = {
    "Wallet:WalletsController",
    "Wallet:AdminWalletsController",
    "Wallet:InternalWalletsController",
}
ANONYMOUS_ACTION_HINTS = (
    "register",
    "verify",
    "resend",
    "login",
    "refresh",
    "password/forgot",
    "password/reset",
    "vnpay/ipn",
    "vnpay/return",
    "logout",
)

HTTP_VERB_RE = re.compile(r"^\s*\[Http(Get|Post|Put|Patch|Delete)\s*(?:\(\s*(?:\"([^\"]*)\")?\s*\))?\s*\]")
ROUTE_ATTR_RE = re.compile(r"^\s*\[Route\(\s*\"([^\"]*)\"\s*\)\s*\]")
REQUIRE_ROLE_RE = re.compile(r"^\s*\[RequireRole\s*(?:\(([^)]*)\))?\s*\]")
SUMMARY_RE = re.compile(r"^\s*///\s*<summary>(.*)</summary>\s*$")
PAGE_SIZE_CLAMP_RE = re.compile(
    r"pageSize\s*>\s*\d+|Math\.Clamp\(\s*pageSize|Normalize\([^)]*\b(?:pageSize|limit)\b",
    re.I,
)
LIMIT_CLAMP_RE = re.compile(r"limit\s*>\s*\d+|Math\.Clamp\(\s*limit|Normalize\([^)]*\blimit\b", re.I)
ENUM_LOWERCASE_RE = re.compile(r"ToString\(\)\s*\.\s*ToLower")
CLASS_RE = re.compile(r"^\s*public\s+(?:sealed\s+)?class\s+(\w+)\s*:\s*(.+)$")
SIGNATURE_RE = re.compile(r"^\s*public\s+(?:async\s+)?(?:Task<)?([\w<>,\[\]\?\. ]+?)(?:>)?\s+(\w+)\s*\(")
SERVICE_CTOR_RE = re.compile(
    r"public\s+\w+Controller\s*\(([^)]*)\)", re.S
)


@dataclass
class Check:
    label: str
    ok: bool
    note: str = ""


@dataclass
class ActionInfo:
    verb: str
    template: str
    name: str
    return_type: str
    signature: str
    body: str
    has_summary: bool
    summary_text: str
    require_roles: list[str]
    has_require_role: bool
    http_attr_count: int
    checks: list[Check] = field(default_factory=list)

    @property
    def full_route(self) -> str:
        return self.template


@dataclass
class ControllerInfo:
    service: str
    path: Path
    layer: str
    ns: str
    class_name: str
    base_route: str
    class_roles: list[str]
    class_has_require_role: bool
    ctor_params: str
    body: str
    actions: list[ActionInfo]
    checks: list[Check] = field(default_factory=list)


def load_gateway_paths() -> list[str]:
    try:
        cfg = json.loads(GATEWAY_CONFIG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    routes = cfg.get("ReverseProxy", {}).get("Routes", {})
    paths = []
    for route in routes.values():
        path = route.get("Match", {}).get("Path")
        if isinstance(path, str):
            paths.append(path)
    return paths


def gateway_covers(paths: list[str], base_route: str) -> bool:
    target = "/" + base_route.strip("/").lower()
    target = target.split("/{")[0].rstrip("/")
    for path in paths:
        candidate = path.lower().rstrip("/")
        head = candidate.split("/{**")[0].rstrip("/")
        if head == target:
            return True
        if head.count("/") < target.count("/") and target.startswith(head + "/"):
            return True
    return False


def resolve_controller_token(base_route: str, class_name: str) -> str:
    """Expand the ASP.NET `[controller]` token so coverage can be matched against real paths."""
    if "[controller]" not in base_route.lower():
        return base_route
    token = class_name[:-len("Controller")] if class_name.lower().endswith("controller") else class_name
    return re.sub(r"\[controller\]", token, base_route, flags=re.I)


def effective_routes(info: ControllerInfo) -> set[str]:
    """Full route of every action, joining the class route unless the action overrides it."""
    routes: set[str] = set()
    for action in info.actions:
        template = (action.template or "").strip()
        if template.startswith("/"):
            routes.add(template.strip("/"))
            continue
        joined = "/".join(part for part in (info.base_route.strip("/"), template.strip("/")) if part)
        routes.add(joined)
    if not routes:
        routes.add(info.base_route.strip("/"))
    return routes


def route_head(path: str) -> str:
    return ("/" + path.strip("/")).lower().rstrip("/").split("/{**")[0].rstrip("/")


def head_covers(head: str, target_head: str) -> bool:
    return head == target_head or target_head.startswith(head + "/")


GATEWAY_ONLY_PREFIXES = {"/health"}


def gateway_coverage() -> int:
    """Fail when a controller route has no Gateway route, or a Gateway route maps to nothing."""
    paths = load_gateway_paths()
    controllers = parse_controllers()

    expected: dict[str, tuple[str, str]] = {}
    for info in controllers:
        if info.layer == "Internal":
            continue
        for route in effective_routes(info):
            expected.setdefault(route.lower(), (info.service, info.class_name))

    missing = [
        (service, controller, "/" + route)
        for route, (service, controller) in sorted(expected.items())
        if not gateway_covers(paths, route)
    ]

    expected_heads = {route_head(route) for route in expected}
    dead = [
        path
        for path in paths
        if not any(head_covers(route_head(path), head) for head in expected_heads)
        and route_head(path) not in GATEWAY_ONLY_PREFIXES
    ]

    print(f"Gateway routes: {len(paths)}")
    print(f"Controller routes (public): {len(expected)}")
    for service, controller, route in missing:
        print(f"MISSING ROUTE  {service}:{controller}  {route}")
    for path in dead:
        print(f"DEAD ROUTE     {path}")
    print(f"Missing: {len(missing)}  Dead: {len(dead)}")
    return 0 if not missing and not dead else 1


def first_segment(route: str) -> str:
    parts = [p for p in route.strip("/").split("/") if p]
    if parts and parts[0].lower() == "api" and len(parts) > 1 and parts[1].lower() == "v1":
        parts = parts[2:]
    if parts and parts[0].lower() == "admin":
        parts = parts[1:]
    return parts[0].lower() if parts else ""


def parse_controllers() -> list[ControllerInfo]:
    paths = load_gateway_paths()
    controllers: list[ControllerInfo] = []

    for service in SERVICES:
        service_root = SERVICES_DIR / service
        if not service_root.exists():
            continue
        for cs_path in sorted(service_root.rglob("*Controller.cs")):
            if any(part in {"obj", "bin"} for part in cs_path.parts):
                continue
            text = cs_path.read_text(encoding="utf-8", errors="replace")
            lines = text.splitlines()

            ns_match = re.search(r"^namespace\s+([\w\.]+)\s*;", text, re.M)
            ns = ns_match.group(1) if ns_match else ""

            class_name = ""
            base_route = ""
            class_roles: list[str] = []
            class_has_require_role = False
            for line in lines:
                route_match = ROUTE_ATTR_RE.match(line)
                if route_match and not base_route:
                    base_route = route_match.group(1)
                role_match = REQUIRE_ROLE_RE.match(line)
                if role_match:
                    class_has_require_role = True
                    class_roles.extend(split_roles(role_match.group(1)))
                class_match = CLASS_RE.match(line)
                if class_match:
                    class_name = class_match.group(1)
                    break

            ctor_match = SERVICE_CTOR_RE.search(text)
            ctor_params = ctor_match.group(1) if ctor_match else ""

            actions = parse_actions(lines, class_roles, class_has_require_role)

            rel = cs_path.relative_to(service_root).parts
            layer = "Internal" if any(p == "Internal" for p in rel) else "Public"

            info = ControllerInfo(
                service=service,
                path=cs_path,
                layer=layer,
                ns=ns,
                class_name=class_name or cs_path.stem,
                base_route=resolve_controller_token(base_route, class_name or cs_path.stem),
                class_roles=class_roles,
                class_has_require_role=class_has_require_role,
                ctor_params=ctor_params,
                body=text,
                actions=actions,
            )
            info.checks = controller_checks(info, paths)
            for action in info.actions:
                action.checks = action_checks(action, info)
            controllers.append(info)

    return controllers


def split_roles(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [token.strip().strip('"').strip().lower() for token in raw.split(",") if token.strip()]


def parse_actions(lines: list[str], class_roles: list[str], class_has_require_role: bool) -> list[ActionInfo]:
    actions: list[ActionInfo] = []
    i = 0
    while i < len(lines):
        verb_match = HTTP_VERB_RE.match(lines[i])
        if not verb_match:
            i += 1
            continue

        start = i
        verbs: list[tuple[str, str]] = []
        roles: list[str] = []
        action_has_require_role = False
        j = i
        while j < len(lines):
            more_verb = HTTP_VERB_RE.match(lines[j])
            if more_verb:
                verbs.append((more_verb.group(1).upper(), more_verb.group(2) or ""))
                j += 1
                continue
            role_match = REQUIRE_ROLE_RE.match(lines[j])
            if role_match:
                action_has_require_role = True
                roles.extend(split_roles(role_match.group(1)))
                j += 1
                continue
            if lines[j].strip().startswith("["):
                j += 1
                continue
            break

        signature_lines: list[str] = []
        for s in range(j, min(j + 40, len(lines))):
            signature_lines.append(lines[s])
            if ")" in lines[s]:
                break
        signature_line = "\n".join(signature_lines)
        name = ""
        return_type = ""
        sig_match = SIGNATURE_RE.match(signature_lines[0] if signature_lines else "")
        if sig_match:
            return_type = sig_match.group(1).strip()
            name = sig_match.group(2)

        header_lines: list[str] = []
        for k in range(start, j):
            header_lines.append(lines[k])

        body_lines: list[str] = list(header_lines)
        depth = 0
        opened = False
        k = j
        while k < len(lines):
            body_lines.append(lines[k])
            depth += lines[k].count("{") - lines[k].count("}")
            if "{" in lines[k]:
                opened = True
            if opened and depth <= 0:
                break
            k += 1

        has_summary = False
        summary_text = ""
        back = start - 1
        while back >= 0 and lines[back].strip().startswith(("///", "[")):
            summary_match = SUMMARY_RE.match(lines[back])
            if summary_match:
                has_summary = True
                summary_text = summary_match.group(1).strip()
                break
            back -= 1

        actions.append(
            ActionInfo(
                verb=verbs[0][0] if verbs else "",
                template=verbs[0][1] if verbs else "",
                name=name or "?",
                return_type=return_type,
                signature=signature_line.strip(),
                body="\n".join(body_lines),
                has_summary=has_summary,
                summary_text=summary_text,
                require_roles=roles if roles else list(class_roles),
                has_require_role=action_has_require_role or class_has_require_role,
                http_attr_count=len(verbs),
                checks=[],
            )
        )
        i = max(k + 1, start + 1)

    return actions


def controller_checks(info: ControllerInfo, gateway_paths: list[str]) -> list[Check]:
    checks: list[Check] = []

    in_public = "/Controllers/Public/" in str(info.path).replace("\\", "/")
    in_internal = "/Controllers/Internal/" in str(info.path).replace("\\", "/")
    checks.append(
        Check(
            "Segregation: file lives under `Controllers/Public/` or `Controllers/Internal/`",
            in_public or in_internal,
            "" if (in_public or in_internal) else f"found under {info.path.parent.name}/",
        )
    )

    literal_ok = bool(info.base_route) and "[controller]" not in info.base_route.lower()
    checks.append(
        Check(
            "Class route is a literal lowercase path (no `[controller]` token)", literal_ok, info.base_route
        )
    )

    prefix_ok = info.base_route.lower().startswith("api/v1/")
    checks.append(Check("Class route starts with `api/v1/`", prefix_ok, info.base_route))

    if in_internal:
        internal_ok = info.base_route.lower().startswith("api/v1/internal/")
        checks.append(Check("Internal controller mounts under `api/v1/internal/`", internal_ok, info.base_route))
        checks.append(Check("Gateway does not expose this controller (internal isolation)", True, "skipped by design"))
    else:
        checks.append(Check("Public controller does not mount under `/internal`", "/internal" not in info.base_route.lower()))
        covered = gateway_covers(gateway_paths, info.base_route)
        checks.append(Check("Gateway YARP has a route covering the base path", covered, info.base_route))

    no_db = "DbContext" not in info.body.replace("I" + info.service + "DbContext", "")
    checks.append(Check("Controller performs no direct DbContext access", no_db))

    identity_guarded = "GetUserId()" not in info.body or "TryGetUserId" in info.body
    checks.append(
        Check(
            "Caller identity is read through `TryGetUserId`, not a nullable `GetUserId`",
            identity_guarded,
            "" if identity_guarded else "GetUserId() is passed downstream without an auth guard",
        )
    )

    cqrs_exception = f"{info.service}:{info.class_name}" in CQRS_DISPATCHER_CONTROLLERS
    if cqrs_exception:
        dispatcher = "ISender" in info.ctor_params
        checks.append(
            Check(
                "Thin controller dispatches through MediatR `ISender` (Wallet CQRS exception)",
                dispatcher,
                "ISender" if dispatcher else "no ISender injection",
            )
        )
        return checks

    service_injections = [
        token
        for token in re.findall(r"\bI(\w+(?:Service|Manager|Client))\b", info.ctor_params)
        if not token.endswith("Logger")
    ]
    checks.append(
        Check(
            "Thin controller injects exactly one collaborating feature abstraction",
            len(service_injections) == 1,
            f"injects: {', '.join(service_injections) or 'none'}",
        )
    )

    return checks


def strip_route_params(template: str) -> str:
    return re.sub(r"\{[^}]*\}", "", template)


def route_segments(template: str) -> list[str]:
    return [p for p in strip_route_params(template).strip("/").split("/") if p]


def route_has_param(template: str) -> bool:
    return bool(re.search(r"\{[^}]*\}", template))


def action_checks(action: ActionInfo, info: ControllerInfo) -> list[Check]:
    checks: list[Check] = []

    checks.append(Check("Single-line XML `<summary>` on the action", action.has_summary, action.summary_text))

    checks.append(
        Check(
            "Exactly one HTTP verb attribute on the action (no duplicate route alias)",
            action.http_attr_count == 1,
            f"{action.http_attr_count} verb attributes",
        )
    )

    template = action.template
    absolute = template.startswith("/")
    checks.append(
        Check(
            "Action route stays inside the controller resource (no absolute override)",
            not absolute,
            template,
        )
    )

    base_segment = strip_route_params(info.base_route).strip("/").split("/")[-1].lower()
    if absolute:
        trimmed = template.strip("/").split("/")
        if len(trimmed) >= 3 and trimmed[0].lower() == "api" and trimmed[1].lower() == "v1":
            trimmed = trimmed[2:]
        if trimmed and trimmed[0].lower() == "admin":
            trimmed = trimmed[1:]
        segments = [p for p in trimmed if p]
    else:
        segments = route_segments(template)
    candidate = segments[0].lower() if segments else base_segment
    plural_ok = (
        not candidate
        or candidate.endswith("s")
        or candidate in ALLOWED_SINGULAR
        or candidate in ALLOWED_FILTER_SEGMENTS
        or (route_has_param(template) and not segments)
    )
    checks.append(Check("Route uses a plural collection or an allowed singleton/filter", plural_ok, candidate or "-"))

    written = {p for p in segments if p.isalpha()}
    kebab_ok = all(p.islower() for p in written)
    checks.append(
        Check(
            "Route segments are lowercase (kebab-case for compounds)",
            kebab_ok,
            template or "-",
        )
    )

    anonymous = any(hint in f"{info.base_route}/{template}".lower() for hint in ANONYMOUS_ACTION_HINTS)
    api_key_protected = f"{info.service}:{info.class_name}" in API_KEY_PROTECTED_CONTROLLERS
    rbac_needed = action.verb in MUTATING_VERBS
    rbac_ok = (
        action.has_require_role
        or anonymous
        or api_key_protected
        or info.layer == "Internal"
        or not rbac_needed
    )
    checks.append(
        Check(
            "Mutating action declares authorization (`[RequireRole]` or API-key middleware), or is a documented anonymous endpoint",
            rbac_ok,
            ", ".join(action.require_roles) or ("api-key" if api_key_protected else ("anonymous" if anonymous else "missing")),
        )
    )

    identity_params = re.findall(
        r"\[From(?:Query|Route)\]\s*Guid\??\s+((?:buyer|seller|owner|bidder|user)Id)\b", action.signature
    )
    privileged = any(role in {"admin", "staff"} for role in action.require_roles)
    if identity_params and not privileged:
        ownership = any(token in action.body for token in OWNERSHIP_TOKENS)
        checks.append(
            Check(
                "Caller identity parameters are verified against the token (no trusting `buyerId`/`sellerId` from the client)",
                ownership,
                ", ".join(identity_params),
            )
        )

    name_lower = action.name.lower()
    is_list = name_lower.startswith(("list", "query", "search", "getall"))
    bounded = f"{info.service}:{info.class_name}:{action.name}" in BOUNDED_REFERENCE_ACTIONS
    lowered_signature = action.signature.lower()
    paged_ok = True
    if is_list and not bounded:
        paged_ok = any(
            token in action.return_type or token in action.body
            for token in ("PagedData", "Paged", "PageResponse")
        ) or ("page" in lowered_signature and ("pagesize" in lowered_signature or "limit" in lowered_signature))
    checks.append(
        Check(
            "List/query action returns a paged envelope (pagination computed in the database)",
            paged_ok,
            "bounded reference collection (accepted by exception)"
            if bounded
            else action.return_type or "IActionResult",
        )
    )

    if is_list and not bounded and "pagesize" in lowered_signature:
        clamp_ok = bool(PAGE_SIZE_CLAMP_RE.search(action.body))
        checks.append(
            Check(
                "List action clamps `pageSize` to a maximum (client cannot request an unbounded page)",
                clamp_ok,
                "" if clamp_ok else "pageSize is forwarded as supplied",
            )
        )

    if re.search(r"\[fromquery\]\s*int\s+limit", lowered_signature):
        limit_ok = bool(LIMIT_CLAMP_RE.search(action.body))
        checks.append(
            Check(
                "Query cap parameter `limit` is clamped to a maximum",
                limit_ok,
                "" if limit_ok else "limit is forwarded as supplied",
            )
        )

    enum_lowercased = bool(ENUM_LOWERCASE_RE.search(action.body))
    checks.append(
        Check(
            "Response enum values stay PascalCase (no manual `ToString().ToLower...`)",
            not enum_lowercased,
            "enum lowercased in the response body" if enum_lowercased else "",
        )
    )

    is_delete = action.verb == "DELETE"
    returns_no_content = "NoContent(" in action.body
    checks.append(
        Check(
            "Deletion returns `204 NoContent` with an empty body",
            (not is_delete) or returns_no_content,
            "Ok(...)" if (is_delete and not returns_no_content) else "NoContent",
        )
    )

    if is_delete:
        requires_body = "[FromBody]" in action.signature
        body_optional = "EmptyBodyBehavior" in action.signature
        checks.append(
            Check(
                "Deletion accepts an empty request body",
                (not requires_body) or body_optional,
                "" if (not requires_body) or body_optional else "[FromBody] is mandatory",
            )
        )

    declares_error_status = bool(
        re.search(r"ProducesResponseType\(\s*StatusCodes\.Status[45]\d\d", action.body)
    )
    checks.append(
        Check(
            "Controller declares no error status codes (the error matrix lives in the API doc)",
            not declares_error_status,
            "" if not declares_error_status else "declares a 4xx/5xx response",
        )
    )

    return checks


def render_controller(info: ControllerInfo) -> str:
    total = len(info.checks) + sum(len(a.checks) for a in info.actions)
    unchecked = sum(1 for c in info.checks if not c.ok) + sum(1 for a in info.actions for c in a.checks if not c.ok)

    lines: list[str] = []
    lines.append(f"# AUDIT: {info.class_name} — {info.service}Service")
    lines.append("")
    lines.append(
        "> Generated by `tools/audit_controllers.py`. Re-run to refresh. "
        "Each box states one static invariant; an unchecked box means the source does not satisfy it. "
        "The Gateway owns the response envelope (`specs/06`), so envelopes are not checked here."
    )
    lines.append("")
    lines.append(f"- **File**: `{info.path.relative_to(ROOT).as_posix()}`")
    lines.append(f"- **Layer**: {info.layer}")
    lines.append(f"- **Base Route**: `/{info.base_route.strip('/')}`")
    lines.append(f"- **Namespace**: `{info.ns}`")
    lines.append(f"- **Endpoints**: {len(info.actions)}")
    lines.append(f"- **Open violations**: {unchecked} / {total}")
    lines.append("")
    lines.append("## Controller-level")
    lines.append("")
    for check in info.checks:
        mark = "x" if check.ok else " "
        note = f" — `{check.note}`" if check.note else ""
        lines.append(f"- [{mark}] {check.label}{note}")
    lines.append("")

    for action in info.actions:
        route = (action.template or "").strip("/")
        full = f"{info.base_route.strip('/')}/{route}".strip("/") if route else info.base_route.strip("/")
        if action.template.startswith("/"):
            full = action.template.strip("/")
        lines.append(f"### `{action.verb} /{full}` — `{action.name}`")
        lines.append("")
        lines.append(f"- **Return**: `{action.return_type or 'unknown'}`")
        lines.append(f"- **RBAC**: {', '.join(action.require_roles) or 'none'}")
        lines.append("")
        for check in action.checks:
            mark = "x" if check.ok else " "
            note = f" — `{check.note}`" if check.note else ""
            lines.append(f"- [{mark}] {check.label}{note}")
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    if "--gateway-coverage" in sys.argv[1:]:
        return gateway_coverage()

    controllers = parse_controllers()
    if not controllers:
        print("no controllers found", file=sys.stderr)
        return 1

    FIX_DIR.mkdir(parents=True, exist_ok=True)
    total_violations = 0
    summary_rows: list[str] = []
    expected: dict[Path, set[str]] = {}

    for info in controllers:
        out_dir = FIX_DIR / info.service
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{info.class_name}.md"
        expected.setdefault(out_dir, set()).add(out_path.name)
        out_path.write_text(render_controller(info), encoding="utf-8")

        violations = sum(1 for c in info.checks if not c.ok) + sum(
            1 for a in info.actions for c in a.checks if not c.ok
        )
        total_violations += violations
        summary_rows.append(
            f"{info.service:<13} {info.class_name:<32} endpoints={len(info.actions):<3} open={violations}"
        )

    for directory, names in expected.items():
        for stale in directory.glob("*.md"):
            if stale.name not in names:
                stale.unlink()

    print(f"Audited {len(controllers)} controllers on {datetime.now(timezone.utc).date()}.")
    for row in summary_rows:
        print("  " + row)
    print(f"Total open violations: {total_violations}")

    index_lines: list[str] = []
    index_lines.append("# CONTROLLER SYNC AUDIT")
    index_lines.append("")
    index_lines.append(
        f"> Generated by `tools/audit_controllers.py` on {datetime.now(timezone.utc):%Y-%m-%d %H:%M UTC}. "
        "Re-run the script to refresh. Each box states one static invariant; a checked box means the source satisfies it. "
        "The Gateway owns the response envelope (`specs/06`), so envelopes are not checked here."
    )
    index_lines.append("")
    index_lines.append("| Service | Controller | Endpoints | Open |")
    index_lines.append("|:---|:---|---:|---:|")
    for info in controllers:
        violations = sum(1 for c in info.checks if not c.ok) + sum(
            1 for a in info.actions for c in a.checks if not c.ok
        )
        index_lines.append(
            f"| {info.service} | [{info.class_name}]({info.service}/{info.class_name}.md) | {len(info.actions)} | {violations} |"
        )
    index_lines.append("")
    index_lines.append(f"**Total open violations: {total_violations}**")
    index_lines.append("")
    (FIX_DIR / "README.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
