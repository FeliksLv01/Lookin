import Foundation
import AppKit
import LookinMCP

// Type aliases to avoid ambiguity between LookinMCP and LookinShared (Obj-C)
typealias MCPAppInfo = LookinMCP.LookinAppInfo
typealias ObjCAppInfo = LookinShared.LookinAppInfo

// MCP types for attributes
typealias MCPViewAttributesResult = LookinMCP.LookinViewAttributesResult
typealias MCPAttributeGroupInfo = LookinMCP.LookinAttributeGroupInfo
typealias MCPAttributeSectionInfo = LookinMCP.LookinAttributeSectionInfo
typealias MCPAttributeInfo = LookinMCP.LookinAttributeInfo
typealias MCPAttributeValue = LookinMCP.LookinAttributeValue
typealias MCPColorValue = LookinMCP.LookinColorValue
typealias MCPRectValue = LookinMCP.LookinRectValue
typealias MCPPointValue = LookinMCP.LookinPointValue
typealias MCPSizeValue = LookinMCP.LookinSizeValue
typealias MCPInsetsValue = LookinMCP.LookinInsetsValue
typealias MCPShadowValue = LookinMCP.LookinShadowValue
typealias MCPAffineTransformValue = LookinMCP.LookinAffineTransformValue
typealias MCPConstraintInfo = LookinMCP.LookinConstraintInfo
typealias MCPConstraintItemInfo = LookinMCP.LookinConstraintItemInfo
typealias MCPEventHandlerInfo = LookinMCP.LookinEventHandlerInfo
typealias MCPEventHandlerTypeValue = LookinMCP.LookinEventHandlerTypeValue
typealias MCPTargetActionInfo = LookinMCP.LookinTargetActionInfo

/// Lookin MCP 数据提供者 - 桥接 Obj-C 数据源
@MainActor
final class LookinMCPDataProvider: LookinMCPDataSource, @unchecked Sendable {
    
    // MARK: - Data Sources
    
    private var dataSource: LKStaticHierarchyDataSource {
        LKStaticHierarchyDataSource.sharedInstance()
    }
    
    private var appsManager: LKAppsManager {
        LKAppsManager.sharedInstance()
    }
    
    // MARK: - LookinMCPDataSource Implementation
    
    func getStatus() async -> LookinServerStatus {
        let app = appsManager.inspectingApp
        let items = dataSource.flatItems ?? []
        
        return LookinServerStatus(
            connected: app != nil,
            hasHierarchy: items.count > 0,
            appName: app?.appInfo?.appName,
            bundleId: app?.appInfo?.appBundleIdentifier
        )
    }
    
    func listApps() async -> [MCPAppInfo] {
        guard let app = appsManager.inspectingApp,
              let appInfo = app.appInfo else {
            return []
        }
        
        return [
            MCPAppInfo(
                name: appInfo.appName ?? "Unknown",
                bundleId: appInfo.appBundleIdentifier ?? "",
                deviceName: appInfo.deviceDescription ?? "",
                osVersion: appInfo.osDescription ?? "",
                screenWidth: Double(appInfo.screenWidth),
                screenHeight: Double(appInfo.screenHeight),
                screenScale: Double(appInfo.screenScale)
            )
        ]
    }
    
    func getHierarchy(flat: Bool, maxDepth: Int?) async -> LookinHierarchyResult {
        let items = dataSource.flatItems ?? []
        
        let views = items.map { item in
            convertToViewInfo(item)
        }
        
        return LookinHierarchyResult(views: views, total: views.count)
    }
    
    func getView(oid: UInt) async -> LookinViewInfo? {
        guard let item = dataSource.displayItem(withOid: UInt(oid)) else {
            return nil
        }
        return convertToViewInfo(item)
    }
    
    func getScreenshot(oid: UInt) async -> LookinScreenshotData? {
        guard let item = dataSource.displayItem(withOid: UInt(oid)) else {
            return nil
        }
        
        let screenshot = item.soloScreenshot ?? item.groupScreenshot
        guard let image = screenshot else {
            return nil
        }
        
        guard let pngData = pngData(from: image) else {
            return nil
        }
        
        let base64 = pngData.base64EncodedString()
        
        return LookinScreenshotData(
            oid: oid,
            format: "png",
            encoding: "base64",
            data: base64
        )
    }
    
