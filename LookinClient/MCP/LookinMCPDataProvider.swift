import Foundation
import AppKit
import LookinMCP

// Type aliases to avoid ambiguity between LookinMCP and LookinShared (Obj-C)
typealias MCPAppInfo = LookinMCP.LookinAppInfo
typealias ObjCAppInfo = LookinShared.LookinAppInfo

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
        
        let childOids: [UInt] = (item.subitems as? [LookinDisplayItem])?.compactMap { child in
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
}
