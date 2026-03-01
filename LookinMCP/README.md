# LookinMCP

MCP (Model Context Protocol) Server for iOS View Debugging using Lookin.

This server allows LLMs (like Claude) to inspect iOS app UI hierarchy - both from exported `.lookin` files and in **real-time** from the running Lookin macOS app.

## Features

### Static Analysis (from .lookin files)
- Load and parse `.lookin` files exported from Lookin
- Browse view hierarchy tree
- Search views by class name, memory address, or text content
- Get detailed view attributes (frame, constraints, colors, etc.)
- Analyze layout issues (ambiguous layout, conflicting constraints)
- Extract screenshots
- List all ViewControllers

### Real-time Inspection (from running Lookin app)
- Query live view hierarchy from connected iOS app
- Search views in real-time
- Get live screenshots
- No need to export files - inspect directly!

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LookinMCP Server                            │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────┐    ┌────────────────┐ │
│  │   MCP Layer     │    │  LookinBridge    │    │  LookinShared  │ │
│  │  (JSON-RPC)     │◄──►│  (Swift Wrapper) │◄──►│  (Objective-C) │ │
│  │                 │    │                  │    │                │ │
│  │ - stdio I/O     │    │ - File Parsing   │    │ - Data Models  │ │
│  │ - tools/list    │    │ - HTTP Client    │    │ - NSCoding     │ │
│  │ - tools/call    │    │ - Search/Filter  │    │ - Attributes   │ │
│  └─────────────────┘    └──────────────────┘    └────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
           │                         │
           │ JSON-RPC (stdio)        │ HTTP (port 47199)
           ▼                         ▼
      ┌─────────┐              ┌─────────────┐
      │   LLM   │              │   Lookin    │
      │ (Claude)│              │  macOS App  │
      └─────────┘              └─────────────┘
```

## Available Tools

### Static Tools (from .lookin files)

| Tool | Description |
|------|-------------|
| `load_lookin_file` | Load a .lookin file (must be called first for static analysis) |
| `get_app_info` | Get app information (name, bundle ID, device, OS) |
| `get_hierarchy` | Get the view hierarchy tree |
| `get_view_details` | Get detailed attributes of a specific view |
| `search_views` | Search views by class name, address, or text |
| `get_screenshot` | Get screenshot of a view (base64 PNG) |
| `list_view_controllers` | List all ViewControllers in the hierarchy |
| `analyze_layout_issues` | Find views with ambiguous layout or constraint issues |

### Live Tools (from running Lookin app)

| Tool | Description |
|------|-------------|
| `live_status` | Check if Lookin is running and connected to an iOS app |
| `live_hierarchy` | Get real-time view hierarchy from connected app |
| `live_view_details` | Get real-time details of a specific view |
| `live_search` | Search views in real-time |
| `live_screenshot` | Get real-time screenshot of a view |
| `live_app_info` | Get info about the connected iOS app |
| `live_view_controllers` | List all ViewControllers in real-time |

## Prerequisites

### For Static Analysis (.lookin files)

1. Export a `.lookin` file from Lookin app:
   - Open Lookin and connect to your iOS app
   - File → Export (Cmd+E)
   - Save the `.lookin` file

### For Real-time Inspection

1. **Build Lookin from source** (with MCP Server support):
   ```bash
   cd /path/to/Lookin
   pod install
   xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -configuration Debug build
   ```

2. **Run the modified Lookin app** - it will start an HTTP server on port 47199

3. **Connect to an iOS app** in Lookin

### iOS App Requirements

Your iOS app must have [LookinServer](https://github.com/QMUI/LookinServer) integrated:

```ruby
# Podfile
pod 'LookinServer', :configurations => ['Debug']
```

## Building

```bash
cd LookinMCP
swift build -c release
```

The binary will be at `.build/release/lookin-mcp`

## Usage with Claude Desktop

Add to your Claude Desktop configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "lookin": {
      "command": "/Users/YOUR_USERNAME/Desktop/LookinMCP/.build/release/lookin-mcp"
    }
  }
}
```

After restarting Claude Desktop, you can use the Lookin tools.

## Example Usage

### Static Analysis (from .lookin file)

1. **Load a file first:**
   > "Load the lookin file at /path/to/MyApp.lookin"

2. **Explore the hierarchy:**
   > "Show me the view hierarchy"
   > "List all ViewControllers"

3. **Search for views:**
   > "Find all UIButton views"
   > "Search for views containing the text 'Submit'"

4. **Get details:**
   > "What are the details of view with oid 42?"

### Real-time Inspection

1. **Check connection:**
   > "Check if Lookin is connected"
   > "What's the live status?"

2. **Explore live:**
   > "Show me the live view hierarchy"
   > "Get the live app info"

3. **Search in real-time:**
   > "Search for UITableViewCell in the live app"
   > "Find all buttons in the running app"

4. **Get live details:**
   > "Get live details of view 123"
   > "Show me a live screenshot of view 456"

## Development Status

- [x] MCP Protocol Layer (JSON-RPC over stdio)
- [x] .lookin file parsing
- [x] View hierarchy navigation
- [x] View search (by class, address, text)
- [x] Attribute extraction
- [x] Screenshot extraction
- [x] Layout issue analysis
- [x] Real-time connection to Lookin (via HTTP)
- [x] Live hierarchy queries
- [x] Live view details
- [x] Live search
- [x] Live screenshots

## How .lookin Files Work

`.lookin` files are binary files created by the Lookin app using `NSKeyedArchiver`. They contain:

- `LookinHierarchyInfo`: The complete hierarchy snapshot
  - `LookinAppInfo`: App metadata (bundle ID, device info, etc.)
  - `LookinDisplayItem[]`: Tree of views with their attributes
- Screenshots for each view
- Constraint information
- Custom attribute sections

## HTTP API (for Lookin App)

When running the modified Lookin app, it exposes an HTTP server on port 47199:

| Endpoint | Description |
|----------|-------------|
| `GET /status` | Server status and connection info |
| `GET /apps` | List connected iOS apps |
| `GET /app-info` | Get current app info |
| `GET /hierarchy?flat=true` | Get view hierarchy |
| `GET /view/:oid` | Get view details |
| `GET /screenshot/:oid` | Get view screenshot |
| `GET /search?q=...&type=class` | Search views |
| `GET /viewcontrollers` | List all ViewControllers |

## License

MIT