    func searchViews(query: String, type: LookinSearchType) async -> [LookinViewInfo] {
        let items = dataSource.flatItems ?? []
        var results: [LookinViewInfo] = []
        
        for item in items {
            var match = false
            
            switch type {
            case .className:
                let title = item.title()
                match = title.localizedCaseInsensitiveContains(query)
            case .text:
                let subtitle = item.subtitle()
                match = subtitle.localizedCaseInsensitiveContains(query)
            case .oid:
                if let oidValue = UInt(query) {
                    match = item.layerObject?.oid == oidValue
                }
            }
            
            if match {
                results.append(convertToViewInfo(item))
            }
        }
        
        return results
    }
    
    func listViewControllers() async -> [LookinViewControllerInfo] {
        let items = dataSource.flatItems ?? []
        var vcs: [LookinViewControllerInfo] = []
        var seenAddresses: Set<String> = []
        
        for item in items {
            if let vcObject = item.hostViewControllerObject {
                let address = String(format: "0x%lx", vcObject.oid)
                
                // 避免重复
                if seenAddresses.contains(address) {
                    continue
                }
                seenAddresses.insert(address)
                
                let className = vcObject.classChainList?.first as? String ?? "Unknown"
                let viewOid = item.layerObject?.oid
                
                vcs.append(LookinViewControllerInfo(
                    className: className,
                    address: address,
                    viewOid: viewOid != nil ? UInt(viewOid!) : nil
                ))
            }
        }
        
        return vcs
    }
    
    func getAppInfo() async -> MCPAppInfo? {
        guard let appInfo = dataSource.appInfo else {
            return nil
        }
        
        return MCPAppInfo(
            name: appInfo.appName ?? "Unknown",
            bundleId: appInfo.appBundleIdentifier ?? "",
            deviceName: appInfo.deviceDescription ?? "",
            osVersion: appInfo.osDescription ?? "",
            screenWidth: Double(appInfo.screenWidth),
            screenHeight: Double(appInfo.screenHeight),
            screenScale: Double(appInfo.screenScale)
        )
    }
    
    func reloadHierarchy() async -> LookinReloadResult {
        guard let app = appsManager.inspectingApp else {
            return LookinReloadResult(
                success: false,
                message: "No app connected. Please connect to an app in Lookin first.",
                viewCount: nil
            )
        }
        
        // 使用异步方式获取层级数据
        return await withCheckedContinuation { continuation in
            app.fetchHierarchyData().subscribeNext({ [weak self] info in
                guard let self = self, let hierarchyInfo = info as? LookinHierarchyInfo else {
                    continuation.resume(returning: LookinReloadResult(
                        success: false,
                        message: "Failed to fetch hierarchy data",
                        viewCount: nil
                    ))
                    return
                }
                
                // 在主线程更新数据源
                DispatchQueue.main.async {
                    self.dataSource.reload(with: hierarchyInfo, keepState: true)
                    let count = self.dataSource.flatItems?.count ?? 0
                    
                    continuation.resume(returning: LookinReloadResult(
                        success: true,
                        message: "Hierarchy reloaded successfully",
                        viewCount: count
                    ))
                }
            }, error: { error in
                let message = error?.localizedDescription ?? "Unknown error"
                continuation.resume(returning: LookinReloadResult(
                    success: false,
                    message: message,
                    viewCount: nil
                ))
            })
        }
    }
    
    func getViewAttributes(oid: UInt) async -> MCPViewAttributesResult? {
        guard let item = dataSource.displayItem(withOid: UInt(oid)) else {
            return nil
        }
        
        // 转换标准属性组
        let attrGroups = convertAttributeGroups(item.attributesGroupList)
        
        // 转换自定义属性组
        let customGroups = convertAttributeGroups(item.customAttrGroupList)
        
        // 转换事件处理器
        let handlers = convertEventHandlers(item.eventHandlers)
        
        // 获取内存地址
        let address = item.viewObject?.memoryAddress ?? item.layerObject?.memoryAddress
        
        return MCPViewAttributesResult(
            oid: oid,
            className: item.title(),
            memoryAddress: address,
            attributeGroups: attrGroups,
            customAttributeGroups: customGroups,
            eventHandlers: handlers
        )
    }
    
    // MARK: - Private Helpers
    
