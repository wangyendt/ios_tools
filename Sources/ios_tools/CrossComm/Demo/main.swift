import Foundation
import ios_tools_lib

@available(iOS 13.0, macOS 10.15, watchOS 6.2, *)
@main
struct CrossCommDemo {
    // 默认服务器配置
    static let DEFAULT_SERVER_IP = "39.105.45.101"
    static let DEFAULT_SERVER_PORT = 9898
    
    // 🔧 AliyunOSS配置 - 修改这里以启用文件传输功能
    // 如果不需要文件传输功能，保持这些值为nil即可
    static let OSS_ENDPOINT = "xxx"  // 例如: "oss-cn-beijing.aliyuncs.com"
    static let OSS_ACCESS_KEY_ID = "xxx"  // 例如: "your-access-key-id"
    static let OSS_ACCESS_KEY_SECRET = "xxx"  // 例如: "your-access-key-secret"
    static let OSS_BUCKET_NAME = "xxx"  // 例如: "your-bucket-name"
    
    // 📁 文件下载目录配置
    static let DOWNLOAD_FILES_DIR = "./downloads/files"
    static let DOWNLOAD_IMAGES_DIR = "./downloads/images" 
    static let DOWNLOAD_FOLDERS_DIR = "./downloads/folders"
    
    static func main() async {
        let arguments = CommandLine.arguments
        
        if arguments.count < 2 {
            printUsage()
            return
        }
        
        let mode = arguments[1].lowercased()
        let serverIP = arguments.count > 2 ? arguments[2] : DEFAULT_SERVER_IP
        let serverPort = arguments.count > 3 ? Int(arguments[3]) ?? DEFAULT_SERVER_PORT : DEFAULT_SERVER_PORT
        
        switch mode {
        case "listen", "listener":
            await runListenerMode(serverIP: serverIP, port: serverPort)
        case "send", "sender":
            await runSenderMode(serverIP: serverIP, port: serverPort)
        case "both", "interactive":
            await runInteractiveMode(serverIP: serverIP, port: serverPort)
        default:
            printUsage()
        }
    }
    
    static func printUsage() {
        WaynePrint.print("=== CrossComm iOS 测试工具 ===", color: "cyan")
        WaynePrint.print("", color: "white")
        WaynePrint.print("使用方法:", color: "yellow")
        WaynePrint.print("  swift run CrossCommDemo <模式> [服务器IP] [端口]", color: "white")
        WaynePrint.print("", color: "white")
        WaynePrint.print("默认服务器: \(DEFAULT_SERVER_IP):\(DEFAULT_SERVER_PORT)", color: "cyan")
        WaynePrint.print("", color: "white")
        WaynePrint.print("模式选项:", color: "yellow")
        WaynePrint.print("  listen    - 监听模式，接收并显示消息", color: "green")
        WaynePrint.print("  send      - 发送模式，发送测试消息", color: "blue")
        WaynePrint.print("  both      - 交互模式，既监听又可发送", color: "magenta")
        WaynePrint.print("", color: "white")
        WaynePrint.print("示例:", color: "yellow")
        WaynePrint.print("  swift run CrossCommDemo listen", color: "white")
        WaynePrint.print("  swift run CrossCommDemo send \(DEFAULT_SERVER_IP) \(DEFAULT_SERVER_PORT)", color: "white")
        WaynePrint.print("  swift run CrossCommDemo both 192.168.1.100", color: "white")
        WaynePrint.print("  swift run CrossCommDemo listen localhost 9898", color: "white")
        WaynePrint.print("", color: "white")
        WaynePrint.print("注意:", color: "red")
        WaynePrint.print("  1. 确保CrossComm Python服务器正在运行", color: "white")
        WaynePrint.print("  2. 文件传输需要配置AliyunOSS参数（在Demo代码中）", color: "white")
    }
    
