import Foundation
import MCP
import Logging

// MARK: - MCPServer

/// Main entry point for building and running MCP servers.
///
/// Use the builder pattern to configure the server:
/// ```swift
/// try await MCPServer.builder()
///     .serverName("My MCP Server")
///     .serverVersion("1.0.0")
///     .port(8080)
///     .tools(getMyTools())
///     .run()
/// ```
public enum MCPServer {

    /// Create a new builder for configuring an MCP server.
    public static func builder() -> MCPServerBuilder {
        return MCPServerBuilder()
    }

    /// Parse command-line arguments into a structured representation.
    ///
    /// Recognized flags:
    /// - `--http <port>`: Run HTTP server on specified port
    /// - `--tls-cert <path>`: TLS certificate path (PEM)
    /// - `--tls-key <path>`: TLS private key path (PEM)
    /// - `--verbose` / `-v`: Enable verbose logging
    /// - `--generate-key`: Generate a new API key
    /// - `--name <name>`: Name for generated key
    /// - `--list-keys`: List all API keys
    /// - `--revoke-key <prefix>`: Revoke a key by prefix
    /// - `--help` / `-h`: Show help
    public static func parseArguments(_ args: [String]) -> ParsedArguments {
        var parsed = ParsedArguments()

        // Check for key management / help commands first
        if args.contains("--help") || args.contains("-h") {
            parsed.command = .help
            return parsed
        }

        if args.contains("--generate-key") {
            parsed.command = .generateKey
            if let nameIndex = args.firstIndex(of: "--name"),
               nameIndex + 1 < args.count {
                parsed.keyName = args[nameIndex + 1]
            }
            return parsed
        }

        if args.contains("--list-keys") {
            parsed.command = .listKeys
            return parsed
        }

        if let revokeIndex = args.firstIndex(of: "--revoke-key"),
           revokeIndex + 1 < args.count {
            parsed.command = .revokeKey
            parsed.keyPrefix = args[revokeIndex + 1]
            return parsed
        }

        // Server mode
        parsed.command = .server

        // Transport
        if let httpIndex = args.firstIndex(of: "--http"),
           httpIndex + 1 < args.count,
           let port = UInt16(args[httpIndex + 1]) {
            parsed.transportMode = .http
            parsed.port = port
        }

        // TLS
        if let certIndex = args.firstIndex(of: "--tls-cert"),
           certIndex + 1 < args.count {
            parsed.tlsCertPath = args[certIndex + 1]
        }
        if let keyIndex = args.firstIndex(of: "--tls-key"),
           keyIndex + 1 < args.count {
            parsed.tlsKeyPath = args[keyIndex + 1]
        }

        // Verbose
        if args.contains("--verbose") || args.contains("-v") {
            parsed.verbose = true
        }

        return parsed
    }
}

// MARK: - ParsedArguments

/// Parsed command-line arguments.
public struct ParsedArguments: Sendable {
    /// The command to execute.
    public var command: ServerCommand = .server
    /// Transport mode for server command.
    public var transportMode: TransportModeOption = .stdio
    /// Port for HTTP transport.
    public var port: UInt16 = 8080
    /// TLS certificate path.
    public var tlsCertPath: String? = nil
    /// TLS private key path.
    public var tlsKeyPath: String? = nil
    /// Enable verbose logging.
    public var verbose: Bool = false
    /// Key name for --generate-key.
    public var keyName: String? = nil
    /// Key prefix for --revoke-key.
    public var keyPrefix: String? = nil
}

/// Server command parsed from CLI arguments.
public enum ServerCommand: Sendable, Equatable {
    case server
    case generateKey
    case listKeys
    case revokeKey
    case help
}

/// Transport mode for the server.
public enum TransportModeOption: Sendable, Equatable {
    case stdio
    case http
}

// MARK: - MCPServerConfiguration

