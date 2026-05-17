# SwiftMCPServer

A Swift implementation of the Model Context Protocol (MCP) server with HTTP transport.

## Features

- MCP Streamable HTTP transport (spec 2025-03-26)
- OAuth 2.0 authorization with PKCE (RFC 7636)
- API key authentication
- Server-Sent Events (SSE) for server-initiated messages
- TLS/HTTPS support
- Cross-platform (macOS, Linux) via SwiftNIO

## Requirements

- Swift 6.0+
- macOS 14+ or Linux

## Usage

```swift
import SwiftMCPServer

let server = MCPServer(
    name: "My Server",
    version: "1.0.0"
)

server.tool("greet") { args in
    "Hello, world!"
}

try await server.run(transport: .http(port: 8080))
```

## License

See LICENSE file for details.
