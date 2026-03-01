import Foundation
import Logging
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1

// MARK: - Lookin MCP Server

/// Lookin MCP Server - 提供 MCP 协议接口供 Claude 等 AI 工具调用
public actor LookinMCPServer {
    
    /// 服务器配置
    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var endpoint: String
        
        public init(
            host: String = "127.0.0.1",
            port: Int = 47199,
            endpoint: String = "/mcp"
        ) {
            self.host = host
            self.port = port
            self.endpoint = endpoint
        }
    }
    
    private let configuration: Configuration
    private let dataSource: any LookinMCPDataSource
    private var channel: Channel?
    private var transport: StatelessHTTPServerTransport?
    private var server: Server?
    
    public nonisolated let logger: Logger
    
    // MARK: - Init
    
    public init(
        dataSource: any LookinMCPDataSource,
        configuration: Configuration = Configuration(),
        logger: Logger? = nil
    ) {
        self.dataSource = dataSource
        self.configuration = configuration
        self.logger = logger ?? Logger(label: "lookin.mcp.server")
    }
    
    // MARK: - Lifecycle
    
    /// 启动服务器
    public func start() async throws {
        // 创建 Transport
        transport = StatelessHTTPServerTransport(
            logger: logger
        )
        
        guard let transport = transport else {
            throw LookinMCPError.serverNotInitialized
        }
        
        // 创建 MCP Server
        server = Server(
            name: "lookin-mcp-server",
            version: "1.0.0",
            capabilities: Server.Capabilities(
                tools: .init(listChanged: false)
            )
        )
        
        guard let server = server else {
            throw LookinMCPError.serverNotInitialized
        }
        
        // 注册 Tools
        await LookinMCPToolHandler.registerTools(on: server, dataSource: dataSource)
        
        // 启动 MCP Server
        try await server.start(transport: transport)
        
        // 启动 HTTP Server
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(LookinHTTPHandler(server: self))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        logger.info(
            "Starting Lookin MCP Server",
            metadata: [
                "host": "\(configuration.host)",
                "port": "\(configuration.port)",
                "endpoint": "\(configuration.endpoint)"
            ]
        )
        
        let channel = try await bootstrap.bind(host: configuration.host, port: configuration.port).get()
        self.channel = channel
        
        logger.info("Lookin MCP Server started on http://\(configuration.host):\(configuration.port)\(configuration.endpoint)")
        
        // 等待 channel 关闭 (这会阻塞直到 stop() 被调用)
        try await channel.closeFuture.get()
    }
    
    /// 停止服务器
    public func stop() async {
        try? await channel?.close()
        channel = nil
        await transport?.disconnect()
        transport = nil
        server = nil
        logger.info("Lookin MCP Server stopped")
    }
    
    // MARK: - HTTP Request Handling
    
    var endpoint: String { configuration.endpoint }
    
    func handleHTTPRequest(_ request: HTTPRequest) async -> HTTPResponse {
        guard let transport = transport else {
            return .error(statusCode: 500, .internalError("Server not initialized"))
        }
        return await transport.handleRequest(request)
    }
}

// MARK: - Errors

public enum LookinMCPError: Error, LocalizedError {
    case serverNotInitialized
    case invalidRequest(String)
    
    public var errorDescription: String? {
        switch self {
        case .serverNotInitialized:
            return "MCP Server not initialized"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        }
    }
}

// MARK: - NIO HTTP Handler

/// NIO HTTP 处理器 - 将 NIO 请求转换为 MCP HTTPRequest
private final class LookinHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let server: LookinMCPServer
    
    private struct RequestState {
        var head: HTTPRequestHead
        var bodyBuffer: ByteBuffer
    }
    
    private var requestState: RequestState?
    
    init(server: LookinMCPServer) {
        self.server = server
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        
        switch part {
        case .head(let head):
            requestState = RequestState(
                head: head,
                bodyBuffer: context.channel.allocator.buffer(capacity: 0)
            )
        case .body(var buffer):
            requestState?.bodyBuffer.writeBuffer(&buffer)
        case .end:
            guard let state = requestState else { return }
            requestState = nil
            
            nonisolated(unsafe) let ctx = context
            Task { @MainActor in
                await self.handleRequest(state: state, context: ctx)
            }
        }
    }
    
    private func handleRequest(state: RequestState, context: ChannelHandlerContext) async {
        let head = state.head
        let path = head.uri.split(separator: "?").first.map(String.init) ?? head.uri
        let endpoint = await server.endpoint
        
        // 检查路径
        guard path == endpoint else {
            await writeResponse(
                .error(statusCode: 404, .invalidRequest("Not Found")),
                version: head.version,
                context: context
            )
            return
        }
        
        // 转换请求
        let httpRequest = makeHTTPRequest(from: state)
        
        // 委托给 MCP Transport 处理
        let response = await server.handleHTTPRequest(httpRequest)
        
        // 写回响应
        await writeResponse(response, version: head.version, context: context)
    }
    
    private func makeHTTPRequest(from state: RequestState) -> HTTPRequest {
        var headers: [String: String] = [:]
        for (name, value) in state.head.headers {
            if let existing = headers[name] {
                headers[name] = existing + ", " + value
            } else {
                headers[name] = value
            }
        }
        
        let body: Data?
        if state.bodyBuffer.readableBytes > 0,
           let bytes = state.bodyBuffer.getBytes(at: 0, length: state.bodyBuffer.readableBytes) {
            body = Data(bytes)
        } else {
            body = nil
        }
        
        return HTTPRequest(
            method: state.head.method.rawValue,
            headers: headers,
            body: body
        )
    }
    
    private func writeResponse(
        _ response: HTTPResponse,
        version: HTTPVersion,
        context: ChannelHandlerContext
    ) async {
        nonisolated(unsafe) let ctx = context
        let eventLoop = ctx.eventLoop
        let statusCode = response.statusCode
        let headers = response.headers
        let bodyData = response.bodyData
        
        eventLoop.execute {
            var head = HTTPResponseHead(
                version: version,
                status: HTTPResponseStatus(statusCode: statusCode)
            )
            for (name, value) in headers {
                head.headers.add(name: name, value: value)
            }
            
            ctx.write(self.wrapOutboundOut(.head(head)), promise: nil)
            
            if let body = bodyData {
                var buffer = ctx.channel.allocator.buffer(capacity: body.count)
                buffer.writeBytes(body)
                ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            }
            
            ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }
    }
}
