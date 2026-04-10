# Session Summary: OAuth Scope Leniency & RFC 9728 Protected Resource Metadata

| Date | Phase | Status |
| :--- | :--- | :--- |
| 2026-04-10 | OAuth Interoperability Fix | COMPLETED |

## 1. Core Objective

Fix OAuth authentication failures across all SwiftMCPServer-based MCP deployments caused by strict scope validation and missing RFC 9728 endpoint. Claude Code could not authenticate, returning `invalid_scope`.

## 2. Design Decisions

- **Decision:** Accept any OAuth scope rather than rejecting unknown values; default to all MCP scopes when scope is nil/empty
- **Rationale:** RFC 6749 Section 3.3 permits lenient handling; Claude Code bug (anthropics/claude-code#12077) means clients may send unexpected scopes
- **Alternatives Considered:** Fix only client-side (rejected: requires waiting for upstream fix and doesn't achieve spec compliance)

- **Decision:** Use string interpolation for GetPrompt arguments conversion instead of `#if swift(>=6.1)` compile-time check
- **Rationale:** Swift version doesn't determine swift-sdk version; interpolation works for both `String` and `Value` types
- **Alternatives Considered:** `#if canImport` with version (rejected: not supported by SPM)

See ADR-012 and ADR-013 in `06_ARCHITECTURE_DECISIONS.md`.

## 3. Work Completed

### Design Proposal
- [x] Architecture proposed: `development-guidelines/02_IMPLEMENTATION_PLANS/UPCOMING/OAuthScopeLeniencyAndProtectedResource.md`
- [x] API surface defined (ProtectedResourceMetadata model, two handler methods)
- [x] Constraints compliance verified (Sendable, Swift 6, no new deps)

### Tests Written (RED phase)
- [x] Golden path: Valid MCP scopes still work
- [x] Edge cases: nil scope defaults, empty scope defaults, whitespace-only scope defaults
- [x] Invalid input: Unknown scopes accepted (openid, profile), mixed known+unknown scopes
- [x] Validation path: `validateAuthorizationRequest` also accepts unknown scopes
- [x] Protected resource metadata: RFC 9728 compliance (OAuthServer + OAuthHTTPHandler levels)

**8 new tests added, 280 total tests passing.**

### Implementation (GREEN phase)
- [x] Files modified:
  - `Sources/SwiftMCPServer/OAuth/OAuthServer.swift` — Scope leniency, `getProtectedResourceMetadata()`, `ProtectedResourceMetadata` model
  - `Sources/SwiftMCPServer/OAuth/OAuthHTTPHandler.swift` — `handleProtectedResourceMetadata()` handler
  - `Sources/SwiftMCPServer/Transport/MCPServerHandler.swift` — Route `GET /.well-known/oauth-protected-resource`
  - `Sources/SwiftMCPServer/MCPServer.swift` — Version-agnostic GetPrompt arguments conversion
- [x] Tests modified:
  - `Tests/SwiftMCPServerTests/OAuthServerTests.swift` — 7 new tests (scope leniency + protected resource)
  - `Tests/SwiftMCPServerTests/OAuthHTTPHandlerTests.swift` — 2 new tests (protected resource HTTP)

### Documentation
- [x] DocC comments on all new public types and methods
- [x] Design proposal archived in UPCOMING

## 4. Mandatory Quality Gate (Zero Tolerance)

| Check | Status |
| :--- | :--- |
| **build** | 0 errors, 0 warnings |
| **test** | 280/280 passing |

## 5. Project State Updates

- [x] Design proposal in `development-guidelines/02_IMPLEMENTATION_PLANS/UPCOMING/`
- [x] ADR-012 and ADR-013 added to `06_ARCHITECTURE_DECISIONS.md`

## 6. Next Session Handover (Context Recovery)

### Immediate Starting Point

All work for this feature is complete and deployed. No pending implementation.

### Deployment Status

All three servers redeployed to roseclub.org on Swift 6.3.0 with swift-sdk 0.12.0:

| Server | Port | SwiftMCPServer commit | Status |
|---|---|---|---|
| BusinessMathMCP | :8080 | e5747f0 | Running, OAuth verified |
| GeoSEOMCP | :8081 | e5747f0 | Running, endpoint verified |
| DevGuidelinesMCP | :8082 | e5747f0 (local path) | Running, endpoint verified |

### Additional Changes Made

- **roseclub.org Swift version:** Switched global default from 6.2.4 back to 6.3.0
- **GeoSEOMCP Package.swift:** Relaxed swift-sdk pin from `exact: "0.10.0"` to `from: "0.10.0"` (commit 48d9348)
- **SwiftMCPServer:** Added development-guidelines and `.claude/` configuration

### Pending Tasks

- [ ] Move design proposal to `COMPLETED/` once confirmed stable in production
- [ ] Consider submitting upstream improvements to modelcontextprotocol/swift-sdk if scope handling issues persist

### Blockers

None.

### Context Loss Warning

- The server uses `nonisolated(unsafe)` for the NWConnection property in MCPServerHandler — this is intentional and justified, not a shortcut. Don't refactor it away.
- DevGuidelinesMCP uses a **local path** dependency (`../SwiftMCPServer`) on roseclub.org, not a git URL. Updates require `git pull` in `~/SwiftMCPServer` on the server, not `swift package update`.
- roseclub.org has both Swift 6.0.3 (`/usr/bin/swift` via Xcode) and 6.3.0 (`~/.swiftly/bin/swift` via Swiftly). Always use the Swiftly path for builds.

---

**Session Duration:** ~1.5 hours
**AI Model Used:** Claude Opus 4.6
