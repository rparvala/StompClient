//
//  StompClient.swift
//  Surveillance
//
//  Created by ShengHua Wu on 3/23/16.
//  Copyright © 2016 nogle. All rights reserved.
//

import Starscream
import Foundation

public protocol StompClientDelegate {
    
    func stompClientDidConnected(_ client: StompClient)
    func stompClient(_ client: StompClient, didErrorOccurred error: NSError)
    func stompClient(_ client: StompClient, didReceivedData data: Data, fromDestination destination: String)
    
}

public final class StompClient {
    
    // MARK: - Public Properties
    public var delegate: StompClientDelegate?
    public var isConnected: Bool {
        return socket.isConnected
    }

    // MARK: - Private Properties
    private var socket: WebSocketProtocol
    
    // MARK: - Designated Initializer
    init(socket: WebSocketProtocol) {
        self.socket = socket
        self.socket.delegate = self
    }
    
    // MARK: - Convenience Initializer
    public convenience init(url: URL) {
        let socket = WebSocket(url: url.appendServerIdAndSessionId())
        self.init(socket: socket)
    }
    
    // MARK: - Public Methods
    public func setValue(_ value: String, forHeaderField field: String) {
        socket.headers[field] = value
    }
    
    public func connect() {
        socket.connect()
    }
    
    public func disconnect() {
        sendDisconnect()
        socket.disconnect(0.0)
    }
    
    public func subscribe(_ destination: String, parameters: [String : String]? = nil) -> String {
        let id = "sub-" + Int(arc4random_uniform(1000)).description
        var headers: Set<StompHeader> = [.destinationId(id: id), .destination(path: destination)]
        if let params = parameters , !params.isEmpty {
            for (key, value) in params {
                headers.insert(.custom(key: key, value: value))
            }
        }
        let frame = StompFrame(command: .subscribe, headers: headers)
        sendFrame(frame)
        
        return id
    }

    public func unsubscribe(_ destination: String, destinationId: String) {
        let headers: Set<StompHeader> = [.destinationId(id: destinationId), .destination(path: destination)]
        let frame = StompFrame(command: .unsubscribe, headers: headers)
        sendFrame(frame)
    }
    
    // MARK: - Private Methods
    fileprivate func sendConnect() {
        let headers: Set<StompHeader> = [.acceptVersion(version: "1.1"), .heartBeat(value: "10000,10000")]
        let frame = StompFrame(command: .connect, headers: headers)
        sendFrame(frame)
    }
    
    private func sendDisconnect() {
        let frame = StompFrame(command: .disconnect)
        sendFrame(frame)
    }
    
    private func sendFrame(_ frame: StompFrame) {
        let data = try! JSONSerialization.data(withJSONObject: [frame.description], options: JSONSerialization.WritingOptions(rawValue: 0))
        let string = String(data: data, encoding: String.Encoding.utf8)!
        // Because STOMP is a message convey protocol, 
        // only -websocketDidReceiveMessage method will be called,
        // and we MUST use -writeString method to pass messages.
        socket.writeString(string)
    }
    
}

// MARK: - Websocket Delegate
extension StompClient: WebSocketDelegate {

    
    public func websocketDidConnect(socket: WebSocketClient) {
        // We should wait for server response an open type frame.
    }
    
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        if let error = error {
            delegate?.stompClient(self, didErrorOccurred: error as NSError)
        }
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        var mutableText = text
        let firstCharacter = mutableText.remove(at: mutableText.startIndex)
        do {
            // Parse response type from the first character
            let type = try StompResponseType(character: firstCharacter)
            if type == .Open {
                sendConnect()
                return
            } else if type == .HeartBeat {
                // TODO: Send heart-beat back to server.
                return
            }
            
            // Parse frame from the remaining text
            let frame = try StompFrame(text: mutableText)
            switch frame.command {
            case .connected:
                delegate?.stompClientDidConnected(self)
            case .message:
                guard let data = frame.body?.data(using: String.Encoding.utf8) else {
                    return
                }
                
                delegate?.stompClient(self, didReceivedData: data, fromDestination: frame.destination)
            case .error:
                let error = NSError(domain: "com.shenghuawu.error", code: 999, userInfo: [NSLocalizedDescriptionKey : frame.message])
                delegate?.stompClient(self, didErrorOccurred: error)
            default:
                break
            }
        } catch let error as NSError {
            delegate?.stompClient(self, didErrorOccurred: error)
        }
    }
    
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // This delegate will NOT be called, since STOMP is a message convey protocol.
    }
    
}

// MARK: - Extensions
extension URL {
    
    func appendServerIdAndSessionId() -> URL {
        let serverId = Int(arc4random_uniform(1000)).description
        let sessionId = String.randomAlphaNumericString(8)
        var path = (serverId as NSString).appendingPathComponent(sessionId)
        path = (path as NSString).appendingPathComponent("websocket")
        
        return self.appendingPathComponent(path)
    }
    
}

extension String {
    
    static func randomAlphaNumericString(_ length: Int) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.characters.count)
        var randomString = ""
        
        for _ in (0 ..< length) {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let newCharacter = allowedChars[allowedChars.characters.index(allowedChars.startIndex, offsetBy: randomNum)]
            randomString += String(newCharacter)
        }
        
        return randomString
    }
    
}

public protocol WebSocketProtocol {
    
    weak var delegate: WebSocketDelegate? { get set }
    var headers: [String : String] { get set }
    var isConnected: Bool { get }
    
    func connect()
    func disconnect(_ forceTimeout: TimeInterval?)
    func writeString(_ str: String)
    
}

extension WebSocket: WebSocketProtocol {
    public var headers: [String : String] {
        get {
            return self.headers
        }
        set {
            self.headers = newValue
        }
    }
    
    public func disconnect(_ forceTimeout: TimeInterval?) {
        disconnect(forceTimeout: forceTimeout)
    }

    
    public func writeString(_ str: String) {
        write(string: str, completion: nil)
    }
}
