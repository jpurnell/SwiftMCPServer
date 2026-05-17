import Foundation
import Logging
import MCP

/// A tool definition that combines metadata and execution logic
public struct ToolDefinition: Sendable {
    /// The SDK tool metadata (name, description, schema)
    public let tool: Tool
    /// The closure that executes this tool's logic
    public let execute: @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result

    /// Initialize with a Tool and execute closure
    public init(
        tool: Tool,
        execute: @escaping @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result
    ) {
        self.tool = tool
        self.execute = execute
    }

    /// Initialize with individual parameters (using Value directly)
    public init(
        name: String,
        description: String,
        inputSchema: MCP.Value,
        execute: @escaping @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result
    ) {
        self.tool = Tool(
            name: name,
            description: description,
            inputSchema: inputSchema
        )
        self.execute = execute
    }
}

/// Registry for managing tool definitions
public actor ToolDefinitionRegistry {
    private var tools: [String: ToolDefinition] = [:]

    /// Creates an empty tool registry
    public init() {}

    /// Registers a single tool definition
    public func register(_ definition: ToolDefinition) {
        tools[definition.tool.name] = definition
    }

    /// Registers multiple tool definitions
    public func register(_ definitions: [ToolDefinition]) {
        for definition in definitions {
            tools[definition.tool.name] = definition
        }
    }

    /// Returns all registered tools
    public func listTools() -> [Tool] {
        return Array(tools.values.map { $0.tool })
    }

    /// Executes a tool by name with the given arguments
    public func executeTool(name: String, arguments: [String: MCP.Value]?) async throws -> CallTool.Result {
        guard let definition = tools[name] else {
            return CallTool.Result(
                content: [.text("Tool not found: \(name)")],
                isError: true
            )
        }

        do {
            return try await definition.execute(arguments)
        } catch let error as ValueExtractionError {
            Logger(label: "tool-registry").debug("Tool extraction error: \(error.localizedDescription, privacy: .public)")
            return CallTool.Result(
                content: [.text(error.localizedDescription)],
                isError: true
            )
        } catch {
            Logger(label: "tool-registry").debug("Tool execution error: \(error.localizedDescription, privacy: .public)")
            return CallTool.Result(
                content: [.text("Execution error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}