    private func convertToViewInfo(_ item: LookinDisplayItem) -> LookinViewInfo {
        let oid = item.layerObject?.oid ?? 0
        let className = item.title()
        let text: String? = item.subtitle()
        
        let frame = item.frame
        let bounds = item.bounds
        
        let classChain = (item.layerObject?.classChainList as? [String]) ?? []
        
        let parentOid: UInt? = item.`super`?.layerObject?.oid != nil 
            ? UInt(truncatingIfNeeded: item.`super`!.layerObject!.oid) 
            : nil
        
        let childOids: [UInt] = (item.subitems)?.compactMap { child in
            child.layerObject?.oid != nil ? UInt(truncatingIfNeeded: child.layerObject!.oid) : nil
        } ?? []
        
        let vcClassName = item.hostViewControllerObject?.classChainList?.first as? String
        
        return LookinViewInfo(
            oid: UInt(truncatingIfNeeded: oid),
            className: className,
            text: text,
            frameX: Double(frame.origin.x),
            frameY: Double(frame.origin.y),
            frameWidth: Double(frame.size.width),
            frameHeight: Double(frame.size.height),
            boundsX: Double(bounds.origin.x),
            boundsY: Double(bounds.origin.y),
            boundsWidth: Double(bounds.size.width),
            boundsHeight: Double(bounds.size.height),
            isHidden: item.isHidden,
            alpha: Double(item.alpha),
            viewController: vcClassName,
            depth: item.indentLevel(),
            hasChildren: (item.subitems?.count ?? 0) > 0,
            childCount: item.subitems?.count ?? 0,
            classChain: classChain,
            parentOid: parentOid,
            childOids: childOids
        )
    }
    
    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    // MARK: - Attribute Conversion
    
    private func convertAttributeGroups(_ groups: [LookinAttributesGroup]?) -> [MCPAttributeGroupInfo] {
        guard let groups = groups else { return [] }
        
        return groups.compactMap { group -> MCPAttributeGroupInfo? in
            let sections = convertAttributeSections(group.attrSections)
            guard !sections.isEmpty else { return nil }
            
            return MCPAttributeGroupInfo(
                identifier: group.identifier ?? "unknown",
                title: group.userCustomTitle,
                isUserCustom: group.isUserCustom(),
                sections: sections
            )
        }
    }
    
    private func convertAttributeSections(_ sections: [LookinAttributesSection]?) -> [MCPAttributeSectionInfo] {
        guard let sections = sections else { return [] }
        
        return sections.compactMap { section -> MCPAttributeSectionInfo? in
            let attributes = convertAttributes(section.attributes)
            guard !attributes.isEmpty else { return nil }
            
            return MCPAttributeSectionInfo(
                identifier: section.identifier ?? "unknown",
                attributes: attributes
            )
        }
    }
    
    private func convertAttributes(_ attributes: [LookinAttribute]?) -> [MCPAttributeInfo] {
        guard let attributes = attributes else { return [] }
        
        return attributes.compactMap { attr -> MCPAttributeInfo? in
            let (value, typeName, enumCases) = convertAttributeValue(attr)
            
            return MCPAttributeInfo(
                identifier: attr.identifier ?? "unknown",
                displayTitle: attr.displayTitle,
                type: typeName,
                value: value,
                enumCases: enumCases
            )
        }
    }
    