    // MARK: - 客户端创建辅助方法
    static func createCrossCommClient(serverIP: String, port: Int, clientId: String) -> CrossCommClient {
        // 检查OSS配置是否完整（非空字符串）
        if !OSS_ENDPOINT.isEmpty &&
           !OSS_ACCESS_KEY_ID.isEmpty &&
           !OSS_ACCESS_KEY_SECRET.isEmpty &&
           !OSS_BUCKET_NAME.isEmpty {
            WaynePrint.print("📤 AliyunOSS配置已启用，支持文件传输功能", color: "cyan")
            return CrossCommClient(
                ip: serverIP,
                port: port,
                clientId: clientId,
                heartbeatInterval: 30,
                ossEndpoint: OSS_ENDPOINT,
                ossAccessKeyId: OSS_ACCESS_KEY_ID,
                ossAccessKeySecret: OSS_ACCESS_KEY_SECRET,
                ossBucketName: OSS_BUCKET_NAME
            )
        } else {
            WaynePrint.print("⚠️  AliyunOSS未配置，文件传输功能已禁用", color: "yellow")
            WaynePrint.print("   如需启用文件传输，请在Demo代码中配置OSS参数", color: "gray")
            return CrossCommClient(
                ip: serverIP,
                port: port,
                clientId: clientId,
                heartbeatInterval: 30
            )
        }
    }
    
    // MARK: - 监听模式
    static func runListenerMode(serverIP: String, port: Int) async {
        WaynePrint.print("🎧 启动监听模式", color: "cyan")
        WaynePrint.print("服务器: \(serverIP):\(port)", color: "white")
        
        let client = createCrossCommClient(
            serverIP: serverIP,
            port: port,
            clientId: "ios_listener_\(UUID().uuidString.prefix(8))"
        )
        
        await setupAllMessageListeners(client)
        
        let connected = await client.connect()
        if !connected {
            WaynePrint.print("❌ 连接失败，请检查服务器是否运行", color: "red")
            return
        }
        
        WaynePrint.print("✅ 连接成功，开始监听消息...", color: "green")
        WaynePrint.print("按 Ctrl+C 退出", color: "yellow")
        
        // 发送上线通知
        _ = await client.sendText("📱 iOS监听客户端已上线")
        
        // 保持程序运行
        while true {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        }
    }
    
    // MARK: - 发送模式
    static func runSenderMode(serverIP: String, port: Int) async {
        WaynePrint.print("📤 启动发送模式", color: "cyan")
        WaynePrint.print("服务器: \(serverIP):\(port)", color: "white")
        
        let client = createCrossCommClient(
            serverIP: serverIP,
            port: port,
            clientId: "ios_sender_\(UUID().uuidString.prefix(8))"
        )
        
        // 也添加监听器，以便看到回复
        await setupAllMessageListeners(client)
        
        let connected = await client.connect()
        if !connected {
            WaynePrint.print("❌ 连接失败，请检查服务器是否运行", color: "red")
            return
        }
        
        WaynePrint.print("✅ 连接成功，开始发送测试消息...", color: "green")
        
        // 发送上线通知
        _ = await client.sendText("📱 iOS发送客户端已上线")
        
        await sendTestMessages(client)
        
        // 等待一段时间接收可能的回复
        WaynePrint.print("⏳ 等待10秒接收回复消息...", color: "blue")
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
        
        // 发送下线通知
        _ = await client.sendText("📱 iOS发送客户端即将下线")
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
        
        await client.disconnect()
        WaynePrint.print("👋 已断开连接", color: "yellow")
    }
    
