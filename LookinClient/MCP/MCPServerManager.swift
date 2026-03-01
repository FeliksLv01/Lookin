import Foundation
import LookinMCP

/// MCP Server 管理器 - 提供 @objc 接口供 Obj-C 代码调用
@objc(MCPServerManager)
@MainActor
final class MCPServerManager: NSObject {
    
    @objc static let shared = MCPServerManager()
    
    private var server: LookinMCPServer?
    private let dataProvider = LookinMCPDataProvider()
    
    private override init() {
        super.init()
    }
    
    /// 启动 MCP Server
    @objc func start() {
        guard server == nil else {
            NSLog("[MCP] Server already running")
            return
        }
        
        Task { @MainActor in
            do {
                let configuration = LookinMCPServer.Configuration(
                    host: "127.0.0.1",
                    port: 47199,
                    endpoint: "/mcp"
                )
                let mcpServer = LookinMCPServer(
                    dataSource: dataProvider,
                    configuration: configuration
                )
                self.server = mcpServer
                try await mcpServer.start()
                NSLog("[MCP] Server started on http://127.0.0.1:47199/mcp")
            } catch {
                NSLog("[MCP] Failed to start server: %@", error.localizedDescription)
            }
        }
    }
    
    /// 停止 MCP Server
    @objc func stop() {
        guard let server = server else {
            return
        }
        
        Task { @MainActor in
            await server.stop()
            self.server = nil
            NSLog("[MCP] Server stopped")
        }
    }
    
    /// 检查服务器是否正在运行
    @objc var isRunning: Bool {
        server != nil
    }
}
