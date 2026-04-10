# Design Proposal: SwiftMCPServer — Infrastructure Extraction

## 1. Objective

**Objective:** Extract the reusable MCP server infrastructure from BusinessMathMCP into a standalone Swift package (`SwiftMCPServer`) so that multiple MCP tool sets can share the same transport, authentication, and session management code.

**Master Plan Reference:** Phase 1 — Extraction

**Problem:** BusinessMathMCP contains ~8,200 lines of server infrastructure (HTTP transport, auth, OAuth, sessions, tool registry) tightly coupled with ~34,200 lines of domain-specific financial tools. Adding a second tool set (GeoSEO) would require duplicating all infrastructure code.

**Solution:** Extract infrastructure into a Swift package. BusinessMathMCP becomes the first consumer; GeoSEO becomes the second.

---

## 2. Proposed Architecture

### Source Files to Extract (from BusinessMathMCP → SwiftMCPServer)

**New package structure:**

```
Sources/SwiftMCPServer/
├── Transport/
│   ├── HTTPServerTransport.swift       (from HTTPServerTransport.swift)
│   ├── MCPServerHandler.swift          (from MCPServerHandler.swift)
│   ├── HTTPConnection.swift            (from HTTPConnection.swift)
│   ├── NIOHTTPConnection.swift         (from NIOHTTPConnection.swift)
│   └── HTTPModels.swift                (from HTTPModels.swift)
├── Session/
│   ├── StreamableSessionManager.swift  (from StreamableSessionManager.swift)
│   ├── SSESessionManager.swift         (from SSESessionManager.swift)
│   └── SSESession.swift                (from SSESession.swift)
├── Auth/
│   ├── APIKeyAuthenticator.swift       (from APIKeyAuthenticator.swift)
│   └── APIKeyStore.swift               (from APIKeyStore.swift)
├── OAuth/
│   ├── OAuthServer.swift               (from OAuth/OAuthServer.swift)
│   ├── OAuthStorage.swift              (from OAuth/OAuthStorage.swift)
│   ├── OAuthHTTPHandler.swift          (from OAuth/OAuthHTTPHandler.swift)
│   ├── OAuthModels.swift               (from OAuth/OAuthModels.swift)
│   ├── PKCE.swift                      (from OAuth/PKCE.swift)
│   ├── TokenGenerator.swift            (from OAuth/TokenGenerator.swift)
│   └── ConsentPage.swift               (from OAuth/ConsentPage.swift)
├── Response/
│   └── HTTPResponseManager.swift       (from HTTPResponseManager.swift)
├── Tools/
│   ├── ToolDefinition.swift            (from ToolDefinition.swift)
│   ├── MCPCompat.swift                 (from MCPCompat.swift)
│   └── TypeMarshalling.swift           (from TypeMarshalling.swift)
├── Logging/
│   └── LoggingConfiguration.swift      (from LoggingConfiguration.swift)
└── Utilities/
    ├── ValueExtensions.swift           (from ValueExtensions.swift)
    └── CrossPlatformExpression.swift   (from CrossPlatformExpression.swift)
```

**Files that stay in BusinessMathMCP:**

- All 49 files in `Sources/BusinessMathMCP/Tools/` (domain-specific calculators)
- `Resources.swift` (financial documentation content)
- `Prompts.swift` (financial analysis templates)
- `Sources/BusinessMathMCPServer/main.swift` (slimmed down — just tool registration + server boot)

### Modified Files

- **BusinessMathMCP `Package.swift`**: Add dependency on SwiftMCPServer, remove SwiftNIO/NIOSSL/Crypto direct deps
- **BusinessMathMCP `main.swift`**: Import SwiftMCPServer, use its `MCPServer` type for bootstrapping
- **BusinessMathMCP `Sources/BusinessMathMCP/`**: Remove extracted files, keep only tools + resources + prompts

---

## 3. API Surface

### Primary Entry Point — `MCPServer`

A new convenience type that replaces the raw bootstrapping code currently in `main.swift`:

```swift
/// Main entry point for building MCP servers.
/// Configures transport, auth, and tool registration.
public struct MCPServerConfiguration: Sendable {
    public var port: UInt16
    public var tlsCertPath: String?
    public var tlsKeyPath: String?
    public var authenticator: APIKeyAuthenticator?
    public var oauthServer: OAuthServer?
    public var verbose: Bool

    public init(
        port: UInt16 = 8080,
        tlsCertPath: String? = nil,
        tlsKeyPath: String? = nil,
        authenticator: APIKeyAuthenticator? = nil,
        oauthServer: OAuthServer? = nil,
        verbose: Bool = false
    )
}
```

### Tool Registration Protocol (already exists)

```swift
public protocol MCPToolHandler: Sendable {
    var tool: MCPTool { get }
    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult
}
```

### Tool Registry (already exists)

```swift
public actor ToolDefinitionRegistry {
    public func register(_ definition: ToolDefinition) async throws
    public func listTools() async -> [ToolDefinition]
    public func execute(name: String, arguments: [String: Any]?) async throws -> String
}
```

### Type Marshalling (already exists)

```swift
public func getDouble(_ args: [String: Any]?, _ key: String) throws -> Double
public func getInt(_ args: [String: Any]?, _ key: String) throws -> Int
public func getString(_ args: [String: Any]?, _ key: String) throws -> String
// ... etc
```