    private func convertAttributeValue(_ attr: LookinAttribute) -> (MCPAttributeValue, String, [String]?) {
        let attrType = attr.attrType
        let value = attr.value
        
        switch attrType {
        case .none, .void:
            return (.null, "void", nil)
            
        case .char:
            if let charValue = value as? Int8 {
                return (.int(Int(charValue)), "char", nil)
            }
            return (.null, "char", nil)
            
        case .int:
            if let intValue = value as? Int32 {
                return (.int(Int(intValue)), "int", nil)
            } else if let intValue = value as? Int {
                return (.int(intValue), "int", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "int", nil)
            }
            return (.null, "int", nil)
            
        case .short:
            if let shortValue = value as? Int16 {
                return (.int(Int(shortValue)), "short", nil)
            }
            return (.null, "short", nil)
            
        case .long:
            if let longValue = value as? Int {
                return (.int(longValue), "long", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "long", nil)
            }
            return (.null, "long", nil)
            
        case .longLong:
            if let longValue = value as? Int64 {
                return (.int(Int(longValue)), "longlong", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "longlong", nil)
            }
            return (.null, "longlong", nil)
            
        case .unsignedChar:
            if let ucharValue = value as? UInt8 {
                return (.int(Int(ucharValue)), "uchar", nil)
            }
            return (.null, "uchar", nil)
            
        case .unsignedInt:
            if let uintValue = value as? UInt32 {
                return (.int(Int(uintValue)), "uint", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "uint", nil)
            }
            return (.null, "uint", nil)
            
        case .unsignedShort:
            if let ushortValue = value as? UInt16 {
                return (.int(Int(ushortValue)), "ushort", nil)
            }
            return (.null, "ushort", nil)
            
        case .unsignedLong:
            if let ulongValue = value as? UInt {
                return (.int(Int(ulongValue)), "ulong", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "ulong", nil)
            }
            return (.null, "ulong", nil)
            
        case .unsignedLongLong:
            if let ulongValue = value as? UInt64 {
                return (.int(Int(ulongValue)), "ulonglong", nil)
            } else if let numValue = value as? NSNumber {
                return (.int(numValue.intValue), "ulonglong", nil)
            }
            return (.null, "ulonglong", nil)
            
        case .float:
            if let floatValue = value as? Float {
                return (.double(Double(floatValue)), "float", nil)
            } else if let numValue = value as? NSNumber {
                return (.double(numValue.doubleValue), "float", nil)
            }
            return (.null, "float", nil)
            
        case .double:
            if let doubleValue = value as? Double {
                return (.double(doubleValue), "double", nil)
            } else if let numValue = value as? NSNumber {
                return (.double(numValue.doubleValue), "double", nil)
            }
            return (.null, "double", nil)
            
        case .BOOL:
            if let boolValue = value as? Bool {
                return (.bool(boolValue), "bool", nil)
            } else if let numValue = value as? NSNumber {
                return (.bool(numValue.boolValue), "bool", nil)
            }
            return (.null, "bool", nil)
            
        case .sel:
            if let selString = value as? String {
                return (.string(selString), "selector", nil)
            }
            return (.null, "selector", nil)
            
        case .class:
            if let classString = value as? String {
                return (.string(classString), "class", nil)
            }
            return (.null, "class", nil)
            
        case .cgPoint:
            if let pointArray = value as? [NSNumber], pointArray.count >= 2 {
                let point = MCPPointValue(
                    x: pointArray[0].doubleValue,
                    y: pointArray[1].doubleValue
                )
                return (.point(point), "point", nil)
            }
            return (.null, "point", nil)
            
        case .cgVector:
            if let vectorArray = value as? [NSNumber], vectorArray.count >= 2 {
                let point = MCPPointValue(
                    x: vectorArray[0].doubleValue,
                    y: vectorArray[1].doubleValue
                )
                return (.point(point), "vector", nil)
            }
            return (.null, "vector", nil)
            
        case .cgSize:
            if let sizeArray = value as? [NSNumber], sizeArray.count >= 2 {
                let size = MCPSizeValue(
                    width: sizeArray[0].doubleValue,
                    height: sizeArray[1].doubleValue
                )
                return (.size(size), "size", nil)
            }
            return (.null, "size", nil)
            
        case .cgRect:
            if let rectArray = value as? [NSNumber], rectArray.count >= 4 {
                let rect = MCPRectValue(
                    x: rectArray[0].doubleValue,
                    y: rectArray[1].doubleValue,
                    width: rectArray[2].doubleValue,
                    height: rectArray[3].doubleValue
                )
                return (.rect(rect), "rect", nil)
            }
            return (.null, "rect", nil)
            
        case .cgAffineTransform:
            if let transformArray = value as? [NSNumber], transformArray.count >= 6 {
                let transform = MCPAffineTransformValue(
                    a: transformArray[0].doubleValue,
                    b: transformArray[1].doubleValue,
                    c: transformArray[2].doubleValue,
                    d: transformArray[3].doubleValue,
                    tx: transformArray[4].doubleValue,
                    ty: transformArray[5].doubleValue
                )
                return (.affineTransform(transform), "affineTransform", nil)
            }
            return (.null, "affineTransform", nil)
            
        case .uiEdgeInsets:
            if let insetsArray = value as? [NSNumber], insetsArray.count >= 4 {
                let insets = MCPInsetsValue(
                    top: insetsArray[0].doubleValue,
                    left: insetsArray[1].doubleValue,
                    bottom: insetsArray[2].doubleValue,
                    right: insetsArray[3].doubleValue
                )
                return (.insets(insets), "insets", nil)
            }
            return (.null, "insets", nil)
            
        case .uiOffset:
            if let offsetArray = value as? [NSNumber], offsetArray.count >= 2 {
                let point = MCPPointValue(
                    x: offsetArray[0].doubleValue,
                    y: offsetArray[1].doubleValue
                )
                return (.point(point), "offset", nil)
            }
            return (.null, "offset", nil)
            
        case .nsString:
            if let stringValue = value as? String {
                return (.string(stringValue), "string", nil)
            }
            return (.null, "string", nil)
            
        case .enumInt:
            let enumCases = extractEnumCases(attr.extraValue)
            if let intValue = value as? Int {
                // 如果有 enumCases，尝试获取对应的字符串
                if let cases = enumCases, intValue >= 0, intValue < cases.count {
                    return (.string(cases[intValue]), "enum", enumCases)
                }
                return (.int(intValue), "enum", enumCases)
            } else if let numValue = value as? NSNumber {
                let intVal = numValue.intValue
                if let cases = enumCases, intVal >= 0, intVal < cases.count {
                    return (.string(cases[intVal]), "enum", enumCases)
                }
                return (.int(intVal), "enum", enumCases)
            }
            return (.null, "enum", enumCases)
            
        case .enumLong:
            let enumCases = extractEnumCases(attr.extraValue)
            if let intValue = value as? Int {
                if let cases = enumCases, intValue >= 0, intValue < cases.count {
                    return (.string(cases[intValue]), "enum", enumCases)
                }
                return (.int(intValue), "enum", enumCases)
            } else if let numValue = value as? NSNumber {
                let intVal = numValue.intValue
                if let cases = enumCases, intVal >= 0, intVal < cases.count {
                    return (.string(cases[intVal]), "enum", enumCases)
                }
                return (.int(intVal), "enum", enumCases)
            }
            return (.null, "enum", enumCases)
            
        case .uiColor:
            // UIColor value is RGBA array: @[NSNumber, NSNumber, NSNumber, NSNumber]
            if let colorArray = value as? [NSNumber], colorArray.count >= 4 {
                let color = MCPColorValue(
                    red: colorArray[0].doubleValue,
                    green: colorArray[1].doubleValue,
                    blue: colorArray[2].doubleValue,
                    alpha: colorArray[3].doubleValue
                )
                return (.color(color), "color", nil)
            }
            return (.null, "color", nil)
            
        case .customObj:
            // 检查是否是约束数组
            if let constraints = value as? [LookinAutoLayoutConstraint] {
                let constraintInfos = convertConstraints(constraints)
                return (.constraints(constraintInfos), "constraints", nil)
            }
            // 其他自定义对象转为字符串描述
            if let obj = value {
                return (.string(String(describing: obj)), "custom", nil)
            }
            return (.null, "custom", nil)
            
        case .enumString:
            let enumCases = extractEnumCases(attr.extraValue)
            if let stringValue = value as? String {
                return (.string(stringValue), "enum", enumCases)
            }
            return (.null, "enum", enumCases)
            
        case .shadow:
            // Shadow is a complex type
            if let shadowDict = value as? [String: Any] {
                let colorArray = shadowDict["color"] as? [NSNumber]
                let color: MCPColorValue? = colorArray.map { arr in
                    MCPColorValue(
                        red: arr.count > 0 ? arr[0].doubleValue : 0,
                        green: arr.count > 1 ? arr[1].doubleValue : 0,
                        blue: arr.count > 2 ? arr[2].doubleValue : 0,
                        alpha: arr.count > 3 ? arr[3].doubleValue : 1
                    )
                }
                let shadow = MCPShadowValue(
                    color: color,
                    opacity: (shadowDict["opacity"] as? NSNumber)?.doubleValue ?? 0,
                    radius: (shadowDict["radius"] as? NSNumber)?.doubleValue ?? 0,
                    offsetWidth: (shadowDict["offsetW"] as? NSNumber)?.doubleValue ?? 0,
                    offsetHeight: (shadowDict["offsetH"] as? NSNumber)?.doubleValue ?? 0
                )
                return (.shadow(shadow), "shadow", nil)
            }
            return (.null, "shadow", nil)
            
        case .json:
            if let jsonString = value as? String {
                return (.json(jsonString), "json", nil)
            } else if let jsonData = value {
                return (.json(String(describing: jsonData)), "json", nil)
            }
            return (.null, "json", nil)
            
        @unknown default:
            if let obj = value {
                return (.string(String(describing: obj)), "unknown", nil)
            }
            return (.null, "unknown", nil)
        }
    }
    
