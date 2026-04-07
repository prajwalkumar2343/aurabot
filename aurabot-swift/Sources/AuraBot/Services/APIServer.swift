import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat

actor APIServer {
    private let port: Int
    private let enhancerService: EnhancerService
    private var channel: Channel?
    
    init(port: Int, enhancerService: EnhancerService) {
        self.port = port
        self.enhancerService = enhancerService
    }
    
    func start() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(HTTPHandler(enhancerService: self.enhancerService))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        channel = try await bootstrap.bind(host: "localhost", port: port).get()
        print("API Server started on port \(port)")
    }
    
    func stop() async throws {
        try await channel?.close()
        channel = nil
    }
}

final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let enhancerService: EnhancerService
    
    // Allowed origins for CORS
    private let allowedOrigins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:7345",
        "chrome-extension://",
    ]
    
    init(enhancerService: EnhancerService) {
        self.enhancerService = enhancerService
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            handleRequest(context: context, request: request)
        case .body, .end:
            break
        }
    }
    
    private func isAllowedOrigin(_ origin: String) -> Bool {
        if origin.isEmpty {
            return true // Same-origin request
        }
        for allowed in allowedOrigins {
            if allowed.hasSuffix("://") && origin.hasPrefix(allowed) {
                return true // Prefix match for chrome-extension://
            }
            if origin == allowed {
                return true
            }
        }
        return false
    }
    
    private func handleRequest(context: ChannelHandlerContext, request: HTTPRequestHead) {
        // Get origin from request headers
        let origin = request.headers["Origin"].first ?? ""
        let corsOrigin = isAllowedOrigin(origin) ? (origin.isEmpty ? "http://localhost:3000" : origin) : nil
        
        var response = HTTPResponseHead(version: request.version, status: .ok)
        response.headers.add(name: "Content-Type", value: "application/json")
        
        // Only set CORS headers for allowed origins
        if let allowedOrigin = corsOrigin {
            response.headers.add(name: "Access-Control-Allow-Origin", value: allowedOrigin)
            response.headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
            response.headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type, Authorization")
            response.headers.add(name: "Access-Control-Allow-Credentials", value: "true")
        }
        
        let body: String
        
        switch (request.method, request.uri) {
        case (.GET, "/health"):
            body = "{\"status\":\"ok\",\"service\":\"aurabot-swift\"}"
            
        case (.POST, "/api/enhance"):
            body = handleEnhance()
            
        case (.GET, "/api/memories/search"):
            body = handleSearch(query: request.uri)
            
        default:
            response.status = .notFound
            body = "{\"error\":\"Not found\"}"
        }
        
        context.write(self.wrapOutboundOut(.head(response)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil)), promise: nil)
        context.flush()
    }
    
    private func handleEnhance() -> String {
        // In a real implementation, parse the request body
        return """
        {
            "original_prompt": "test",
            "enhanced_prompt": "test enhanced",
            "memories_used": [],
            "memory_count": 0,
            "enhancement_type": "minimal"
        }
        """
    }
    
    private func handleSearch(query: String) -> String {
        return "{\"query\":\"\(query)\",\"memories\":[],\"count\":0}"
    }
}