/// Immutable configuration produced by the builder.
public struct MCPServerConfiguration: Sendable {
    /// Server name reported in MCP server info.
    public let serverName: String
    /// Server version reported in MCP server info.
    public let serverVersion: String
    /// Optional instructions describing server capabilities.
    public let serverInstructions: String?
    /// Port to listen on (HTTP mode).
    public let port: UInt16
    /// Path to TLS certificate chain (PEM format).
    public let tlsCertPath: String?
    /// Path to TLS private key (PEM format).
    public let tlsKeyPath: String?
    /// Enable verbose debug logging.
    public let verbose: Bool
    /// Optional API key authenticator.
    public let authenticator: APIKeyAuthenticator?
    /// Optional OAuth server.
    public let oauthServer: OAuthServer?
    /// Registered tool handlers.
    public let toolHandlers: [any MCPToolHandler]
    /// Optional resource provider.
    public let resourceProvider: (any MCPResourceProvider)?
    /// Optional prompt provider.
    public let promptProvider: (any MCPPromptProvider)?
}

// MARK: - MCPServerBuilder

/// Builder for constructing an MCPServerConfiguration.
///
/// All setter methods return `self` for fluent chaining:
/// ```swift
/// MCPServer.builder()
///     .serverName("My Server")
///     .serverVersion("2.0.0")
///     .port(9090)
///     .tool(MyToolHandler())
///     .run()
/// ```
public final class MCPServerBuilder: @unchecked Sendable {
    private var _serverName: String = "MCP Server"
    private var _serverVersion: String = "1.0.0"
    private var _serverInstructions: String? = nil
    private var _port: UInt16 = 8080
    private var _tlsCertPath: String? = nil
    private var _tlsKeyPath: String? = nil
    private var _verbose: Bool = false
    private var _authenticator: APIKeyAuthenticator? = nil
    private var _oauthServer: OAuthServer? = nil
    private var _toolHandlers: [any MCPToolHandler] = []
    private var _resourceProvider: (any MCPResourceProvider)? = nil
    private var _promptProvider: (any MCPPromptProvider)? = nil

    /// Set the server name.
    @discardableResult
    public func serverName(_ name: String) -> MCPServerBuilder {
        _serverName = name
        return self
    }

    /// Set the server version.
    @discardableResult
    public func serverVersion(_ version: String) -> MCPServerBuilder {
        _serverVersion = version
        return self
    }

    /// Set the server instructions (capability description).
    @discardableResult
    public func serverInstructions(_ instructions: String) -> MCPServerBuilder {
        _serverInstructions = instructions
        return self
    }

    /// Set the HTTP port.
    @discardableResult
    public func port(_ port: UInt16) -> MCPServerBuilder {
        _port = port
        return self
    }

    /// Set TLS certificate and key paths for HTTPS.
    @discardableResult
    public func tls(certPath: String, keyPath: String) -> MCPServerBuilder {
        _tlsCertPath = certPath
        _tlsKeyPath = keyPath
        return self
    }

    /// Enable or disable verbose logging.
    @discardableResult
    public func verbose(_ verbose: Bool) -> MCPServerBuilder {
        _verbose = verbose
        return self
    }

    /// Set the API key authenticator.
    @discardableResult
    public func authenticator(_ authenticator: APIKeyAuthenticator) -> MCPServerBuilder {
        _authenticator = authenticator
        return self
    }

    /// Set the OAuth server.
    @discardableResult
    public func oauthServer(_ server: OAuthServer) -> MCPServerBuilder {
        _oauthServer = server
        return self
    }

    /// Register a single tool handler.
    @discardableResult
    public func tool(_ handler: any MCPToolHandler) -> MCPServerBuilder {
        _toolHandlers.append(handler)
        return self
    }

    /// Register multiple tool handlers.
    @discardableResult
    public func tools(_ handlers: [any MCPToolHandler]) -> MCPServerBuilder {
        _toolHandlers.append(contentsOf: handlers)
        return self
    }