---

## 4. MCP Schema

Not applicable — this is a framework package, not a tool provider. MCP schemas are defined by consumers (BusinessMathMCP, GeoSEO, etc.).

---

## 5. Constraints & Compliance

**Concurrency:** All actors and Sendable types already Swift 6 compliant
**Platform:** macOS 14+ and Linux (SwiftNIO handles cross-platform)
**Safety:** No force unwraps in existing code; maintained during extraction
**Dependencies:** MCP SDK, SwiftNIO, NIOSSL, swift-crypto, CSQLite (all already in use)
**Backward Compatibility:** BusinessMathMCP must produce identical behavior after depending on this package

---

## 6. Backend Abstraction

Not applicable — this is networking/server infrastructure, not compute-intensive.

---

## 7. Dependencies

**External Dependencies (carried over from BusinessMathMCP):**
- `modelcontextprotocol/swift-sdk` (>=0.10.0) — MCP protocol types
- `apple/swift-nio` (>=2.65.0) — HTTP server
- `apple/swift-nio-ssl` (>=2.26.0) — TLS/HTTPS
- `apple/swift-crypto` (>=3.0.0) — Token generation, hashing
- `CSQLite` (system library) — OAuth + API key storage

**NOT carried over (domain-specific):**
- `jpurnell/businessMath` — stays with BusinessMathMCP
- `apple/swift-numerics` — stays with BusinessMathMCP
- `apple/swift-docc-plugin` — add independently if needed

---

## 8. Test Strategy

**Test Categories:**

1. **Transport Tests** (from existing HTTPTransportTests + SSETransportTests)
   - Server starts and binds to port
   - Health endpoint returns 200
   - Server info returns JSON
   - POST /mcp routes JSON-RPC correctly
   - DELETE /mcp terminates sessions
   - SSE stream opens and receives events

2. **Auth Tests** (from existing APIAuthTests)
   - Valid/invalid API key validation
   - Bearer token format parsing
   - Protected endpoint rejects without auth
   - Protected endpoint accepts with valid auth
   - No authenticator means no auth required

3. **Session Tests**
   - Session creation returns unique IDs
   - Session validation accepts valid, rejects invalid
   - Session timeout after inactivity
   - Session touch resets timeout

4. **Tool Registry Tests**
   - Register tool, list tools, execute by name
   - Duplicate registration handling
   - Unknown tool execution returns error

5. **Type Marshalling Tests**
   - getDouble/getInt/getString with valid args
   - Missing required parameter throws
   - Type mismatch throws

6. **OAuth Tests** (from existing OAuthTests if any, or new)
   - Discovery endpoint returns metadata
   - Client registration flow
   - Authorization code flow with PKCE
   - Token refresh

**Reference Truth:** Existing BusinessMathMCP test suite — all tests must produce identical results after extraction.

**Validation Trace:** Run BusinessMathMCP full test suite before and after extraction; diff must be empty (same pass/fail).

---

## 9. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `06_ARCHITECTURE_DECISIONS.md` for related decisions
- [x] Does this supersede an existing ADR? No (new project)
- [x] Does this amend an existing ADR? No
- [x] New ADR required? Yes

**New ADR Draft:**

```yaml
id: ADR-001
date: 2026-03-19
status: accepted
category: architecture
title: Extract MCP server infrastructure into reusable SwiftMCPServer package
decision: |
  All transport, auth, OAuth, session management, response routing, tool registry,
  and type marshalling code is extracted from BusinessMathMCP into a standalone
  Swift package. Domain-specific tools remain in their respective projects.
rationale: |
  - Prevents code duplication when adding new MCP tool sets (GeoSEO, etc.)
  - Clean separation of concerns (infrastructure vs domain logic)
  - Enables independent versioning and testing of server infrastructure
  - Existing code is already naturally separated along this boundary
alternatives_rejected:
  - "Copy infrastructure per project: Duplicates ~8,200 lines, diverges over time"
  - "Single server with all tools: Couples unrelated domains, bloats deployment"
  - "Plugin/dynamic loading: Over-engineered for current needs, Swift lacks stable ABI for plugins"
affected_files:
  - Sources/SwiftMCPServer/**
  - BusinessMathMCP/Package.swift (adds dependency)
  - BusinessMathMCP/Sources/ (removes extracted files)
```

---

## 10. Open Questions — RESOLVED

1. **Should `MCPServerConfiguration` include a builder pattern or just use struct init?**
   **Decision:** Builder pattern. Hard to add later; do it from the start.

2. **Should `Resources.swift` and `Prompts.swift` support be in the framework?**
   **Decision:** Extract the registration mechanism; keep content in consumers.

3. **Should the `main.swift` bootstrapping logic become a reusable function in the package?**
   **Decision:** Yes — provide `MCPServer.run()` that handles signal trapping, CLI arg parsing for common flags (--port, --tls-cert, --generate-key), and server lifecycle.

---

## 11. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Threshold Check:**
- Does it combine 3+ APIs? Yes (transport, auth, tools, sessions)
- Does explanation require 50+ lines? Yes
- Does it need theory/background context? Yes (MCP protocol, OAuth flows)

**Articles Required:**
- `GettingStartedGuide.md` — How to create a new MCP server using this package
- `AuthenticationGuide.md` — API key and OAuth setup
- `ToolRegistrationGuide.md` — Implementing and registering custom tools
