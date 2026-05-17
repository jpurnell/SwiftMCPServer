# Changelog

## [Unreleased]

## [1.1.1] - 2026-05-17

### Fixed
- Quality gate compliance: strict concurrency justifications, doc coverage, test assertions
- Hex formatting for SHA-256 hashes and channel IDs
- Path traversal prevention using URL-based directory creation
- Task closure isolation in actor contexts

### Added
- MCP Streamable HTTP transport (spec 2025-03-26)
- OAuth 2.0 authorization server with PKCE support
- RFC 9728 protected resource metadata
- API key authentication
- SQLite-based OAuth token storage
- SSE session management with heartbeat
- TLS/HTTPS support via SwiftNIO SSL
- Privacy-annotated logging via LogPrivacy extension
- Injectable RandomNumberGenerator for deterministic testing

## [1.1.0]

### Added
- Initial MCP server implementation
- HTTP and stdio transports
- Tool registration and execution
