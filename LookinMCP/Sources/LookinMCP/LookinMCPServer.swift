import Foundation
import Dispatch
import Logging
import MCP
@preconcurrency import NIOCore
@preconcurrency import NIOPosix
@preconcurrency import NIOHTTP1

// MARK: - Lookin MCP Server

public actor LookinMCPServer {

    public struct Configuration: Sendable {
        public var host: String
        public var port: Int
        public var endpoint: String
        public var sessionTimeout: TimeInterval

        public init(
            host: String = "127.0.0.1",
            port: Int = 47199,
            endpoint: String = "/mcp",
            sessionTimeout: TimeInterval = 3600
        ) {
            self.host = host
            self.port = port
            self.endpoint = endpoint
            self.sessionTimeout = sessionTimeout
        }
    }

    private struct SessionContext {
        let server: Server
        let transport: StatefulHTTPServerTransport
        let createdAt: Date
        var lastAccessedAt: Date
    }

    private let configuration: Configuration
    private let dataSource: any LookinMCPDataSource
    private var channel: Channel?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var sessions: [String: SessionContext] = [:]

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

    public func start() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        eventLoopGroup = group

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

        Task { await sessionCleanupLoop() }

        logger.info("Lookin MCP Server started on http://\(configuration.host):\(configuration.port)\(configuration.endpoint)")

        try await channel.closeFuture.get()
    }

    public func stop() async {
        await closeAllSessions()
        if let channel {
            try? await channel.close()
        }
        channel = nil
        if let eventLoopGroup {
            DispatchQueue.global(qos: .utility).async {
                try? eventLoopGroup.syncShutdownGracefully()
            }
        }
        eventLoopGroup = nil
        logger.info("Lookin MCP Server stopped")
    }

    // MARK: - HTTP Request Handling

    var endpoint: String { configuration.endpoint }

    func handleHTTPRequest(_ request: HTTPRequest) async -> HTTPResponse {
        let sessionID = request.header(HTTPHeaderName.sessionID)

        // Route to existing session
        if let sessionID, var session = sessions[sessionID] {
            session.lastAccessedAt = Date()
            sessions[sessionID] = session

            let response = await session.transport.handleRequest(request)

            if request.method.uppercased() == "DELETE" && response.statusCode == 200 {
                await closeSession(sessionID)
            }

            return response
        }

        // No session — check for initialize request
        if request.method.uppercased() == "POST",
           let body = request.body,
           isInitializeRequest(body)
        {
            return await createSessionAndHandle(request)
        }

        if sessionID != nil {
            return .error(statusCode: 404, .invalidRequest("Not Found: Session not found or expired"))
        }
        return .error(statusCode: 400, .invalidRequest("Bad Request: Missing \(HTTPHeaderName.sessionID) header"))
    }

    // MARK: - Session Management

    private func isInitializeRequest(_ body: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let method = json["method"] as? String else { return false }
        return method == "initialize"
    }

    private struct FixedSessionIDGenerator: SessionIDGenerator {
        let sessionID: String
        func generateSessionID() -> String { sessionID }
    }

    private func createSessionAndHandle(_ request: HTTPRequest) async -> HTTPResponse {
        let sessionID = UUID().uuidString

        let transport = StatefulHTTPServerTransport(
            sessionIDGenerator: FixedSessionIDGenerator(sessionID: sessionID),
            logger: logger
        )

        do {
            let server = Server(
                name: "lookin-mcp-server",
                version: "1.0.0",
                capabilities: Server.Capabilities(tools: .init(listChanged: false))
            )
            await LookinMCPToolHandler.registerTools(on: server, dataSource: dataSource)
            try await server.start(transport: transport)

            sessions[sessionID] = SessionContext(
                server: server,
                transport: transport,
                createdAt: Date(),
                lastAccessedAt: Date()
            )

            let response = await transport.handleRequest(request)

            if case .error = response {
                await closeSession(sessionID)
            }

            return response
        } catch {
            await transport.disconnect()
            return .error(statusCode: 500, .internalError("Failed to create session: \(error.localizedDescription)"))
        }
    }

    private func closeSession(_ sessionID: String) async {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        await session.transport.disconnect()
        logger.info("Closed session", metadata: ["sessionID": "\(sessionID)"])
    }

    private func closeAllSessions() async {
        for sessionID in sessions.keys {
            await closeSession(sessionID)
        }
    }

    private func sessionCleanupLoop() async {
        while true {
            try? await Task.sleep(for: .seconds(60))
            let now = Date()
            let expired = sessions.filter { _, context in
                now.timeIntervalSince(context.lastAccessedAt) > configuration.sessionTimeout
            }
            for (sessionID, _) in expired {
                logger.info("Session expired", metadata: ["sessionID": "\(sessionID)"])
                await closeSession(sessionID)
            }
        }
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

        guard path == endpoint else {
            await writeResponse(
                .error(statusCode: 404, .invalidRequest("Not Found")),
                version: head.version,
                context: context
            )
            return
        }

        let httpRequest = makeHTTPRequest(from: state)
        let response = await server.handleHTTPRequest(httpRequest)
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

        let path = state.head.uri.split(separator: "?").first.map(String.init) ?? state.head.uri

        return HTTPRequest(
            method: state.head.method.rawValue,
            headers: headers,
            body: body,
            path: path
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

        if case .stream(let sseStream, _) = response {
            eventLoop.execute {
                var head = HTTPResponseHead(
                    version: version,
                    status: HTTPResponseStatus(statusCode: statusCode)
                )
                for (name, value) in headers {
                    head.headers.add(name: name, value: value)
                }
                ctx.writeAndFlush(self.wrapOutboundOut(.head(head)), promise: nil)
            }

            do {
                for try await chunk in sseStream {
                    let chunkCopy = chunk
                    eventLoop.execute {
                        var buffer = ctx.channel.allocator.buffer(capacity: chunkCopy.count)
                        buffer.writeBytes(chunkCopy)
                        ctx.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                    }
                }
            } catch {
                // stream ended or errored
            }

            eventLoop.execute {
                ctx.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        } else {
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
}