    /// Set the resource provider.
    @discardableResult
    public func resourceProvider(_ provider: any MCPResourceProvider) -> MCPServerBuilder {
        _resourceProvider = provider
        return self
    }

    /// Set the prompt provider.
    @discardableResult
    public func promptProvider(_ provider: any MCPPromptProvider) -> MCPServerBuilder {
        _promptProvider = provider
        return self
    }

    /// Build an immutable configuration from the current builder state.
    public func buildConfiguration() -> MCPServerConfiguration {
        return MCPServerConfiguration(
            serverName: _serverName,
            serverVersion: _serverVersion,
            serverInstructions: _serverInstructions,
            port: _port,
            tlsCertPath: _tlsCertPath,
            tlsKeyPath: _tlsKeyPath,
            verbose: _verbose,
            authenticator: _authenticator,
            oauthServer: _oauthServer,
            toolHandlers: _toolHandlers,
            resourceProvider: _resourceProvider,
            promptProvider: _promptProvider
        )
    }

    /// Build the configuration and run the server.
    ///
    /// This method:
    /// 1. Parses CLI arguments (overriding builder values where flags are present)
    /// 2. Handles key management commands (--generate-key, --list-keys, --revoke-key)
    /// 3. Registers tools with the MCP server
    /// 4. Starts the appropriate transport (stdio or HTTP)
    /// 5. Waits until the server completes
    public func run() async throws {
        let config = buildConfiguration()
        let args = MCPServer.parseArguments(CommandLine.arguments)

        // Handle non-server commands
        switch args.command {
        case .help:
            MCPServer.printHelp(serverName: config.serverName)
            return
        case .generateKey:
            try await MCPServer.handleGenerateKey(name: args.keyName)
            return
        case .listKeys:
            await MCPServer.handleListKeys()
            return
        case .revokeKey:
            if let prefix = args.keyPrefix {
                try await MCPServer.handleRevokeKey(prefix: prefix)
            }
            return
        case .server:
            break
        }

        // Merge CLI args with builder config (CLI wins)
        let port = args.transportMode == .http ? args.port : config.port
        let tlsCertPath = args.tlsCertPath ?? config.tlsCertPath
        let tlsKeyPath = args.tlsKeyPath ?? config.tlsKeyPath
        let verbose = args.verbose || config.verbose

        // Set up logging
        if verbose {
            LoggingSystem.bootstrap { label in
                var handler = StreamLogHandler.standardError(label: label)
                handler.logLevel = .debug
                return handler
            }
        }

        // Create tool registry and register tools
        let toolRegistry = ToolDefinitionRegistry()
        for handler in config.toolHandlers {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        let registeredTools = await toolRegistry.listTools()
        let toolCount = registeredTools.count
        MCPServer.writeStderr("Registered \(toolCount) tools\n")

        // Create MCP server
        let server = Server(
            name: config.serverName,
            version: config.serverVersion,
            instructions: config.serverInstructions,
            capabilities: Server.Capabilities(
                logging: Server.Capabilities.Logging(),
                prompts: Server.Capabilities.Prompts(listChanged: false),
                resources: Server.Capabilities.Resources(subscribe: false, listChanged: false),
                tools: Server.Capabilities.Tools(listChanged: false)
            )
        )

        // Register tool handlers
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = await toolRegistry.listTools()
            return ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { request in
            return try await toolRegistry.executeTool(
                name: request.name,
                arguments: request.arguments
            )
        }

        // Register resource handlers if provider is set
        if let resourceProvider = config.resourceProvider {
            await server.withMethodHandler(ListResources.self) { _ in
                let resources = await resourceProvider.listResources()
                return ListResources.Result(resources: resources)
            }

            await server.withMethodHandler(ReadResource.self) { request in
                return try await resourceProvider.readResource(uri: request.uri)
            }
        }

        // Register prompt handlers if provider is set
        if let promptProvider = config.promptProvider {
            await server.withMethodHandler(ListPrompts.self) { _ in
                let prompts = await promptProvider.listPrompts()
                return ListPrompts.Result(prompts: prompts)
            }

            await server.withMethodHandler(GetPrompt.self) { request in
                let stringArgs = request.arguments?.compactMapValues { value -> String? in
                    value.stringValue
                }
                return await promptProvider.getPrompt(name: request.name, arguments: stringArgs)
            }
        }

        // Start transport
        if args.transportMode == .http {
            let scheme = tlsCertPath != nil ? "HTTPS" : "HTTP"
            MCPServer.writeStderr("Starting \(config.serverName) with \(scheme) transport on port \(port)\n")

            let httpTransport = HTTPServerTransport(
                port: port,
                authenticator: config.authenticator,
                oauthServer: config.oauthServer,
                tlsCertPath: tlsCertPath,
                tlsKeyPath: tlsKeyPath
            )
            try await server.start(transport: httpTransport)
        } else {
            MCPServer.writeStderr("Starting \(config.serverName) with stdio transport\n")
            try await server.start(transport: StdioTransport())
        }

        MCPServer.writeStderr("Server started successfully\n")
        await server.waitUntilCompleted()
    }

    // MARK: - Key Management

    /// Handle --generate-key command
    static func handleGenerateKey(name: String?) async throws {
        // Delegate to MCPServer
        try await MCPServer.handleGenerateKey(name: name)
    }
}

// MARK: - MCPServer Static Helpers

extension MCPServer {

