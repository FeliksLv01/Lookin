import Foundation

// MARK: - Search Type

/// 搜索类型
public enum LookinSearchType: String, Sendable {
    case className = "class"
    case text = "text"
    case oid = "oid"
}

// MARK: - Server Status

/// 服务器状态
public struct LookinServerStatus: Sendable, Encodable {
    public let connected: Bool
    public let hasHierarchy: Bool
    public let appName: String?
    public let bundleId: String?
    
    public init(connected: Bool, hasHierarchy: Bool, appName: String?, bundleId: String?) {
        self.connected = connected
        self.hasHierarchy = hasHierarchy
        self.appName = appName
        self.bundleId = bundleId
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - App Info

/// 应用信息
public struct LookinAppInfo: Sendable, Encodable {
    public let name: String
    public let bundleId: String
    public let deviceName: String
    public let osVersion: String
    public let screenWidth: Double
    public let screenHeight: Double
    public let screenScale: Double
    
    public init(
        name: String,
        bundleId: String,
        deviceName: String,
        osVersion: String,
        screenWidth: Double,
        screenHeight: Double,
        screenScale: Double
    ) {
        self.name = name
        self.bundleId = bundleId
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.screenScale = screenScale
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - View Info

/// 视图信息
public struct LookinViewInfo: Sendable, Encodable {
    public let oid: UInt
    public let className: String
    public let text: String?
    public let frameX: Double
    public let frameY: Double
    public let frameWidth: Double
    public let frameHeight: Double
    public let boundsX: Double
    public let boundsY: Double
    public let boundsWidth: Double
    public let boundsHeight: Double
    public let isHidden: Bool
    public let alpha: Double
    public let viewController: String?
    public let depth: Int
    public let hasChildren: Bool
    public let childCount: Int
    public let classChain: [String]
    public let parentOid: UInt?
    public let childOids: [UInt]
    
    public init(
        oid: UInt,
        className: String,
        text: String?,
        frameX: Double,
        frameY: Double,
        frameWidth: Double,
        frameHeight: Double,
        boundsX: Double,
        boundsY: Double,
        boundsWidth: Double,
        boundsHeight: Double,
        isHidden: Bool,
        alpha: Double,
        viewController: String?,
        depth: Int,
        hasChildren: Bool,
        childCount: Int,
        classChain: [String],
        parentOid: UInt?,
        childOids: [UInt]
    ) {
        self.oid = oid
        self.className = className
        self.text = text
        self.frameX = frameX
        self.frameY = frameY
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.boundsX = boundsX
        self.boundsY = boundsY
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.isHidden = isHidden
        self.alpha = alpha
        self.viewController = viewController
        self.depth = depth
        self.hasChildren = hasChildren
        self.childCount = childCount
        self.classChain = classChain
        self.parentOid = parentOid
        self.childOids = childOids
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - View Node (for tree structure)

/// 视图节点 (树形结构)
public struct LookinViewNode: Sendable, Encodable {
    public let info: LookinViewInfo
    public let children: [LookinViewNode]
    
    public init(info: LookinViewInfo, children: [LookinViewNode]) {
        self.info = info
        self.children = children
    }
}

// MARK: - Hierarchy Result

/// 层级结果
public struct LookinHierarchyResult: Sendable, Encodable {
    public let views: [LookinViewInfo]
    public let total: Int
    
    public init(views: [LookinViewInfo], total: Int) {
        self.views = views
        self.total = total
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Screenshot Data

/// 截图数据
public struct LookinScreenshotData: Sendable, Encodable {
    public let oid: UInt
    public let format: String
    public let encoding: String
    public let data: String
    
    public init(oid: UInt, format: String = "png", encoding: String = "base64", data: String) {
        self.oid = oid
        self.format = format
        self.encoding = encoding
        self.data = data
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - ViewController Info

/// ViewController 信息
public struct LookinViewControllerInfo: Sendable, Encodable {
    public let className: String
    public let address: String
    public let viewOid: UInt?
    
    public init(className: String, address: String, viewOid: UInt?) {
        self.className = className
        self.address = address
        self.viewOid = viewOid
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Reload Result

/// 重载结果
public struct LookinReloadResult: Sendable, Encodable {
    public let success: Bool
    public let message: String
    public let viewCount: Int?
    
    public init(success: Bool, message: String, viewCount: Int?) {
        self.success = success
        self.message = message
        self.viewCount = viewCount
    }
    
    public func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - JSON Helpers for Arrays

public extension Array where Element == LookinAppInfo {
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

public extension Array where Element == LookinViewInfo {
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

public extension Array where Element == LookinViewControllerInfo {
    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Data Source Protocol

/// 数据源协议 - 主应用需要实现
/// 使用 @MainActor 确保在主线程访问 UI 数据
@MainActor
public protocol LookinMCPDataSource: AnyObject, Sendable {
    /// 获取服务器状态
    func getStatus() async -> LookinServerStatus
    
    /// 列出连接的应用
    func listApps() async -> [LookinAppInfo]
    
    /// 获取视图层级
    func getHierarchy(flat: Bool, maxDepth: Int?) async -> LookinHierarchyResult
    
    /// 获取指定视图的详细信息
    func getView(oid: UInt) async -> LookinViewInfo?
    
    /// 获取指定视图的截图
    func getScreenshot(oid: UInt) async -> LookinScreenshotData?
    
    /// 搜索视图
    func searchViews(query: String, type: LookinSearchType) async -> [LookinViewInfo]
    
    /// 列出所有 ViewController
    func listViewControllers() async -> [LookinViewControllerInfo]
    
    /// 获取应用详细信息
    func getAppInfo() async -> LookinAppInfo?
    
    /// 重新加载视图层级
    func reloadHierarchy() async -> LookinReloadResult
}