    private func extractEnumCases(_ extraValue: Any?) -> [String]? {
        if let cases = extraValue as? [String] {
            return cases
        }
        return nil
    }
    
    // MARK: - Constraint Conversion
    
    private func convertConstraints(_ constraints: [LookinAutoLayoutConstraint]) -> [MCPConstraintInfo] {
        return constraints.map { constraint in
            MCPConstraintInfo(
                isActive: constraint.active,
                isEffective: constraint.effective,
                shouldBeArchived: constraint.shouldBeArchived,
                identifier: constraint.identifier,
                firstItem: convertConstraintItem(constraint.firstItem, type: constraint.firstItemType),
                firstAttribute: layoutAttributeName(constraint.firstAttribute),
                relation: layoutRelationName(constraint.relation),
                secondItem: convertConstraintItem(constraint.secondItem, type: constraint.secondItemType),
                secondAttribute: constraint.secondAttribute != 0 ? layoutAttributeName(constraint.secondAttribute) : nil,
                multiplier: Double(constraint.multiplier),
                constant: Double(constraint.constant),
                priority: Double(constraint.priority)
            )
        }
    }
    
    private func convertConstraintItem(_ item: LookinObject?, type: LookinConstraintItemType) -> MCPConstraintItemInfo? {
        let typeName: String
        switch type {
        case .unknown:
            typeName = "unknown"
        case .nil:
            return nil
        case .view:
            typeName = "view"
        case .`self`:
            typeName = "self"
        case .super:
            typeName = "super"
        case .layoutGuide:
            typeName = "layoutGuide"
        @unknown default:
            typeName = "unknown"
        }
        
        return MCPConstraintItemInfo(
            type: typeName,
            className: item?.classChainList?.first as? String,
            oid: item?.oid,
            memoryAddress: item?.memoryAddress
        )
    }
    
