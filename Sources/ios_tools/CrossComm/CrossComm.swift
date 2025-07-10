import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 消息类型枚举
public enum CommMsgType: String, CaseIterable, Codable {
    case text = "text"
    case json = "json"
    case dict = "dict"
    case bytes = "bytes"
    case file = "file"
    case image = "image"
    case folder = "folder"
    case heartbeat = "heartbeat"
    case login = "login"
    case logout = "logout"
    case listClients = "list_clients"
    case listClientsResponse = "list_clients_response"
    case loginResponse = "login_response"
}

// MARK: - 消息结构体
public struct Message: Codable {
    public let msgId: String
    public let fromClientId: String
    public let toClientId: String
    public let msgType: CommMsgType
    public let content: String  // 使用String存储所有内容，需要时再解析
    public let timestamp: Double
    public let ossKey: String?  // 用于文件传输的OSS键值
    
    enum CodingKeys: String, CodingKey {
        case msgId = "msg_id"
        case fromClientId = "from_client_id"
        case toClientId = "to_client_id"
        case msgType = "msg_type"
        case content
        case timestamp
        case ossKey = "oss_key"
    }
    
    public init(msgId: String, fromClientId: String, toClientId: String, msgType: CommMsgType, content: String, timestamp: Double, ossKey: String? = nil) {
        self.msgId = msgId
        self.fromClientId = fromClientId
        self.toClientId = toClientId
        self.msgType = msgType
        self.content = content
        self.timestamp = timestamp
        self.ossKey = ossKey
    }
}

// MARK: - 消息处理器协议
public protocol MessageHandler {
    func handle(_ message: Message) async
}

// MARK: - 消息监听器配置
public struct MessageListenerConfig {
    let msgType: CommMsgType?
    let fromClientId: String?
    let downloadDirectory: String?  // 文件下载目录
    let handler: (Message) async -> Void
    
    public init(msgType: CommMsgType? = nil, fromClientId: String? = nil, downloadDirectory: String? = nil, handler: @escaping (Message) async -> Void) {
        self.msgType = msgType
        self.fromClientId = fromClientId
        self.downloadDirectory = downloadDirectory
        self.handler = handler
    }
}

