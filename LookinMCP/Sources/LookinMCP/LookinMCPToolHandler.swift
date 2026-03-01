import Foundation
import MCP

// MARK: - Tool Handler

/// Lookin MCP Tool Handler - 注册和处理 MCP Tools
struct LookinMCPToolHandler {
    
    /// 注册所有 Tools 到 MCP Server
    static func registerTools(on server: Server, dataSource: any LookinMCPDataSource) async {
        // 注册 Tool 列表
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: allTools)
        }
        
        // 注册 Tool 调用处理
        await server.withMethodHandler(CallTool.self) { params in
            await handleToolCall(params: params, dataSource: dataSource)
        }
    }
    
    // MARK: - Tool Definitions
    
    private static var allTools: [Tool] {
        [
            Tool(
                name: "get_status",
                description: "Get Lookin server status and connection state. Returns whether an iOS app is connected and if hierarchy data is available.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "list_apps",
                description: "List all connected iOS apps with their basic information.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "get_hierarchy",
                description: "Get the complete view hierarchy of the connected iOS app. Returns all views with their properties, frames, and relationships.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "flat": ["type": "boolean", "description": "If true, returns a flat array of views. If false (default), returns tree structure."],
                        "maxDepth": ["type": "integer", "description": "Maximum depth to traverse in the hierarchy. Omit for unlimited depth."]
                    ]
                ])
            ),
            Tool(
                name: "get_view",
                description: "Get detailed information about a specific view by its object ID (oid). Returns frame, bounds, class chain, attributes, and more.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "oid": ["type": "integer", "description": "The object ID of the view to retrieve"]
                    ],
                    "required": ["oid"]
                ])
            ),
            Tool(
                name: "get_screenshot",
                description: "Get a screenshot of a specific view as base64-encoded PNG image.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "oid": ["type": "integer", "description": "The object ID of the view to screenshot"]
                    ],
                    "required": ["oid"]
                ])
            ),
            Tool(
                name: "search_views",
                description: "Search for views by class name, text content, or object ID. Returns matching views with their basic information.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "The search query string"],
                        "type": ["type": "string", "enum": ["class", "text", "oid"], "description": "Type of search: 'class' for class name, 'text' for text content, 'oid' for object ID. Defaults to 'class'."]
                    ],
                    "required": ["query"]
                ])
            ),
            Tool(
                name: "list_viewcontrollers",
                description: "List all view controllers in the app with their class names, memory addresses, and associated view object IDs.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "get_app_info",
                description: "Get detailed information about the connected iOS app including app name, bundle ID, device name, OS version, and screen dimensions.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "reload_hierarchy",
                description: "Reload the view hierarchy from the connected iOS app. Use this to refresh the data after UI changes.",
                inputSchema: .object(["type": "object", "properties": [:]])
            )
        ]
    }
    
    // MARK: - Tool Call Handler
    
    private static func handleToolCall(
        params: CallTool.Parameters,
        dataSource: any LookinMCPDataSource
    ) async -> CallTool.Result {
        switch params.name {
        case "get_status":
            let status = await dataSource.getStatus()
            return .init(content: [.text(status.toJSON())], isError: false)
            
        case "list_apps":
            let apps = await dataSource.listApps()
            return .init(content: [.text(apps.toJSON())], isError: false)
            
        case "get_hierarchy":
            let flat = params.arguments?["flat"]?.boolValue ?? false
            let maxDepth = params.arguments?["maxDepth"]?.intValue
            let result = await dataSource.getHierarchy(flat: flat, maxDepth: maxDepth)
            return .init(content: [.text(result.toJSON())], isError: false)
            
        case "get_view":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let oid = UInt(oidValue)
            if let view = await dataSource.getView(oid: oid) {
                return .init(content: [.text(view.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: View not found with oid \(oid)")], isError: true)
            }
            
        case "get_screenshot":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let oid = UInt(oidValue)
            if let screenshot = await dataSource.getScreenshot(oid: oid) {
                return .init(content: [.text(screenshot.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: Screenshot not available for oid \(oid)")], isError: true)
            }
            
        case "search_views":
            guard let query = params.arguments?["query"]?.stringValue else {
                return .init(content: [.text("Error: Missing required parameter 'query'")], isError: true)
            }
            let typeStr = params.arguments?["type"]?.stringValue ?? "class"
            let searchType = LookinSearchType(rawValue: typeStr) ?? .className
            let results = await dataSource.searchViews(query: query, type: searchType)
            
            // 构建搜索结果 JSON
            let resultJSON: [String: Any] = [
                "results": results.map { view in
                    [
                        "oid": view.oid,
                        "class": view.className,
                        "text": view.text as Any,
                        "depth": view.depth
                    ]
                },
                "count": results.count,
                "query": query,
                "type": typeStr
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: resultJSON, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                return .init(content: [.text(json)], isError: false)
            } else {
                return .init(content: [.text(results.toJSON())], isError: false)
            }
            
        case "list_viewcontrollers":
            let vcs = await dataSource.listViewControllers()
            
            // 构建 VC 列表 JSON
            let vcJSON: [String: Any] = [
                "viewControllers": vcs.map { vc in
                    [
                        "class": vc.className,
                        "address": vc.address,
                        "viewOid": vc.viewOid as Any
                    ]
                },
                "count": vcs.count
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: vcJSON, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                return .init(content: [.text(json)], isError: false)
            } else {
                return .init(content: [.text(vcs.toJSON())], isError: false)
            }
            
        case "get_app_info":
            if let info = await dataSource.getAppInfo() {
                return .init(content: [.text(info.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: No app connected. Please connect to an iOS app in Lookin first.")], isError: true)
            }
            
        case "reload_hierarchy":
            let result = await dataSource.reloadHierarchy()
            return .init(content: [.text(result.toJSON())], isError: !result.success)
            
        default:
            return .init(content: [.text("Error: Unknown tool '\(params.name)'")], isError: true)
        }
    }
}
