//
//  Server.swift
//  SwiftNIOTest
//
//  Created by Jacopo Mangiavacchi on 3/1/18.
//

import Foundation
import NIO
import NIOHTTP1
import Thrift

public protocol Processor {
  func process(on inProtocol: TProtocol, outProtocol: TProtocol) throws
}


public class Server {
    let host: String
    let port: Int
    private let group: MultiThreadedEventLoopGroup
    private let threadPool: BlockingIOThreadPool
    private let fileIO: NonBlockingFileIO
    private let processor: Processor
    private let inProtocolType: TProtocol.Type
    private let outProtocolType: TProtocol.Type

    public init(host: String, port: Int, with processor: Processor, eventLoopThreads: Int = 1, poolThreads: Int = 6, inProtocolType: TProtocol.Type, outProtocolType: TProtocol.Type) {
        self.host = host
        self.port = port
        self.processor = processor
        self.inProtocolType = inProtocolType
        self.outProtocolType = outProtocolType
        
        group = MultiThreadedEventLoopGroup(numThreads: eventLoopThreads)
        threadPool = BlockingIOThreadPool(numberOfThreads: poolThreads)
        threadPool.start()

        fileIO = NonBlockingFileIO(threadPool: threadPool)
    }
    
    
    public func run() {
        do {
            let bootstrap = ServerBootstrap(group: group)
                // Specify backlog and enable SO_REUSEADDR for the server itself
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                
                // Set the handlers that are applied to the accepted Channels
                .childChannelInitializer { channel in
                    channel.pipeline.addHTTPServerHandlers().then {
                        channel.pipeline.add(handler: Handler(fileIO: self.fileIO, processor: self.processor, inProtocolType: self.inProtocolType, outProtocolType: self.outProtocolType))
                    }
                }
                
                // Enable TCP_NODELAY and SO_REUSEADDR for the accepted Channels
                .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

            let channel = try bootstrap.bind(host: host, port: port).wait()
            
            print("Server started and listening on \(channel.localAddress!)")
            
            // This will never unblock as we don't close the ServerChannel
            try channel.closeFuture.wait()
        }
        catch {
            print("Error starting server")
        }
    }
}




//defer {
//    try! group.syncShutdownGracefully()
//    try! threadPool.syncShutdownGracefully()
//}

