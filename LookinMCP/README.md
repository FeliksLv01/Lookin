# LookinMCP

MCP (Model Context Protocol) Server for iOS View Debugging, built into the Lookin macOS app.

LookinMCP 以 HTTP 服务的形式内嵌在 Lookin macOS 应用中，让 Claude、opencode 等 AI 工具能够实时检查 iOS 应用的视图层级。

## 架构

```
┌─────────────────────────────────────────────┐
│              Lookin macOS App               │
│                                             │
│  ┌──────────────┐    ┌───────────────────┐  │
│  │  LookinMCP   │    │   Lookin Core     │  │
│  │  HTTP Server │◄──►│  (DataSource)     │  │
│  │  :47199/mcp  │    │                   │  │
│  └──────────────┘    └───────────────────┘  │
└─────────────────────────────────────────────┘
         │ MCP Streamable HTTP (SSE)
         ▼
┌─────────────────┐
│   AI Tool       │
│ (Claude/opencode│
│  /Cursor etc.)  │
└─────────────────┘
         │ LookinServer protocol
         ▼
┌─────────────────┐
│   iOS App       │
│ (LookinServer)  │
└─────────────────┘
```

## 前置条件

1. **运行 Lookin macOS 应用**（需从源码构建，已集成 LookinMCP）
2. **iOS 应用集成 LookinServer**：

```ruby
# Podfile
pod 'LookinServer', :configurations => ['Debug']
```

3. **在模拟器或真机上运行 iOS 应用**，并在 Lookin 中连接到它

Lookin 启动后会自动在 `http://127.0.0.1:47199/mcp` 上启动 MCP 服务。

## 配置 AI 工具

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "lookin": {
      "type": "http",
      "url": "http://127.0.0.1:47199/mcp"
    }
  }
}
```

### opencode / Cursor 等

配置 remote MCP server，URL 填 `http://127.0.0.1:47199/mcp`。

## 可用工具

| 工具 | 说明 | 参数 |
|------|------|------|
| `get_status` | 检查 MCP 服务器状态及 iOS 应用连接情况 | 无 |
| `get_app_info` | 获取应用名、Bundle ID、设备、系统版本、屏幕尺寸 | 无 |
| `list_apps` | 列出所有已连接的 iOS 应用 | 无 |
| `get_hierarchy` | 获取完整视图树 | `flat`（bool）、`maxDepth`（int） |
| `reload_hierarchy` | 从应用刷新视图层级数据 | 无 |
| `get_view` | 通过 oid 获取视图详细信息 | `oid`（int，必填） |
| `get_view_attributes` | 获取视图全部属性（布局、AutoLayout、手势、约束等） | `oid`（int，必填） |
| `search_views` | 按类名、文本或 oid 搜索视图 | `query`（string，必填）、`type`（"class"/"text"/"oid"） |
| `get_screenshot` | 获取指定视图的 base64 PNG 截图 | `oid`（int，必填） |
| `list_viewcontrollers` | 列出所有视图控制器及其类名和对应视图的 oid | 无 |

## 使用示例

```
"帮我看看当前界面的视图层级"
→ get_status → get_hierarchy

"找一下所有 UIButton"
→ search_views(query="UIButton", type="class")

"oid 42 这个视图的 frame 是多少？有没有约束冲突？"
→ get_view_attributes(oid=42)

"给我截一下 oid 100 的视图"
→ get_screenshot(oid=100)
```

## 开发

LookinMCP 是一个 Swift Package Library，集成在 Lookin Xcode 工程中。

```bash
# 仅编译 LookinMCP 包（验证代码）
cd LookinMCP
swift build

# 完整构建需在 Xcode 中 build Lookin 主工程
```

### Transport

使用 `StatefulHTTPServerTransport`，支持：
- **POST** `/mcp`：JSON-RPC 请求
- **GET** `/mcp`：建立 SSE 流（server-initiated messages）

## License

MIT