    // MARK: - 交互模式
    static func runInteractiveMode(serverIP: String, port: Int) async {
        WaynePrint.print("🎭 启动交互模式", color: "cyan")
        WaynePrint.print("服务器: \(serverIP):\(port)", color: "white")
        
        let client = createCrossCommClient(
            serverIP: serverIP,
            port: port,
            clientId: "ios_interactive_\(UUID().uuidString.prefix(8))"
        )
        
        await setupAllMessageListeners(client)
        
        let connected = await client.connect()
        if !connected {
            WaynePrint.print("❌ 连接失败，请检查服务器是否运行", color: "red")
            return
        }
        
        WaynePrint.print("✅ 连接成功", color: "green")
        _ = await client.sendText("📱 iOS交互客户端已上线")
        
        WaynePrint.print("", color: "white")
        WaynePrint.print("🎮 交互命令:", color: "yellow")
        WaynePrint.print("  1 - 发送文本消息", color: "white")
        WaynePrint.print("  2 - 发送JSON消息", color: "white")
        WaynePrint.print("  3 - 发送字典消息", color: "white")
        WaynePrint.print("  4 - 发送字节数据", color: "white")
        WaynePrint.print("  5 - 获取客户端列表", color: "white")
        WaynePrint.print("  6 - 发送全套测试消息", color: "white")
        WaynePrint.print("  7 - 发送文件 (需要OSS配置)", color: "cyan")
        WaynePrint.print("  8 - 发送图片 (需要OSS配置)", color: "cyan")
        WaynePrint.print("  9 - 发送文件夹 (需要OSS配置)", color: "cyan")
        WaynePrint.print("  q - 退出", color: "white")
        WaynePrint.print("", color: "white")
        
        // 简单的交互循环（注意：这里使用定时器模拟交互，实际应用中可能需要其他方式处理输入）
        await startInteractiveLoop(client)
    }
    
    // MARK: - 辅助方法
    static func setupAllMessageListeners(_ client: CrossCommClient) async {
        // 文本消息监听器
        await client.addMessageListener(msgType: .text) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("📝 [\(timestamp)] 文本消息", color: "green")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            WaynePrint.print("   内容: \(message.content)", color: "white")
            WaynePrint.print("", color: "white")
        }
        
