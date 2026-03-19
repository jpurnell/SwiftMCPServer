# SwiftMCPServer Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

---

## Project Overview

### Mission
Provide a reusable, production-ready Swift package for building MCP (Model Context Protocol) servers. Extracted from the battle-tested BusinessMathMCP server infrastructure, SwiftMCPServer handles all transport, authentication, session management, and tool registration so that domain-specific tool sets can focus purely on their business logic.

### Target Users
- Swift developers building MCP tool servers
- Projects that need multiple MCP tool sets sharing the same infrastructure
- Existing BusinessMathMCP project (first consumer — validates the extraction)

### Key Differentiators
- Cross-platform (macOS + Linux) via SwiftNIO
- MCP Streamable HTTP transport (spec 2025-03-26) with legacy SSE fallback
- Built-in HTTPS (NIOSSL), API key auth, and full OAuth 2.0 server
- Protocol-based tool registration — bring your own tools
- Extracted from production server handling 187+ tools

---

## Architecture

### Technology Stack
- **Language:** Swift 6.0+
- **Frameworks:** SwiftNIO, NIOSSL, swift-crypto, MCP SDK
- **Build System:** SPM
- **Testing:** Swift Testing
- **Platforms:** macOS 14+, Linux

### Module Structure

```
SwiftMCPServer/
├── Sources/
│   └── SwiftMCPServer/
│       ├── Transport/          # HTTP transport, NIO handlers, connections
│       ├── Session/            # Streamable HTTP + legacy SSE sessions
│       ├── Auth/               # API key authenticator + key store
│       ├── OAuth/              # Full OAuth 2.0 server
│       ├── Response/           # JSON-RPC response routing
│       ├── Tools/              # Tool protocol, registry, type marshalling
│       └── Logging/            # Logging configuration
├── Tests/
│   └── SwiftMCPServerTests/
└── Package.swift
```

### Key Types

| Type | Purpose |
|------|---------|
| `MCPServer` | Main entry point — configures and runs the server |
| `HTTPServerTransport` | SwiftNIO-based HTTP/HTTPS server (MCP Streamable HTTP) |
| `MCPServerHandler` | NIO channel handler for request routing |
| `StreamableSessionManager` | MCP session lifecycle management |
| `APIKeyAuthenticator` | API key validation (hashed, multi-key) |
| `OAuthServer` | OAuth 2.0 authorization server (RFC 6749, PKCE, dynamic registration) |
| `ToolDefinitionRegistry` | Tool registration and dispatch |
| `MCPToolHandler` | Protocol that tool implementations conform to |
| `HTTPResponseManager` | JSON-RPC request/response correlation |

---

## Current Status

### What's Working
- [ ] Initial project setup
- [ ] Design proposal approved

### Known Issues
- N/A (new project)

### Current Priorities
1. Extract server infrastructure from BusinessMathMCP into this package
2. Ensure BusinessMathMCP can depend on this package with zero behavior changes
3. Establish test suite covering transport, auth, sessions, and tool dispatch

---

## Quality Standards

### Code Quality
- All code follows `01_CODING_RULES.md`
- Test coverage target: 100%
- Documentation for all public APIs
- No warnings in build output
- **License:** MIT (public GitHub repo)

### Documentation Quality
- DocC comments for all public functions
- Usage examples in documentation
- Articles for complex topics (OAuth setup, tool registration)

---

## Error Registry

### Error Types

| Error Enum | Case | When Thrown | Module |
|------------|------|------------|--------|
| `MCPServerError` | `.failedToCreateListener` | Port binding fails | Transport |
| `MCPServerError` | `.notConnected` | Operation attempted before `connect()` | Transport |
| `MCPServerError` | `.invalidConfiguration(message:)` | Missing TLS cert, bad port, etc. | Server |
| `ValueExtractionError` | `.missingRequired(name:)` | Required tool parameter missing | Tools |
| `ValueExtractionError` | `.typeMismatch(name:expected:)` | Tool parameter wrong type | Tools |

### Error Design Principles

- **One error enum per domain boundary** — avoid proliferating error types
- **Descriptive associated values** — include context (parameter name, expected range, etc.)
- **No overlapping cases** — each case covers a distinct failure mode

---

## Roadmap

### Phase 1: Extraction
- [ ] Extract infrastructure from BusinessMathMCP
- [ ] Package compiles and tests pass independently
- [ ] BusinessMathMCP depends on SwiftMCPServer with zero behavior change

### Phase 2: Refinement
- [ ] Improve public API ergonomics (builder pattern for server config)
- [ ] Full DocC documentation
- [ ] CI/CD pipeline

### Phase 3: Consumers
- [ ] GeoSEO MCP server as second consumer
- [ ] Validate that adding a new tool set is straightforward

### Future Considerations
- WebSocket transport option
- Tool middleware (logging, rate limiting, metrics)
- Multi-server coordination

---

**Last Updated:** 2026-03-19
