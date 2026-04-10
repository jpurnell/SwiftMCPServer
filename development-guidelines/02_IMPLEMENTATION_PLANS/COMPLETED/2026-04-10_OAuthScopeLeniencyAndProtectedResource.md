# Design Proposal: OAuth Scope Leniency & Protected Resource Metadata

## 1. Objective

**Problem:** Claude Code (and potentially other MCP clients) fail OAuth authentication against SwiftMCPServer with `invalid_scope` errors. Root causes:

1. **Missing `/.well-known/oauth-protected-resource` endpoint (RFC 9728):** The MCP auth spec requires this endpoint so clients can discover which authorization server to use and which scopes to request. Without it, clients guess — and guess wrong.
2. **Strict scope validation:** The server rejects any scope not in the hardcoded set `["mcp:tools", "mcp:resources", "mcp:prompts"]`. Clients like Claude Code may send different or no scopes due to implementation bugs or spec evolution.

**Impact:** All three MCP servers using SwiftMCPServer (BusinessMathMCP, DevGuidelinesMCP, GeoSeoMCP) are affected.

**Reference:** [anthropics/claude-code#12077](https://github.com/anthropics/claude-code/issues/12077)

## 2. Proposed Architecture

**Modified Files:**
- `Sources/SwiftMCPServer/OAuth/OAuthServer.swift` — Relax scope validation, add `getProtectedResourceMetadata()`, make default scopes configurable
- `Sources/SwiftMCPServer/OAuth/OAuthHTTPHandler.swift` — Add `handleProtectedResourceMetadata()` handler
- `Sources/SwiftMCPServer/Transport/MCPServerHandler.swift` — Route `GET /.well-known/oauth-protected-resource`

**No new files required.** All changes extend existing modules.

## 3. API Surface

```swift
// New in OAuthServer
public func getProtectedResourceMetadata() -> ProtectedResourceMetadata

// New model (added to OAuthServer.swift alongside ServerMetadata)
public struct ProtectedResourceMetadata: Codable, Sendable {
    public let resource: String
    public let authorizationServers: [String]
    public let scopesSupported: [String]
    public let bearerMethodsSupported: [String]
}

// New in OAuthHTTPHandler
public func handleProtectedResourceMetadata() async -> OAuthHTTPResponse
```

### Scope Validation Behavior Change

| Scope value sent by client | Current behavior | New behavior |
|---|---|---|
| `nil` (no scope) | Passes (no validation) | Passes, defaults to `"mcp:tools mcp:resources mcp:prompts"` in auth code |
| `""` (empty string) | Passes (empty set ⊆ anything) | Treated same as nil, defaults to all scopes |
| `"mcp:tools"` | Passes | Passes (no change) |
| `"mcp:tools mcp:resources"` | Passes | Passes (no change) |
| `"openid profile"` or other unknown | **Rejects with `invalid_scope`** | **Passes** — unknown scopes accepted |

**Rationale:** Per RFC 6749 §3.3, if the client sends scopes the server doesn't understand, the server MAY ignore them rather than reject. Being lenient here is critical for interoperability with evolving MCP clients.

## 4. MCP Schema

Not applicable — this is server infrastructure, not a tool.

## 5. Constraints & Compliance

- **Concurrency:** `ProtectedResourceMetadata` is `Sendable` (immutable value type)
- **Swift 6:** All new code is strict-concurrency safe
- **RFC compliance:** Implements RFC 9728 (Protected Resource Metadata)
- **Backward compatible:** No breaking changes to existing public API
- **No new dependencies**

## 6. Backend Abstraction

Not applicable — no compute-intensive operations.

## 7. Dependencies

**Internal:** `OAuthServer`, `OAuthHTTPHandler`, `MCPServerHandler` (all existing)
**External:** None

## 8. Test Strategy

**Test Categories:**

### OAuthServerTests (scope validation)
- **Golden path:** Authorization with valid MCP scope still works
- **No scope:** Authorization with `nil` scope succeeds, defaults to all scopes in auth code
- **Empty scope:** Authorization with `""` scope succeeds, defaults to all scopes
- **Unknown scope:** Authorization with non-MCP scopes (e.g., `"openid"`) succeeds
- **Mixed scopes:** Known + unknown scopes together succeed
- **Protected resource metadata:** Returns correct structure with issuer/scopes

### OAuthHTTPHandlerTests (HTTP layer)
- **Protected resource metadata endpoint:** Returns 200 with correct JSON
- **RFC 9728 compliance:** Response contains required fields (`resource`, `authorization_servers`)

### MCPServerHandler routing (tested indirectly via integration)
- **Route exists:** `GET /.well-known/oauth-protected-resource` returns 200 (not 404)
- **Public endpoint:** No auth required for metadata endpoint

**Reference Truth:** RFC 9728 Section 2 defines the response format. RFC 6749 Section 3.3 permits lenient scope handling.

**Validation Trace:**
- `GET /.well-known/oauth-protected-resource` → `{"resource":"https://example.com","authorization_servers":["https://example.com"],"scopes_supported":["mcp:tools","mcp:resources","mcp:prompts"],"bearer_methods_supported":["header"]}`
- Auth request with `scope=nil` → auth code stored with `scope="mcp:tools mcp:resources mcp:prompts"`
- Auth request with `scope="openid"` → auth code stored with `scope="openid"` (no rejection)

## 9. Architecture Decision Review

**ADR Check:**
- [x] No existing ADR for scope handling
- [ ] Does not supersede any ADR
- [ ] Does not amend any ADR
- [x] No new ADR required — this is a spec-compliance fix, not an architectural decision

## 10. Open Questions

None — the approach is straightforward spec compliance.

## 11. Documentation Strategy

**Documentation Type:** API Docs Only

No narrative article needed — changes are internal to the OAuth subsystem.
