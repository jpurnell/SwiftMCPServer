import Testing
@testable import SwiftMCPServer

@Suite("SwiftMCPServer Smoke Tests")
struct SwiftMCPServerSmokeTests {

    @Test("Package imports successfully")
    func packageImports() {
        // Verify the module can be imported and key types exist
        let registry = ToolDefinitionRegistry()
        #expect(registry != nil)
    }
}