// MARK: - CrossComm 客户端
@available(iOS 13.0, macOS 10.15, watchOS 6.2, *)
public actor CrossCommClient {
    private let ip: String
    private let port: Int
    private let clientId: String
    private let heartbeatInterval: TimeInterval
    private let heartbeatTimeout: TimeInterval
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var heartbeatTask: Task<Void, Never>?
    private var messageListeners: [MessageListenerConfig] = []
    private var lastClientList: [String: Any]?
    private var aliyunOSS: AliyunOSS?  // OSS实例，用于文件传输
    
    public init(
        ip: String = "localhost", 
        port: Int = 9898, 
        clientId: String? = nil, 
        heartbeatInterval: TimeInterval = 30, 
        heartbeatTimeout: TimeInterval = 60,
        ossEndpoint: String? = nil,
        ossAccessKeyId: String? = nil,
        ossAccessKeySecret: String? = nil,
        ossBucketName: String? = nil
    ) {
        self.ip = ip
        self.port = port
        self.heartbeatInterval = heartbeatInterval
        self.heartbeatTimeout = heartbeatTimeout
        
        // 生成客户端唯一ID
        if let customId = clientId {
            self.clientId = customId
        } else {
            // 使用设备信息生成唯一ID，针对不同平台使用相应的API
            let deviceId: String
            
            #if os(iOS) || os(tvOS)
            // iOS, iPadOS, tvOS 使用 UIDevice
            deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #elseif os(watchOS)
            // watchOS 使用 WKInterfaceDevice
            deviceId = WKInterfaceDevice.current().identifierForVendor?.uuidString ?? UUID().uuidString
            #elseif os(macOS)
            // macOS 可以尝试使用系统信息或直接使用UUID
            deviceId = UUID().uuidString
            #else
            // 其他平台直接使用UUID
            deviceId = UUID().uuidString
            #endif
            
            let randomId = String(UUID().uuidString.prefix(8))
            self.clientId = "\(deviceId)_\(randomId)"
        }
        
        // 初始化OSS（如果提供了配置）
        if let endpoint = ossEndpoint,
           let keyId = ossAccessKeyId,
           let keySecret = ossAccessKeySecret,
           let bucket = ossBucketName {
            self.aliyunOSS = AliyunOSS(
                endpoint: endpoint,
                bucketName: bucket,
                apiKey: keyId,
                apiSecret: keySecret,
                verbose: false
            )
            WaynePrint.print("AliyunOSS initialized for file transfer", color: "cyan")
        } else {
            self.aliyunOSS = nil
            WaynePrint.print("AliyunOSS not configured - file transfer disabled", color: "yellow")
        }
        
        WaynePrint.print("CrossCommClient initialized: clientId=\(self.clientId)", color: "green")
    }
    
    // MARK: - 连接管理
    public func connect() async -> Bool {
        guard let url = URL(string: "ws://\(ip):\(port)") else {
            WaynePrint.print("Invalid WebSocket URL", color: "red")
            return false
        }
        
        let urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with: url)
        
        webSocketTask?.resume()
        
        // 启动消息接收
        startReceiving()
        
        // 发送登录消息
        let loginMessage = Message(
            msgId: generateMsgId(),
            fromClientId: clientId,
            toClientId: "server",
            msgType: .login,
            content: "{}",
            timestamp: Date().timeIntervalSince1970
        )
        
        let success = await sendMessage(loginMessage)
        if success {
            isConnected = true
            startHeartbeat()
            WaynePrint.print("Connected to server successfully", color: "green")
        } else {
            WaynePrint.print("Failed to send login message", color: "red")
        }
        
        return success
    }
    
    public func disconnect() async {
        isConnected = false
        
        // 取消心跳任务
        heartbeatTask?.cancel()
        
        // 发送登出消息
        let logoutMessage = Message(
            msgId: generateMsgId(),
            fromClientId: clientId,
            toClientId: "server",
            msgType: .logout,
            content: "{}",
            timestamp: Date().timeIntervalSince1970
        )
        
        _ = await sendMessage(logoutMessage)
        
        // 关闭WebSocket连接
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        WaynePrint.print("Disconnected from server", color: "yellow")
    }
    
    // MARK: - 消息发送
    public func send(content: Any, msgType: CommMsgType, toClientId: String = "all") async -> Bool {
        guard isConnected else {
            WaynePrint.print("Client not connected", color: "red")
            return false
        }
        
        // 处理文件类型消息 - 先上传到OSS
        var ossKey: String? = nil
        var processedContent: String?
        
        if [.file, .image, .folder].contains(msgType) {
            // 文件类型消息需要先上传到OSS
            guard let aliyunOSS = aliyunOSS else {
                WaynePrint.print("File transfer requires OSS configuration", color: "red")
                return false
            }
            
            guard let filePath = content as? String else {
                WaynePrint.print("File message content must be a file path string", color: "red")
                return false
            }
            
            // 检查文件/目录是否存在
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) else {
                WaynePrint.print("File or directory does not exist: \(filePath)", color: "red")
                return false
            }
            
            // 验证文件类型与消息类型匹配
            if msgType == .folder && !isDirectory.boolValue {
                WaynePrint.print("Expected directory for folder message type", color: "red")
                return false
            } else if [.file, .image].contains(msgType) && isDirectory.boolValue {
                WaynePrint.print("Expected file for \(msgType.rawValue) message type", color: "red")
                return false
            }
            
            do {
                if msgType == .folder {
                    // 上传文件夹
                    ossKey = try await uploadFolderToOSS(aliyunOSS, folderPath: filePath)
                } else {
                    // 上传文件
                    ossKey = try await uploadFileToOSS(aliyunOSS, filePath: filePath, msgType: msgType)
                }
                
                guard let validOssKey = ossKey else {
                    WaynePrint.print("Failed to upload file to OSS", color: "red")
                    return false
                }
                
                processedContent = filePath  // 保存原始文件路径作为content
                WaynePrint.print("File uploaded to OSS: \(validOssKey)", color: "green")
                
            } catch {
                WaynePrint.print("Failed to upload file: \(error)", color: "red")
                return false
            }
        } else {
            // 非文件类型消息，使用原有的处理逻辑
            processedContent = processContentForType(content, msgType: msgType)
        }
        
        guard let contentString = processedContent else {
            WaynePrint.print("Failed to process content for message type \(msgType.rawValue)", color: "red")
            return false
        }
        
        let message = Message(
            msgId: generateMsgId(),
            fromClientId: clientId,
            toClientId: toClientId,
            msgType: msgType,
            content: contentString,
            timestamp: Date().timeIntervalSince1970,
            ossKey: ossKey
        )
        
        let success = await sendMessage(message)
        if success {
            WaynePrint.print("Message sent: \(msgType.rawValue) -> \(toClientId)", color: "green")
        }
        return success
    }
    
    // MARK: - 客户端列表
    public func listClients(onlyShowOnline: Bool = true, timeout: TimeInterval = 5.0) async -> [String: Any]? {
        guard isConnected else {
            WaynePrint.print("Client not connected", color: "red")
            return nil
        }
        
        // 清空之前的响应
        lastClientList = nil
        
        let requestContent = ["only_show_online": onlyShowOnline]
        guard let contentData = try? JSONSerialization.data(withJSONObject: requestContent),
              let contentString = String(data: contentData, encoding: .utf8) else {
            WaynePrint.print("Failed to create list clients request", color: "red")
            return nil
        }
        
        let requestMessage = Message(
            msgId: generateMsgId(),
            fromClientId: clientId,
            toClientId: "server",
            msgType: .listClients,
            content: contentString,
            timestamp: Date().timeIntervalSince1970
        )
        
        let success = await sendMessage(requestMessage)
        if !success {
            WaynePrint.print("Failed to send list clients request", color: "red")
            return nil
        }
        
        // 等待响应
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if let response = lastClientList {
                return response
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        WaynePrint.print("List clients request timeout", color: "yellow")
        return nil
    }
    
    // MARK: - 消息监听器
    public func addMessageListener(
        msgType: CommMsgType? = nil, 
        fromClientId: String? = nil, 
        downloadDirectory: String? = nil,
        handler: @escaping (Message) async -> Void
    ) {
        let config = MessageListenerConfig(
            msgType: msgType, 
            fromClientId: fromClientId, 
            downloadDirectory: downloadDirectory,
            handler: handler
        )
        messageListeners.append(config)
        
        var description = "Added message listener"
        if let msgType = msgType {
            description += " for type: \(msgType.rawValue)"
        }
        if let fromClientId = fromClientId {
            description += " from: \(fromClientId)"
        }
        if let downloadDir = downloadDirectory {
            description += " with download dir: \(downloadDir)"
        }
        WaynePrint.print(description, color: "cyan")
    }
    
    // MARK: - 内部方法
    private func generateMsgId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = String(UUID().uuidString.prefix(8))
        return "\(clientId)_\(timestamp)_\(random)"
    }
    
    private func processContentForType(_ content: Any, msgType: CommMsgType) -> String? {
        switch msgType {
        case .text:
            return String(describing: content)
            
        case .json:
            if let string = content as? String {
                // 验证是否为有效JSON
                guard let data = string.data(using: .utf8),
                      (try? JSONSerialization.jsonObject(with: data)) != nil else {
                    WaynePrint.print("Invalid JSON string", color: "red")
                    return nil
                }
                return string
            } else {
                // 将对象转换为JSON字符串
                guard let data = try? JSONSerialization.data(withJSONObject: content),
                      let jsonString = String(data: data, encoding: .utf8) else {
                    WaynePrint.print("Failed to convert content to JSON", color: "red")
                    return nil
                }
                return jsonString
            }
            
        case .dict:
            guard let data = try? JSONSerialization.data(withJSONObject: content),
                  let jsonString = String(data: data, encoding: .utf8) else {
                WaynePrint.print("Failed to convert dict to JSON", color: "red")
                return nil
            }
            return jsonString
            
        case .bytes:
            if let data = content as? Data {
                return data.base64EncodedString()
            } else if let bytes = content as? [UInt8] {
                return Data(bytes).base64EncodedString()
            } else {
                WaynePrint.print("Invalid bytes content", color: "red")
                return nil
            }
            
        default:
            return String(describing: content)
        }
    }
    
    private func sendMessage(_ message: Message) async -> Bool {
        guard let webSocketTask = webSocketTask else {
            return false
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let string = String(data: data, encoding: .utf8) ?? ""
            try await webSocketTask.send(.string(string))
            return true
        } catch {
            WaynePrint.print("Failed to send message: \(error)", color: "red")
            return false
        }
    }
    
    private func startReceiving() {
        guard let webSocketTask = webSocketTask else { return }
        
        Task {
            do {
                while !Task.isCancelled {
                    let message = try await webSocketTask.receive()
                    await handleReceivedMessage(message)
                }
            } catch {
                WaynePrint.print("WebSocket receiving error: \(error)", color: "red")
                isConnected = false
            }
        }
    }
    
    private func handleReceivedMessage(_ wsMessage: URLSessionWebSocketTask.Message) async {
        switch wsMessage {
        case .string(let text):
            if let message = parseMessageFromString(text) {
                await processReceivedMessage(message)
            } else {
                WaynePrint.print("Failed to parse message: \(text)", color: "red")
            }
            
        case .data(let data):
            if let text = String(data: data, encoding: .utf8),
               let message = parseMessageFromString(text) {
                await processReceivedMessage(message)
            } else {
                WaynePrint.print("Failed to parse binary message", color: "red")
            }
            
        @unknown default:
            WaynePrint.print("Unknown message type received", color: "yellow")
        }
    }
    
    // 新增：灵活的消息解析方法
    private func parseMessageFromString(_ text: String) -> Message? {
        guard let data = text.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        guard let msgId = jsonObject["msg_id"] as? String,
              let fromClientId = jsonObject["from_client_id"] as? String,
              let toClientId = jsonObject["to_client_id"] as? String,
              let msgTypeString = jsonObject["msg_type"] as? String,
              let msgType = CommMsgType(rawValue: msgTypeString),
              let timestamp = jsonObject["timestamp"] as? Double else {
            return nil
        }
        
        // 处理content字段 - 可能是字符串、字典或其他类型
        let contentString: String
        if let stringContent = jsonObject["content"] as? String {
            contentString = stringContent
        } else if let content = jsonObject["content"] {
            // 将非字符串类型转换为JSON字符串
            if let contentData = try? JSONSerialization.data(withJSONObject: content),
               let jsonString = String(data: contentData, encoding: .utf8) {
                contentString = jsonString
            } else {
                contentString = String(describing: content)
            }
        } else {
            contentString = ""
        }
        
        // 解析ossKey字段
        let ossKey = jsonObject["oss_key"] as? String
        
        return Message(
            msgId: msgId,
            fromClientId: fromClientId,
            toClientId: toClientId,
            msgType: msgType,
            content: contentString,
            timestamp: timestamp,
            ossKey: ossKey
        )
    }
    
    private func processReceivedMessage(_ message: Message) async {
        // 处理特殊消息类型
        switch message.msgType {
        case .listClientsResponse:
            handleListClientsResponse(message)
            return
            
        case .heartbeat:
            // 忽略心跳消息
            return
            
        default:
            break
        }
        
        // 不处理自己发送的消息
        if message.fromClientId == clientId {
            return
        }
        
        // 处理字节消息的解码
        var processedMessage = message
        if message.msgType == .bytes {
            // 尝试解码base64字符串为Data
            if Data(base64Encoded: message.content) != nil {
                // 这里我们保持为base64字符串，让用户自己决定如何处理
                processedMessage = message
            }
        }
        
        // 处理文件类型消息 - 自动下载文件
        if [.file, .image, .folder].contains(message.msgType), let ossKey = message.ossKey {
            processedMessage = await handleFileMessage(message, ossKey: ossKey)
        }
        
        // 调用所有匹配的消息监听器
        for listener in messageListeners {
            // 过滤消息类型
            if let listenerMsgType = listener.msgType, listenerMsgType != message.msgType {
                continue
            }
            
            // 过滤发送方
            if let listenerFromClientId = listener.fromClientId, listenerFromClientId != message.fromClientId {
                continue
            }
            
            // 调用处理器
            await listener.handler(processedMessage)
        }
    }
    
    private func handleListClientsResponse(_ message: Message) {
        do {
            let data = message.content.data(using: .utf8) ?? Data()
            let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            lastClientList = response
            
            if let totalCount = response?["total_count"] as? Int {
                WaynePrint.print("Received client list with \(totalCount) clients", color: "blue")
            }
        } catch {
            WaynePrint.print("Failed to parse client list response: \(error)", color: "red")
        }
    }
    
    private func startHeartbeat() {
        heartbeatTask = Task {
            while !Task.isCancelled && isConnected {
                let heartbeatMessage = Message(
                    msgId: generateMsgId(),
                    fromClientId: clientId,
                    toClientId: "server",
                    msgType: .heartbeat,
                    content: "{}",
                    timestamp: Date().timeIntervalSince1970
                )
                
                _ = await sendMessage(heartbeatMessage)
                
                try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
            }
        }
    }
    
    // MARK: - 文件处理功能
    
    private func handleFileMessage(_ message: Message, ossKey: String) async -> Message {
        // 查找匹配的监听器，检查是否配置了下载目录
        var downloadDirectory: String? = nil
        
        for listener in messageListeners {
            // 检查是否匹配消息类型和发送方
            if let listenerMsgType = listener.msgType, listenerMsgType != message.msgType {
                continue
            }
            
            if let listenerFromClientId = listener.fromClientId, listenerFromClientId != message.fromClientId {
                continue
            }
            
            // 找到匹配的监听器，获取其下载目录
            if let downloadDir = listener.downloadDirectory {
                downloadDirectory = downloadDir
                break
            }
        }
        
        // 如果没有配置下载目录，直接返回原消息
        guard let downloadDir = downloadDirectory else {
            WaynePrint.print("File message received but no download directory configured", color: "yellow")
            return message
        }
        
        // 确保有OSS配置
        guard let aliyunOSS = aliyunOSS else {
            WaynePrint.print("File download requires OSS configuration", color: "red")
            return message
        }
        
        do {
            // 创建下载目录
            let fileManager = FileManager.default
            try fileManager.createDirectory(atPath: downloadDir, withIntermediateDirectories: true, attributes: nil)
            
            let localPath: String
            
            if message.msgType == .folder {
                // 下载文件夹
                localPath = try await downloadFolderFromOSS(aliyunOSS, ossKey: ossKey, downloadDir: downloadDir)
            } else {
                // 下载文件
                localPath = try await downloadFileFromOSS(aliyunOSS, ossKey: ossKey, downloadDir: downloadDir)
            }
            
            // 创建新的消息，将content更新为本地文件路径
            let updatedMessage = Message(
                msgId: message.msgId,
                fromClientId: message.fromClientId,
                toClientId: message.toClientId,
                msgType: message.msgType,
                content: localPath,
                timestamp: message.timestamp,
                ossKey: message.ossKey
            )
            
            WaynePrint.print("File downloaded: \(ossKey) -> \(localPath)", color: "green")
            return updatedMessage
            
        } catch {
            WaynePrint.print("Failed to download file: \(error)", color: "red")
            return message
        }
    }
    
    private func downloadFileFromOSS(_ oss: AliyunOSS, ossKey: String, downloadDir: String) async throws -> String {
        // 从OSS key中提取文件名
        let fileName = (ossKey as NSString).lastPathComponent
        let localPath = (downloadDir as NSString).appendingPathComponent(fileName)
        
        let success = try await oss.downloadFile(key: ossKey, rootDir: downloadDir, useBasename: true)
        if success {
            return localPath
        } else {
            throw NSError(domain: "CrossComm", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download file from OSS"])
        }
    }
    
    private func downloadFolderFromOSS(_ oss: AliyunOSS, ossKey: String, downloadDir: String) async throws -> String {
        // 创建一个以时间戳命名的文件夹
        let timestamp = Int(Date().timeIntervalSince1970)
        let folderName = "folder_\(timestamp)"
        let localFolderPath = (downloadDir as NSString).appendingPathComponent(folderName)
        
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: localFolderPath, withIntermediateDirectories: true, attributes: nil)
        
        // 使用AliyunOSS的downloadDirectory方法真正下载文件夹内容
        let success = try await oss.downloadDirectory(prefix: ossKey, localPath: localFolderPath, useBasename: false)
        if success {
            WaynePrint.print("Folder downloaded successfully from OSS", color: "green")
        } else {
            WaynePrint.print("Folder download failed or folder is empty", color: "yellow")
        }
        
        return localFolderPath
    }
    
    private func uploadFileToOSS(_ oss: AliyunOSS, filePath: String, msgType: CommMsgType) async throws -> String? {
        // 生成唯一的OSS key
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let randomId = String(UUID().uuidString.prefix(8))
        let fileExtension = (filePath as NSString).pathExtension
        let fileName = (filePath as NSString).lastPathComponent
        
        let ossKey: String
        if fileExtension.isEmpty {
            ossKey = "cross_comm/\(clientId)/\(timestamp)_\(randomId)_\(fileName)"
        } else {
            ossKey = "cross_comm/\(clientId)/\(timestamp)_\(randomId).\(fileExtension)"
        }
        
        let success = try await oss.uploadFile(key: ossKey, filePath: filePath)
        return success ? ossKey : nil
    }
    
    private func uploadFolderToOSS(_ oss: AliyunOSS, folderPath: String) async throws -> String? {
        // 文件夹上传需要逐个上传文件夹内的文件
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let randomId = String(UUID().uuidString.prefix(8))
        let folderName = (folderPath as NSString).lastPathComponent
        let ossPrefix = "cross_comm/\(clientId)/\(timestamp)_\(randomId)_\(folderName)/"
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: folderPath),
                                                     includingPropertiesForKeys: [.isRegularFileKey],
                                                     options: [.skipsHiddenFiles]) else {
            WaynePrint.print("Failed to enumerate folder contents", color: "red")
            return nil
        }
        
        // 收集所有文件URL到数组中，避免在异步上下文中使用迭代器
        var fileURLs: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    fileURLs.append(fileURL)
                }
            } catch {
                WaynePrint.print("Error checking file \(fileURL.path): \(error)", color: "yellow")
            }
        }
        
        var uploadCount = 0
        for fileURL in fileURLs {
            do {
                let relativePath = String(fileURL.path.dropFirst(folderPath.count + 1))
                let ossKey = ossPrefix + relativePath
                
                let success = try await oss.uploadFile(key: ossKey, filePath: fileURL.path)
                if success {
                    uploadCount += 1
                } else {
                    WaynePrint.print("Failed to upload file: \(relativePath)", color: "yellow")
                }
            } catch {
                WaynePrint.print("Error uploading file \(fileURL.path): \(error)", color: "yellow")
            }
        }
        
        WaynePrint.print("Uploaded \(uploadCount) files from folder", color: "green")
        return uploadCount > 0 ? ossPrefix : nil
    }
}

