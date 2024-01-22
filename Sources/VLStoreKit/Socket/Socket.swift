//
//  Socket.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 25/02/22.
//

import Foundation
import Starscream
import SocketIO

final class Socket: WebSocketDelegate {
    
    private var socket:WebSocket?
    
    private var syncSocketConnectionCompletionHandler:((Bool) -> Void)?
    private var syncSocketAPIConnectionCompletionHandler:((Bool) -> Void)?
    private var socketConnectionCompletionHandler:((Bool) -> Void)?
    private var socketMessageHandler:((_ message:String?) -> Void)?
    private var isSyncSocketOnLaunch:Bool = false
    
    func createWebSocket(with authToken:String, isSyncingOnLaunch:Bool = false, socketConnectionCompletionHandler:((Bool) -> Void)? = nil, syncSocketAPIConnectionCompletionHandler:((Bool) -> Void)? = nil, socketMessageHandler:((_ message:String?) -> Void)? = nil)  {
        if self.socket != nil && !isSocketConnected() {
            self.socket = nil
        }
        
        if self.socket == nil {
            self.createSocket(authToken: authToken, isSyncingOnLaunch: isSyncingOnLaunch, socketConnectionCompletionHandler: socketConnectionCompletionHandler, syncSocketAPIConnectionCompletionHandler: syncSocketAPIConnectionCompletionHandler, socketMessageHandler: socketMessageHandler)
        }
        else if self.socket != nil && isSocketConnected() {
            socketConnectionCompletionHandler?(true)
        }
    }
    
    private func createSocket(authToken:String, isSyncingOnLaunch:Bool, socketConnectionCompletionHandler:((Bool) -> Void)? = nil, syncSocketAPIConnectionCompletionHandler:((Bool) -> Void)? = nil, socketMessageHandler:((_ message:String?) -> Void)? = nil) {
        var apiUrl = APIUrl.getAPIBaseUrl()
        apiUrl = apiUrl.replacingOccurrences(of: "http", with: "ws")
        apiUrl = apiUrl.replacingOccurrences(of: "api", with: "ws")
        apiUrl = "\(apiUrl)/notification?token=\(authToken)"
        if let _url = URL(string: apiUrl) {
            var request = URLRequest(url: _url)
            request.timeoutInterval = 60
            socket = WebSocket(request: request)
            socket?.delegate = self
            socket?.connect()
            self.socketMessageHandler = socketMessageHandler
            if isSyncingOnLaunch {
                self.syncSocketConnectionCompletionHandler = socketConnectionCompletionHandler
                self.syncSocketAPIConnectionCompletionHandler = syncSocketAPIConnectionCompletionHandler
                self.isSyncSocketOnLaunch = isSyncingOnLaunch
            }
            else {
                self.socketConnectionCompletionHandler = socketConnectionCompletionHandler
            }
        }
    }
    
    private func isSocketConnected() -> Bool {
        var isConnected = false
        if socket != nil {
            socket!.onEvent = { (socketEvent) in
                switch socketEvent {
                case .connected(_):
                    isConnected = true
                default:
                    break
                }
            }
        }
        return isConnected
    }
    
    //MARK: WebSocket Delegates
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(_):
            self.websocketDidConnect()
        case .disconnected(_, _):
            self.websocketDidDisconnect()
        case .text(_):
            self.websocketDidReceiveMessage()
        case .binary(_):
            self.websocketDidReceiveData()
        case .pong(_):
            break
        case .ping(_):
            break
        case .error(_):
            self.websocketDidDisconnect()
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            self.websocketDidDisconnect()
        default:
            break
        }
    }
    
    private func websocketDidConnect() {
        if self.syncSocketConnectionCompletionHandler != nil {
            self.syncSocketConnectionCompletionHandler?(true)
        }
        if self.socketConnectionCompletionHandler != nil {
            self.socketConnectionCompletionHandler?(true)
        }
    }
    
    func websocketDidReceiveMessage() {
        if self.socketConnectionCompletionHandler != nil {
            self.socketConnectionCompletionHandler?(false)
        }
        if self.syncSocketConnectionCompletionHandler != nil {
            self.syncSocketConnectionCompletionHandler?(false)
        }
        self.socket?.disconnect()
        self.socketMessageHandler?("SocketReceivedMessage")
    }
    
    func websocketDidReceiveData() {
        self.socket?.disconnect()
    }
    
    func websocketDidDisconnect() {
        if self.socketConnectionCompletionHandler != nil {
            self.socketConnectionCompletionHandler?(false)
        }
        if self.syncSocketConnectionCompletionHandler != nil {
            self.syncSocketConnectionCompletionHandler?(false)
        }
        self.socket = nil
        if !isSyncSocketOnLaunch {
            self.socketMessageHandler?(nil)
        }
    }
    
    func sendMessageToSocket(authToken:String) {
        if isSocketConnected() {
            var dictionary:Dictionary<String,String>  = [:]
            dictionary["action"] = "subscribe"
            dictionary["eventType"] = "PURCHASE_SUCCESS"
            dictionary["token"] = authToken
            var description:String = dictionary.description
            description = description.replacingOccurrences(of: "[", with: "{")
            description = description.replacingOccurrences(of: "]", with: "}")
            self.socket?.write(string: description)
        }
    }
    
    func resetCompletionHandler() {
        if self.socketConnectionCompletionHandler != nil {
            self.socketConnectionCompletionHandler = nil
        }
        if self.syncSocketConnectionCompletionHandler != nil {
            self.syncSocketConnectionCompletionHandler = nil
        }
    }
}