    private func layoutAttributeName(_ attribute: Int) -> String {
        // iOS NSLayoutAttribute values
        switch attribute {
        case 0: return "notAnAttribute"
        case 1: return "left"
        case 2: return "right"
        case 3: return "top"
        case 4: return "bottom"
        case 5: return "leading"
        case 6: return "trailing"
        case 7: return "width"
        case 8: return "height"
        case 9: return "centerX"
        case 10: return "centerY"
        case 11: return "lastBaseline"
        case 12: return "firstBaseline"
        case 13: return "leftMargin"
        case 14: return "rightMargin"
        case 15: return "topMargin"
        case 16: return "bottomMargin"
        case 17: return "leadingMargin"
        case 18: return "trailingMargin"
        case 19: return "centerXWithinMargins"
        case 20: return "centerYWithinMargins"
        default: return "attribute(\(attribute))"
        }
    }
    
    private func layoutRelationName(_ relation: NSLayoutConstraint.Relation) -> String {
        switch relation {
        case .lessThanOrEqual: return "<="
        case .equal: return "=="
        case .greaterThanOrEqual: return ">="
        @unknown default: return "?"
        }
    }
    
    // MARK: - Event Handler Conversion
    
    private func convertEventHandlers(_ handlers: [LookinEventHandler]?) -> [MCPEventHandlerInfo] {
        guard let handlers = handlers else { return [] }
        
        return handlers.map { handler in
            let handlerType: MCPEventHandlerTypeValue
            switch handler.handlerType {
            case .targetAction:
                handlerType = .targetAction
            case .gesture:
                handlerType = .gesture
            @unknown default:
                handlerType = .targetAction
            }
            
            let targetActions: [MCPTargetActionInfo] = (handler.targetActions)?.map { tuple in
                MCPTargetActionInfo(
                    target: tuple.first ?? "",
                    action: tuple.second ?? ""
                )
            } ?? []
            
            return MCPEventHandlerInfo(
                type: handlerType,
                eventName: handler.eventName ?? "",
                targetActions: targetActions,
                inheritedRecognizerName: handler.inheritedRecognizerName,
                isEnabled: handler.handlerType == .gesture ? handler.gestureRecognizerIsEnabled : nil,
                delegate: handler.gestureRecognizerDelegator,
                recognizerOid: handler.handlerType == .gesture ? UInt(handler.recognizerOid) : nil,
                ivarTraces: handler.recognizerIvarTraces
            )
        }
    }
}
