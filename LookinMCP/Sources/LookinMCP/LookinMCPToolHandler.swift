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
                description: "Get the current hierarchy snapshot. Oids are snapshot-scoped: after reload_hierarchy, resolve a view again by class/text/frame or use find_similar_views.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "flat": ["type": "boolean", "description": "If true, returns a flat array of views. If false (default), returns tree structure."],
                        "maxDepth": ["type": "integer", "description": "Maximum depth to traverse in the hierarchy. Omit for unlimited depth."],
                        "rootOid": ["type": "integer", "description": "Optional oid to use as the root of the returned subtree."],
                        "classFilter": ["type": "string", "description": "Optional case-insensitive class-name filter."],
                        "textFilter": ["type": "string", "description": "Optional case-insensitive text filter. Covers visible summary text and loaded text attributes."],
                        "limit": ["type": "integer", "description": "Optional maximum number of returned views for large flat results."],
                        "compact": ["type": "boolean", "description": "If true, returns only oid, class, text, frame, depth, parentOid, and childOids."]
                    ]
                ])
            ),
            Tool(
                name: "get_subtree",
                description: "Get a subtree rooted at a specific current-snapshot oid. Useful for focused exploration such as container -> renderedView -> children.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "oid": ["type": "integer", "description": "The current-snapshot oid of the subtree root"],
                        "maxDepth": ["type": "integer", "description": "Maximum depth under the root. Defaults to unlimited."],
                        "compact": ["type": "boolean", "description": "If true, returns only oid, class, text, frame, depth, parentOid, and childOids."]
                    ],
                    "required": ["oid"]
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
                description: "Search for views by class name, text content, or object ID. Text search covers UILabel text, attributed text strings, button titles, accessibility labels, and loaded string attributes when available.",
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
                description: "Reload the view hierarchy from the connected iOS app. Existing oids may become invalid because oid values are only valid within one hierarchy snapshot.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "find_similar_views",
                description: "Find likely current-snapshot matches for a view oid from the previous snapshot using class, frame, parent, and approximate position.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "oid": ["type": "integer", "description": "The oid to resolve. Usually an oid from before reload_hierarchy."],
                        "limit": ["type": "integer", "description": "Maximum candidate count. Defaults to 5."]
                    ],
                    "required": ["oid"]
                ])
            ),
            Tool(
                name: "diagnose_layout",
                description: "Aggregate common layout anomalies such as visible nonempty text with zero size, visible views with zero frames, and children outside parent bounds.",
                inputSchema: .object(["type": "object", "properties": [:]])
            ),
            Tool(
                name: "get_view_attributes",
                description: "Get detailed attributes of a view by oid, including all property groups (Layout, AutoLayout, UILabel, UIScrollView, etc.), event handlers (gestures, target-actions), and AutoLayout constraints. Use this to inspect specific properties like text, font, textColor, cornerRadius, backgroundColor, constraints, etc.",
                inputSchema: .object([
                    "type": "object",
                    "properties": [
                        "oid": ["type": "integer", "description": "The unique object ID of the view to get attributes for"]
                    ],
                    "required": ["oid"]
                ])
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
            let rootOid = params.arguments?["rootOid"]?.intValue.map(UInt.init)
            let classFilter = params.arguments?["classFilter"]?.stringValue
            let textFilter = params.arguments?["textFilter"]?.stringValue
            let limit = params.arguments?["limit"]?.intValue
            let result = await dataSource.getHierarchy(flat: flat, maxDepth: maxDepth, rootOid: rootOid, classFilter: classFilter, textFilter: textFilter, limit: limit)
            if params.arguments?["compact"]?.boolValue == true,
               let json = compactHierarchyJSON(result) {
                return .init(content: [.text(json)], isError: false)
            }
            return .init(content: [.text(result.toJSON())], isError: false)
            
        case "get_subtree":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let oid = UInt(oidValue)
            let maxDepth = params.arguments?["maxDepth"]?.intValue
            if let result = await dataSource.getSubtree(oid: oid, maxDepth: maxDepth) {
                if params.arguments?["compact"]?.boolValue == true,
                   let json = compactHierarchyJSON(result) {
                    return .init(content: [.text(json)], isError: false)
                }
                return .init(content: [.text(result.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: View not found with oid \(oid). Oids are only valid within the current hierarchy snapshot; after reload_hierarchy, use search_views or find_similar_views.")], isError: true)
            }
            
        case "get_view":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let oid = UInt(oidValue)
            if let view = await dataSource.getView(oid: oid) {
                return .init(content: [.text(view.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: View not found with oid \(oid). Oids are only valid within the current hierarchy snapshot; after reload_hierarchy, use search_views or find_similar_views.")], isError: true)
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
                        "text": jsonValue(view.text),
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
                        "viewOid": jsonValue(vc.viewOid)
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
            
        case "find_similar_views":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let limit = params.arguments?["limit"]?.intValue ?? 5
            let results = await dataSource.findSimilarViews(oid: UInt(oidValue), limit: limit)
            let resultJSON: [String: Any] = [
                "results": results.map { view in
                    [
                        "oid": view.oid,
                        "class": view.className,
                        "text": jsonValue(view.text),
                        "frame": [
                            "x": view.frameX,
                            "y": view.frameY,
                            "width": view.frameWidth,
                            "height": view.frameHeight
                        ],
                        "depth": view.depth,
                        "parentOid": jsonValue(view.parentOid)
                    ]
                },
                "count": results.count,
                "queryOid": oidValue,
                "note": "Candidates are heuristic matches. Confirm with get_view or get_view_attributes before acting."
            ]
            if let data = try? JSONSerialization.data(withJSONObject: resultJSON, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                return .init(content: [.text(json)], isError: false)
            }
            return .init(content: [.text(results.toJSON())], isError: false)
            
        case "diagnose_layout":
            let result = await dataSource.diagnoseLayout()
            return .init(content: [.text(result.toJSON())], isError: false)
            
        case "get_view_attributes":
            guard let oidValue = params.arguments?["oid"]?.intValue else {
                return .init(content: [.text("Error: Missing required parameter 'oid'")], isError: true)
            }
            let oid = UInt(oidValue)
            if let attributes = await dataSource.getViewAttributes(oid: oid) {
                return .init(content: [.text(attributes.toJSON())], isError: false)
            } else {
                return .init(content: [.text("Error: View not found with oid \(oid). Oids are only valid within the current hierarchy snapshot; after reload_hierarchy, use search_views or find_similar_views.")], isError: true)
            }
            
        default:
            return .init(content: [.text("Error: Unknown tool '\(params.name)'")], isError: true)
        }
    }
    
    private static func compactHierarchyJSON(_ result: LookinHierarchyResult) -> String? {
        let resultJSON: [String: Any] = [
            "views": result.views.map { view in
                [
                    "oid": view.oid,
                    "class": view.className,
                    "text": jsonValue(view.text),
                    "frame": [
                        "x": view.frameX,
                        "y": view.frameY,
                        "width": view.frameWidth,
                        "height": view.frameHeight
                    ],
                    "depth": view.depth,
                    "parentOid": jsonValue(view.parentOid),
                    "childOids": view.childOids
                ]
            },
            "total": result.total,
            "returned": result.returned,
            "note": jsonValue(result.note)
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: resultJSON, options: .prettyPrinted) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private static func jsonValue<T>(_ value: T?) -> Any {
        value.map { $0 as Any } ?? NSNull()
    }
}