    /// Thread-safe stderr writer
    static func writeStderr(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }

    /// Handle --generate-key
    static func handleGenerateKey(name: String?) async throws {
        let keyName = name ?? "API Key \(Date().formatted(.dateTime))"
        let store = APIKeyStore()
        let key = try await store.generateKey(name: keyName)
        writeStderr("""
        Generated API key for "\(keyName)":

          \(key.key)

        Save this key securely - it cannot be retrieved later.

        """)
    }

    /// Handle --list-keys
    static func handleListKeys() async {
        let store = APIKeyStore()
        let summaries = await store.listKeySummaries()

        if summaries.isEmpty {
            writeStderr("No API keys found.\n")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        writeStderr("API Keys:\n")
        for summary in summaries {
            let lastUsed = summary.lastUsed.map { dateFormatter.string(from: $0) } ?? "never"
            writeStderr("  \(summary.prefix)  \(summary.name)  (last used: \(lastUsed))\n")
        }
    }

    /// Handle --revoke-key
    static func handleRevokeKey(prefix: String) async throws {
        let store = APIKeyStore()
        let revoked = try await store.revokeKey(prefix: prefix)
        if revoked {
            writeStderr("Key revoked successfully.\n")
        } else {
            writeStderr("No key found with prefix: \(prefix)\n")
        }
    }

    /// Print help text
    static func printHelp(serverName: String) {
        writeStderr("""
        \(serverName)

        USAGE:
          <binary> [OPTIONS]

        SERVER OPTIONS:
          --http <port>           Run HTTP server on specified port
          --tls-cert <path>       Path to TLS certificate chain (PEM format)
          --tls-key <path>        Path to TLS private key (PEM format)
          --verbose, -v           Enable verbose debug logging
          (default)               Run stdio server

        KEY MANAGEMENT:
          --generate-key          Generate a new API key
            --name <name>         Optional name for the key
          --list-keys             List all API keys
          --revoke-key <prefix>   Revoke a key by its prefix

        ENVIRONMENT:
          LOG_LEVEL               Set log level (trace, debug, info, warning, error)
          MCP_OAUTH_ENABLED       Set to "true" to enable OAuth 2.0
          MCP_OAUTH_ISSUER        OAuth issuer URL (default: http://localhost:<port>)
          MCP_API_KEYS            Comma-separated API keys (legacy)
          MCP_AUTH_REQUIRED       Set to "false" to disable authentication

        """)
    }
}