// MARK: - 便利扩展
@available(iOS 13.0, macOS 10.15, watchOS 6.2, *)
extension CrossCommClient {
    
    /// 发送文本消息
    public func sendText(_ text: String, to clientId: String = "all") async -> Bool {
        return await send(content: text, msgType: .text, toClientId: clientId)
    }
    
    /// 发送JSON消息
    public func sendJSON(_ json: Any, to clientId: String = "all") async -> Bool {
        return await send(content: json, msgType: .json, toClientId: clientId)
    }
    
    /// 发送字典消息
    public func sendDict(_ dict: [String: Any], to clientId: String = "all") async -> Bool {
        return await send(content: dict, msgType: .dict, toClientId: clientId)
    }
    
    /// 发送字节数据
    public func sendBytes(_ data: Data, to clientId: String = "all") async -> Bool {
        return await send(content: data, msgType: .bytes, toClientId: clientId)
    }
    
    /// 发送文件
    public func sendFile(_ filePath: String, to clientId: String = "all") async -> Bool {
        return await send(content: filePath, msgType: .file, toClientId: clientId)
    }
    
    /// 发送图片
    public func sendImage(_ imagePath: String, to clientId: String = "all") async -> Bool {
        return await send(content: imagePath, msgType: .image, toClientId: clientId)
    }
    
    /// 发送文件夹
    public func sendFolder(_ folderPath: String, to clientId: String = "all") async -> Bool {
        return await send(content: folderPath, msgType: .folder, toClientId: clientId)
    }
} 