        // JSON消息监听器
        await client.addMessageListener(msgType: .json) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("📋 [\(timestamp)] JSON消息", color: "yellow")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            
            if let data = message.content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                WaynePrint.print("   内容: \(json)", color: "white")
            } else {
                WaynePrint.print("   原始: \(message.content)", color: "white")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 字典消息监听器
        await client.addMessageListener(msgType: .dict) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("📦 [\(timestamp)] 字典消息", color: "magenta")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            
            if let data = message.content.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) {
                WaynePrint.print("   内容: \(dict)", color: "white")
            } else {
                WaynePrint.print("   原始: \(message.content)", color: "white")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 字节数据监听器
        await client.addMessageListener(msgType: .bytes) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("💾 [\(timestamp)] 字节数据", color: "blue")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            
            if let data = Data(base64Encoded: message.content) {
                WaynePrint.print("   大小: \(data.count) bytes", color: "white")
                
                // 尝试转换为文本
                if let text = String(data: data, encoding: .utf8) {
                    WaynePrint.print("   文本: \(text)", color: "white")
                } else {
                    WaynePrint.print("   二进制数据 (前20字节): \(data.prefix(20))", color: "white")
                }
            } else {
                WaynePrint.print("   base64: \(String(message.content.prefix(50)))...", color: "white")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 文件监听器（配置下载目录）
        await client.addMessageListener(msgType: .file, downloadDirectory: DOWNLOAD_FILES_DIR) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("📄 [\(timestamp)] 文件消息", color: "cyan")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            WaynePrint.print("   内容路径: \(message.content)", color: "white")
            
            if let ossKey = message.ossKey {
                WaynePrint.print("   ✅ OSS Key: \(ossKey)", color: "green")
                WaynePrint.print("   🔄 文件下载应该已被触发", color: "blue")
            } else {
                WaynePrint.print("   ❌ OSS Key: nil - 文件下载未被触发", color: "red")
                WaynePrint.print("   💡 这可能是Python端发送的原始文件路径消息", color: "yellow")
            }
            
            // 尝试读取文件信息
            if FileManager.default.fileExists(atPath: message.content) {
                do {
                    let fileSize = try FileManager.default.attributesOfItem(atPath: message.content)[.size] as? Int64 ?? 0
                    WaynePrint.print("   📊 文件大小: \(fileSize) bytes", color: "white")
                    WaynePrint.print("   📂 这是发送方本地的文件", color: "gray")
                } catch {
                    WaynePrint.print("   ⚠️ 无法获取文件信息", color: "yellow")
                }
            } else {
                WaynePrint.print("   🔍 文件不存在于当前客户端本地", color: "gray")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 图片监听器（配置下载目录）
        await client.addMessageListener(msgType: .image, downloadDirectory: DOWNLOAD_IMAGES_DIR) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("🖼️ [\(timestamp)] 图片消息", color: "magenta")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            WaynePrint.print("   内容路径: \(message.content)", color: "white")
            
            if let ossKey = message.ossKey {
                WaynePrint.print("   ✅ OSS Key: \(ossKey)", color: "green")
                WaynePrint.print("   🔄 图片下载应该已被触发", color: "blue")
            } else {
                WaynePrint.print("   ❌ OSS Key: nil - 图片下载未被触发", color: "red")
                WaynePrint.print("   💡 这可能是Python端发送的原始图片路径消息", color: "yellow")
            }
            
            // 尝试读取文件信息
            if FileManager.default.fileExists(atPath: message.content) {
                do {
                    let fileSize = try FileManager.default.attributesOfItem(atPath: message.content)[.size] as? Int64 ?? 0
                    WaynePrint.print("   📊 图片大小: \(fileSize) bytes", color: "white")
                    WaynePrint.print("   📂 这是发送方本地的图片", color: "gray")
                } catch {
                    WaynePrint.print("   ⚠️ 无法获取文件信息", color: "yellow")
                }
            } else {
                WaynePrint.print("   🔍 图片不存在于当前客户端本地", color: "gray")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 文件夹监听器（配置下载目录）
        await client.addMessageListener(msgType: .folder, downloadDirectory: DOWNLOAD_FOLDERS_DIR) { message in
            let timestamp = formatTimestamp(message.timestamp)
            WaynePrint.print("📁 [\(timestamp)] 文件夹消息", color: "green")
            WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
            WaynePrint.print("   内容路径: \(message.content)", color: "white")
            
            if let ossKey = message.ossKey {
                WaynePrint.print("   ✅ OSS Key: \(ossKey)", color: "green")
                WaynePrint.print("   🔄 文件夹下载应该已被触发", color: "blue")
            } else {
                WaynePrint.print("   ❌ OSS Key: nil - 文件夹下载未被触发", color: "red")
                WaynePrint.print("   💡 这可能是Python端发送的原始文件夹路径消息", color: "yellow")
            }
            
            // 尝试读取文件夹信息
            if FileManager.default.fileExists(atPath: message.content) {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: message.content)
                    WaynePrint.print("   📊 包含文件: \(contents.count) 个", color: "white")
                    WaynePrint.print("   📂 这是发送方本地的文件夹", color: "gray")
                } catch {
                    WaynePrint.print("   ⚠️ 无法读取文件夹内容", color: "yellow")
                }
            } else {
                WaynePrint.print("   🔍 文件夹不存在于当前客户端本地", color: "gray")
            }
            WaynePrint.print("", color: "white")
        }
        
        // 通用监听器（用于调试）
        await client.addMessageListener { message in
            if ![.text, .json, .dict, .bytes, .file, .image, .folder].contains(message.msgType) {
                let timestamp = formatTimestamp(message.timestamp)
                WaynePrint.print("🌍 [\(timestamp)] 其他消息: \(message.msgType.rawValue)", color: "gray")
                WaynePrint.print("   来自: \(message.fromClientId)", color: "gray")
                WaynePrint.print("   内容: \(String(message.content.prefix(100)))", color: "gray")
                WaynePrint.print("", color: "white")
            }
        }
    }
    
    static func sendTestMessages(_ client: CrossCommClient) async {
        WaynePrint.print("🚀 开始发送测试消息序列...", color: "cyan")
        
        let delay: UInt64 = 2_000_000_000 // 2秒间隔
        
        // 1. 文本消息
        WaynePrint.print("1️⃣ 发送文本消息...", color: "blue")
        let textSuccess = await client.sendText("Hello from iOS CrossComm! 你好世界！🌍")
        WaynePrint.print("   结果: \(textSuccess ? "✅ 成功" : "❌ 失败")", color: textSuccess ? "green" : "red")
        try? await Task.sleep(nanoseconds: delay)
        
        // 2. JSON消息
        WaynePrint.print("2️⃣ 发送JSON消息...", color: "blue")
        let jsonData = [
            "type": "test_message",
            "platform": "iOS",
            "timestamp": Date().timeIntervalSince1970,
            "version": "1.0.0",
            "features": ["text", "json", "dict", "bytes"],
            "emoji": "🚀📱💻"
        ] as [String: Any]
        let jsonSuccess = await client.sendJSON(jsonData)
        WaynePrint.print("   结果: \(jsonSuccess ? "✅ 成功" : "❌ 失败")", color: jsonSuccess ? "green" : "red")
        try? await Task.sleep(nanoseconds: delay)
        
        // 3. 字典消息
        WaynePrint.print("3️⃣ 发送字典消息...", color: "blue")
        let dictData = [
            "action": "status_report",
            "client_type": "iOS",
            "status": "testing",
            "capabilities": [
                "websocket_communication": true,
                "json_parsing": true,
                "binary_data": true,
                "heartbeat": true
            ],
            "device_info": [
                "model": "iOS Device",
                "os_version": "iOS 17.0+",
                "language": "Swift"
            ]
        ] as [String: Any]
        let dictSuccess = await client.sendDict(dictData)
        WaynePrint.print("   结果: \(dictSuccess ? "✅ 成功" : "❌ 失败")", color: dictSuccess ? "green" : "red")
        try? await Task.sleep(nanoseconds: delay)
        
        // 4. 字节数据
        WaynePrint.print("4️⃣ 发送字节数据...", color: "blue")
        let binaryMessage = """
        这是一段包含中文和emoji的二进制测试数据 🎯
        Binary test data with UTF-8 encoding
        包含特殊字符: ©®™€£¥§¶†‡•…‰‹›ﬁﬂ
        """
        let binaryData = binaryMessage.data(using: .utf8)!
        let bytesSuccess = await client.sendBytes(binaryData)
        WaynePrint.print("   结果: \(bytesSuccess ? "✅ 成功" : "❌ 失败")", color: bytesSuccess ? "green" : "red")
        try? await Task.sleep(nanoseconds: delay)
        
        // 5. 获取客户端列表
        WaynePrint.print("5️⃣ 获取客户端列表...", color: "blue")
        if let clientList = await client.listClients(onlyShowOnline: true) {
            WaynePrint.print("   ✅ 成功获取客户端列表", color: "green")
            if let clients = clientList["clients"] as? [[String: Any]] {
                WaynePrint.print("   在线客户端 (\(clients.count)):", color: "cyan")
                for (index, clientInfo) in clients.enumerated() {
                    let id = clientInfo["client_id"] as? String ?? "unknown"
                    WaynePrint.print("     \(index + 1). \(id)", color: "white")
                }
            }
        } else {
            WaynePrint.print("   ❌ 获取客户端列表失败", color: "red")
        }
        try? await Task.sleep(nanoseconds: delay)
        
        // 6. 发送文件（需要OSS配置）
        WaynePrint.print("6️⃣ 发送文件测试...", color: "blue")
        if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
            let testFilePath = await createTestFile()
            if !testFilePath.isEmpty {
                let fileSuccess = await client.sendFile(testFilePath)
                WaynePrint.print("   结果: \(fileSuccess ? "✅ 成功" : "❌ 失败")", color: fileSuccess ? "green" : "red")
                if fileSuccess {
                    WaynePrint.print("   📤 文件已上传到OSS并发送", color: "cyan")
                }
            } else {
                WaynePrint.print("   ⚠️ 创建测试文件失败", color: "yellow")
            }
        } else {
            WaynePrint.print("   ⚠️ 跳过文件发送 - 需要配置OSS参数", color: "yellow")
        }
        try? await Task.sleep(nanoseconds: delay)
        
        // 7. 发送图片（需要OSS配置）
        WaynePrint.print("7️⃣ 发送图片测试...", color: "blue")
        if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
            let testImagePath = await createTestImage()
            if !testImagePath.isEmpty {
                let imageSuccess = await client.sendImage(testImagePath)
                WaynePrint.print("   结果: \(imageSuccess ? "✅ 成功" : "❌ 失败")", color: imageSuccess ? "green" : "red")
                if imageSuccess {
                    WaynePrint.print("   📤 图片已上传到OSS并发送", color: "cyan")
                }
            } else {
                WaynePrint.print("   ⚠️ 创建测试图片失败", color: "yellow")
            }
        } else {
            WaynePrint.print("   ⚠️ 跳过图片发送 - 需要配置OSS参数", color: "yellow")
        }
        try? await Task.sleep(nanoseconds: delay)
        
        // 8. 发送文件夹（需要OSS配置）
        WaynePrint.print("8️⃣ 发送文件夹测试...", color: "blue")
        if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
            let testFolderPath = await createTestFolder()
            if !testFolderPath.isEmpty {
                let folderSuccess = await client.sendFolder(testFolderPath)
                WaynePrint.print("   结果: \(folderSuccess ? "✅ 成功" : "❌ 失败")", color: folderSuccess ? "green" : "red")
                if folderSuccess {
                    WaynePrint.print("   📤 文件夹已上传到OSS并发送", color: "cyan")
                }
            } else {
                WaynePrint.print("   ⚠️ 创建测试文件夹失败", color: "yellow")
            }
        } else {
            WaynePrint.print("   ⚠️ 跳过文件夹发送 - 需要配置OSS参数", color: "yellow")
        }
        
        WaynePrint.print("", color: "white")
        WaynePrint.print("🎉 测试消息发送完成！", color: "green")
    }
    
    static func startInteractiveLoop(_ client: CrossCommClient) async {
        // 模拟交互循环，发送一些示例命令
        // 在实际应用中，这里应该读取用户输入
        
        let commands = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "q"]
        
        for (index, command) in commands.enumerated() {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒间隔
            
            WaynePrint.print("🎮 模拟执行命令: \(command)", color: "cyan")
            
            switch command {
            case "1":
                _ = await client.sendText("交互模式测试消息 \(index + 1)")
                WaynePrint.print("   📝 已发送文本消息", color: "green")
                
                        case "2":
                let json = ["interactive": true, "command": command, "index": index] as [String: Any]
                _ = await client.sendJSON(json)
                WaynePrint.print("   📋 已发送JSON消息", color: "green")
                
            case "3":
                let dict = ["mode": "interactive", "test": "dict_\(index)"]
                _ = await client.sendDict(dict)
                WaynePrint.print("   📦 已发送字典消息", color: "green")
                
            case "4":
                let data = "交互模式字节数据 \(index)".data(using: .utf8)!
                _ = await client.sendBytes(data)
                WaynePrint.print("   💾 已发送字节数据", color: "green")
                
            case "5":
                if let list = await client.listClients() {
                    let count = (list["clients"] as? [Any])?.count ?? 0
                    WaynePrint.print("   📋 客户端列表: \(count) 个在线", color: "green")
                }
                
            case "6":
                WaynePrint.print("   🚀 发送全套测试消息...", color: "green")
                await sendTestMessages(client)
                
            case "7":
                if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
                    let testFilePath = await createTestFile()
                    if !testFilePath.isEmpty {
                        let success = await client.sendFile(testFilePath)
                        WaynePrint.print("   📄 文件发送\(success ? "成功" : "失败")", color: success ? "green" : "red")
                    }
                } else {
                    WaynePrint.print("   ⚠️ 需要配置OSS参数", color: "yellow")
                }
                
            case "8":
                if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
                    let testImagePath = await createTestImage()
                    if !testImagePath.isEmpty {
                        let success = await client.sendImage(testImagePath)
                        WaynePrint.print("   🖼️ 图片发送\(success ? "成功" : "失败")", color: success ? "green" : "red")
                    }
                } else {
                    WaynePrint.print("   ⚠️ 需要配置OSS参数", color: "yellow")
                }
                
            case "9":
                if !OSS_ENDPOINT.isEmpty && !OSS_ACCESS_KEY_ID.isEmpty {
                    let testFolderPath = await createTestFolder()
                    if !testFolderPath.isEmpty {
                        let success = await client.sendFolder(testFolderPath)
                        WaynePrint.print("   📁 文件夹发送\(success ? "成功" : "失败")", color: success ? "green" : "red")
                    }
                } else {
                    WaynePrint.print("   ⚠️ 需要配置OSS参数", color: "yellow")
                }
                
            case "q":
                WaynePrint.print("   👋 退出交互模式", color: "yellow")
                _ = await client.sendText("📱 iOS交互客户端即将下线")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await client.disconnect()
                return
                
            default:
                break
            }
        }
    }
    
    static func formatTimestamp(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - 测试文件创建辅助方法
    
    static func createTestFile() async -> String {
        do {
            let fileName = "test_file_\(Int(Date().timeIntervalSince1970)).txt"
            let filePath = "./\(fileName)"
            
            let testContent = """
            📄 CrossComm iOS 测试文件
            ========================
            
            创建时间: \(Date())
            发送方: iOS CrossCommDemo
            文件类型: 文本文件
            编码: UTF-8
            
            测试内容:
            - 这是一个由iOS客户端创建的测试文件
            - 包含中文字符测试
            - 包含Emoji表情测试 🚀📱💻🌍
            - 包含特殊字符: ©®™€£¥§¶†‡•…‰‹›
            
            技术信息:
            - 平台: iOS/macOS
            - 语言: Swift
            - 通信协议: WebSocket + OSS
            - 数据格式: JSON + Binary
            
            这个文件将通过CrossComm跨平台通信系统发送到其他客户端。
            收到此文件的客户端可以验证文件传输功能是否正常工作。
            
            测试完成时间: \(Date().addingTimeInterval(5))
            """
            
            try testContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            WaynePrint.print("   📄 已创建测试文件: \(fileName)", color: "cyan")
            
            return filePath
        } catch {
            WaynePrint.print("   ❌ 创建测试文件失败: \(error)", color: "red")
            return ""
        }
    }
    
    static func createTestImage() async -> String {
        do {
            // 创建一个简单的SVG图片文件作为测试
            let fileName = "test_image_\(Int(Date().timeIntervalSince1970)).svg"
            let filePath = "./\(fileName)"
            
            let svgContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg width="200" height="150" xmlns="http://www.w3.org/2000/svg">
              <!-- 背景 -->
              <rect width="200" height="150" fill="#f0f8ff" stroke="#4169e1" stroke-width="2"/>
              
              <!-- 标题 -->
              <text x="100" y="25" text-anchor="middle" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#1e3a8a">
                CrossComm iOS
              </text>
              
              <!-- 图标 -->
              <circle cx="100" cy="70" r="25" fill="#3b82f6" stroke="#1e40af" stroke-width="2"/>
              <text x="100" y="78" text-anchor="middle" font-family="Arial, sans-serif" font-size="20" fill="white">📱</text>
              
              <!-- 信息 -->
              <text x="100" y="110" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#374151">
                测试图片
              </text>
              <text x="100" y="125" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" fill="#6b7280">
                创建时间: \(Date())
              </text>
              <text x="100" y="140" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" fill="#6b7280">
                文件传输测试
              </text>
            </svg>
            """
            
            try svgContent.write(toFile: filePath, atomically: true, encoding: .utf8)
            WaynePrint.print("   🖼️ 已创建测试图片: \(fileName)", color: "cyan")
            
            return filePath
        } catch {
            WaynePrint.print("   ❌ 创建测试图片失败: \(error)", color: "red")
            return ""
        }
    }
    
    static func createTestFolder() async -> String {
        do {
            let folderName = "test_folder_\(Int(Date().timeIntervalSince1970))"
            let folderPath = "./\(folderName)"
            
            // 创建文件夹
            try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            
            // 在文件夹中创建几个测试文件
            
            // 1. README文件
            let readmeContent = """
            # CrossComm 测试文件夹
            
            这个文件夹是由iOS CrossCommDemo客户端创建的测试文件夹。
            
            ## 内容说明
            - README.md: 说明文件
            - config.json: 配置文件示例
            - data.txt: 数据文件示例
            - subfolder/: 子文件夹示例
            
            ## 创建信息
            - 创建时间: \(Date())
            - 创建平台: iOS/macOS
            - 发送客户端: CrossCommDemo
            
            ## 测试目的
            验证CrossComm跨平台通信系统的文件夹传输功能。
            """
            try readmeContent.write(toFile: "\(folderPath)/README.md", atomically: true, encoding: .utf8)
            
            // 2. JSON配置文件
            let configData = [
                "app": "CrossComm",
                "version": "1.0.0",
                "platform": "iOS",
                "timestamp": Date().timeIntervalSince1970,
                "features": [
                    "websocket_communication",
                    "file_transfer",
                    "cross_platform",
                    "oss_storage"
                ],
                "test_data": [
                    "chinese": "中文测试",
                    "emoji": "🚀📱💻🌍",
                    "special_chars": "©®™€£¥"
                ]
            ] as [String: Any]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: configData, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try jsonString.write(toFile: "\(folderPath)/config.json", atomically: true, encoding: .utf8)
            }
            
            // 3. 数据文件
            let dataContent = """
            CrossComm iOS 测试数据
            =====================
            
            时间戳,类型,状态,备注
            \(Date().timeIntervalSince1970),file_transfer,testing,文件传输测试
            \(Date().timeIntervalSince1970 + 1),folder_transfer,testing,文件夹传输测试
            \(Date().timeIntervalSince1970 + 2),cross_platform,success,跨平台通信成功
            \(Date().timeIntervalSince1970 + 3),oss_storage,success,OSS存储成功
            
            测试完成 ✅
            """
            try dataContent.write(toFile: "\(folderPath)/data.txt", atomically: true, encoding: .utf8)
            
            // 4. 创建子文件夹
            let subfolderPath = "\(folderPath)/subfolder"
            try FileManager.default.createDirectory(atPath: subfolderPath, withIntermediateDirectories: true, attributes: nil)
            
            let subfileContent = """
            这是子文件夹中的测试文件。
            
            用于验证文件夹递归传输功能。
            创建时间: \(Date())
            """
            try subfileContent.write(toFile: "\(subfolderPath)/subfile.txt", atomically: true, encoding: .utf8)
            
            WaynePrint.print("   📁 已创建测试文件夹: \(folderName)", color: "cyan")
            WaynePrint.print("   📝 包含4个文件和1个子文件夹", color: "cyan")
            
            return folderPath
        } catch {
            WaynePrint.print("   ❌ 创建测试文件夹失败: \(error)", color: "red")
            return ""
        }
    }
} 