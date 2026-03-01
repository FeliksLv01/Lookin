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

// MARK: - Attribute Value Types

/// 颜色值
public struct LookinColorValue: Sendable, Encodable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    public let hex: String
    
    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)
        self.hex = String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

/// 矩形值
public struct LookinRectValue: Sendable, Encodable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// 点值
public struct LookinPointValue: Sendable, Encodable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 尺寸值
public struct LookinSizeValue: Sendable, Encodable {
    public let width: Double
    public let height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// 边距值
public struct LookinInsetsValue: Sendable, Encodable {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double
    
    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

/// 阴影值
public struct LookinShadowValue: Sendable, Encodable {
    public let color: LookinColorValue?
    public let opacity: Double
    public let radius: Double
    public let offsetWidth: Double
    public let offsetHeight: Double
    
    public init(color: LookinColorValue?, opacity: Double, radius: Double, offsetWidth: Double, offsetHeight: Double) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.offsetWidth = offsetWidth
        self.offsetHeight = offsetHeight
    }
}

/// 仿射变换值
public struct LookinAffineTransformValue: Sendable, Encodable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public let tx: Double
    public let ty: Double
    
    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }
}

// MARK: - Attribute Value (Enum with Associated Values)

/// 属性值 (支持多种类型)
public enum LookinAttributeValue: Sendable, Encodable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case color(LookinColorValue)
    case rect(LookinRectValue)
    case point(LookinPointValue)
    case size(LookinSizeValue)
    case insets(LookinInsetsValue)
    case shadow(LookinShadowValue)
    case affineTransform(LookinAffineTransformValue)
    case constraints([LookinConstraintInfo])
    case json(String)
    case null
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .color(let value):
            try container.encode(value)
        case .rect(let value):
            try container.encode(value)
        case .point(let value):
            try container.encode(value)
        case .size(let value):
            try container.encode(value)
        case .insets(let value):
            try container.encode(value)
        case .shadow(let value):
            try container.encode(value)
        case .affineTransform(let value):
            try container.encode(value)
        case .constraints(let value):
            try container.encode(value)
        case .json(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Attribute Info

/// 单个属性信息
public struct LookinAttributeInfo: Sendable, Encodable {
    public let identifier: String
    public let displayTitle: String?
    public let type: String          // "bool", "int", "double", "string", "color", "rect", "insets", "enum", etc.
    public let value: LookinAttributeValue
    public let enumCases: [String]?  // 枚举的所有可选值
    
    public init(identifier: String, displayTitle: String?, type: String, value: LookinAttributeValue, enumCases: [String]? = nil) {
        self.identifier = identifier
        self.displayTitle = displayTitle
        self.type = type
        self.value = value
        self.enumCases = enumCases
    }
}

/// 属性节
public struct LookinAttributeSectionInfo: Sendable, Encodable {
    public let identifier: String
    public let attributes: [LookinAttributeInfo]
    
    public init(identifier: String, attributes: [LookinAttributeInfo]) {
        self.identifier = identifier
        self.attributes = attributes
    }
}

/// 属性组
public struct LookinAttributeGroupInfo: Sendable, Encodable {
    public let identifier: String
    public let title: String?        // 用户自定义组的标题
    public let isUserCustom: Bool
    public let sections: [LookinAttributeSectionInfo]
    
    public init(identifier: String, title: String?, isUserCustom: Bool, sections: [LookinAttributeSectionInfo]) {
        self.identifier = identifier
        self.title = title
        self.isUserCustom = isUserCustom
        self.sections = sections
    }
}

// MARK: - AutoLayout Constraint

/// 约束项信息
public struct LookinConstraintItemInfo: Sendable, Encodable {
    public let type: String          // "view", "self", "super", "layoutGuide", "nil", "unknown"
    public let className: String?
    public let oid: UInt?
    public let memoryAddress: String?
    
    public init(type: String, className: String?, oid: UInt?, memoryAddress: String?) {
        self.type = type
        self.className = className
        self.oid = oid
        self.memoryAddress = memoryAddress
    }
}

/// 约束信息
public struct LookinConstraintInfo: Sendable, Encodable {
    public let isActive: Bool
    public let isEffective: Bool
    public let shouldBeArchived: Bool
    public let identifier: String?
    public let firstItem: LookinConstraintItemInfo?
    public let firstAttribute: String       // "left", "right", "top", "bottom", "width", "height", etc.
    public let relation: String             // "==", ">=", "<="
    public let secondItem: LookinConstraintItemInfo?
    public let secondAttribute: String?
    public let multiplier: Double
    public let constant: Double
    public let priority: Double
    
    public init(
        isActive: Bool,
        isEffective: Bool,
        shouldBeArchived: Bool,
        identifier: String?,
        firstItem: LookinConstraintItemInfo?,
        firstAttribute: String,
        relation: String,
        secondItem: LookinConstraintItemInfo?,
        secondAttribute: String?,
        multiplier: Double,
        constant: Double,
        priority: Double
    ) {
        self.isActive = isActive
        self.isEffective = isEffective
        self.shouldBeArchived = shouldBeArchived
        self.identifier = identifier
        self.firstItem = firstItem
        self.firstAttribute = firstAttribute
        self.relation = relation
        self.secondItem = secondItem
        self.secondAttribute = secondAttribute
        self.multiplier = multiplier
        self.constant = constant
        self.priority = priority
    }
}

// MARK: - Event Handler

/// 事件处理器类型
public enum LookinEventHandlerTypeValue: String, Sendable, Encodable {
    case targetAction = "target_action"
    case gesture = "gesture"
}

/// Target-Action 信息
public struct LookinTargetActionInfo: Sendable, Encodable {
    public let target: String        // 如 "<WRHomeView: 0xff>"
    public let action: String        // 如 "handleTap"
    
    public init(target: String, action: String) {
        self.target = target
        self.action = action
    }
}

/// 事件处理器信息
public struct LookinEventHandlerInfo: Sendable, Encodable {
    public let type: LookinEventHandlerTypeValue
    public let eventName: String     // 如 "UIControlEventTouchUpInside", "UITapGestureRecognizer"
    public let targetActions: [LookinTargetActionInfo]
    // Gesture specific
    public let inheritedRecognizerName: String?
    public let isEnabled: Bool?
    public let delegate: String?
    public let recognizerOid: UInt?
    public let ivarTraces: [String]?
    
    public init(
        type: LookinEventHandlerTypeValue,
        eventName: String,
        targetActions: [LookinTargetActionInfo],
        inheritedRecognizerName: String? = nil,
        isEnabled: Bool? = nil,
        delegate: String? = nil,
        recognizerOid: UInt? = nil,
        ivarTraces: [String]? = nil
    ) {
        self.type = type
        self.eventName = eventName
        self.targetActions = targetActions
        self.inheritedRecognizerName = inheritedRecognizerName
        self.isEnabled = isEnabled
        self.delegate = delegate
        self.recognizerOid = recognizerOid
        self.ivarTraces = ivarTraces
    }
}

// MARK: - View Attributes Result

/// 视图属性返回结果
public struct LookinViewAttributesResult: Sendable, Encodable {
    public let oid: UInt
    public let className: String
    public let memoryAddress: String?
    public let attributeGroups: [LookinAttributeGroupInfo]      // 标准属性组
    public let customAttributeGroups: [LookinAttributeGroupInfo] // 自定义属性组
    public let eventHandlers: [LookinEventHandlerInfo]
    
    public init(
        oid: UInt,
        className: String,
        memoryAddress: String?,
        attributeGroups: [LookinAttributeGroupInfo],
        customAttributeGroups: [LookinAttributeGroupInfo],
        eventHandlers: [LookinEventHandlerInfo]
    ) {
        self.oid = oid
        self.className = className
        self.memoryAddress = memoryAddress
        self.attributeGroups = attributeGroups
        self.customAttributeGroups = customAttributeGroups
        self.eventHandlers = eventHandlers
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
    
    /// 获取指定视图的完整属性信息（包括属性组、事件处理器、AutoLayout约束等）
    func getViewAttributes(oid: UInt) async -> LookinViewAttributesResult?
}
