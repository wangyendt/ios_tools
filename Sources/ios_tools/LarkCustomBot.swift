import Foundation
import CryptoKit

public class LarkCustomBot {
    private let webhook: String
    private let secret: String
    private let botAppId: String
    private let botSecret: String
    private let logger = Logger()
    
    public init(webhook: String, secret: String, botAppId: String, botSecret: String) {
        self.webhook = webhook
        self.secret = secret
        self.botAppId = botAppId
        self.botSecret = botSecret
    }
    
    // 发送文本消息
    public func sendText(_ text: String, mentionAll: Bool = false) {
        let content: [String: Any] = [
            "text": mentionAll ? "\(text) <at user_id=\"all\">所有人</at>" : text
        ]
        
        let data: [String: Any] = [
            "msg_type": "text",
            "content": content
        ]
        
        sendRequest(data)
    }
    
    // 发送富文本消息
    public func sendPost(content: [[Any]], title: String) {
        let postContent: [String: Any] = [
            "title": title,
            "content": content
        ]
        
        let zhCn: [String: Any] = [
            "zh_cn": postContent
        ]
        
        let data: [String: Any] = [
            "msg_type": "post",
            "content": ["post": zhCn]
        ]
        
        sendRequest(data)
    }
    
    // 发送群名片
    public func sendShareChat(shareChatId: String) {
        let data: [String: Any] = [
            "msg_type": "share_chat",
            "content": ["share_chat_id": shareChatId]
        ]
        
        sendRequest(data)
    }
    
    // 发送图片
    public func sendImage(imageKey: String) {
        let data: [String: Any] = [
            "msg_type": "image",
            "content": ["image_key": imageKey]
        ]
        
        sendRequest(data)
    }
    
    // 发送消息卡片
    public func sendInteractive(card: [String: Any]) {
        let data: [String: Any] = [
            "msg_type": "interactive",
            "card": card
        ]
        
        sendRequest(data)
    }
    
    // 上传图片
    public func uploadImage(filePath: String) async -> String {
        guard FileManager.default.fileExists(atPath: filePath),
              !botAppId.isEmpty, !botSecret.isEmpty else {
            logger.warning("Image file does not exist or bot credentials missing")
            return ""
        }
        
        do {
            let tenantAccessToken = try await getTenantAccessToken()
            let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images")!
            
            let fileURL = URL(fileURLWithPath: filePath)
            let fileName = fileURL.lastPathComponent
            let imageData = try Data(contentsOf: fileURL)
            
            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(tenantAccessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var bodyData = Data()
            // 添加image_type字段
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"image_type\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("message\r\n".data(using: .utf8)!)
            
            // 添加图片数据
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            bodyData.append(imageData)
            bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = bodyData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let imageKey = responseData["image_key"] as? String {
                return imageKey
            }
        } catch {
            logger.error("Failed to upload image: \(error.localizedDescription)")
        }
        return ""
    }
    
    private func getTenantAccessToken() async throws -> String {
        let url = URL(string: "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal")!
        let payload: [String: Any] = [
            "app_id": botAppId,
            "app_secret": botSecret
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["tenant_access_token"] as? String {
            return token
        }
        throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get tenant access token"])
    }
    
    private func sendRequest(_ data: [String: Any]) {
        Task {
            do {
                var requestData = data
                if !secret.isEmpty {
                    let timestamp = Int(Date().timeIntervalSince1970)
                    requestData["timestamp"] = timestamp
                    // 如果需要，这里可以添加签名逻辑
                }
                
                guard let url = URL(string: webhook) else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if json["code"] != nil {
                        logger.warning("Message sending failed: \(json)")
                    } else if let statusCode = json["StatusCode"] as? Int, statusCode == 0 {
                        logger.info("Message sent successfully")
                    }
                }
            } catch {
                logger.error("Failed to send message: \(error.localizedDescription)")
            }
        }
    }
    
    private func generateSignature(timestamp: Int, secret: String) -> String {
        let stringToSign = "\(timestamp)\n\(secret)"
        if let data = stringToSign.data(using: .utf8) {
            let key = SymmetricKey(data: secret.data(using: .utf8)!)
            let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
            return Data(signature).base64EncodedString()
        }
        return ""
    }
}

// 辅助方法
extension LarkCustomBot {
    public static func createTextContent(text: String, unescape: Bool = false) -> [String: Any] {
        return [
            "tag": "text",
            "text": text,
            "un_escape": unescape
        ]
    }
    
    public static func createLinkContent(href: String, text: String) -> [String: Any] {
        return [
            "tag": "a",
            "href": href,
            "text": text
        ]
    }
    
    public static func createAtContent(userId: String, userName: String) -> [String: Any] {
        return [
            "tag": "at",
            "user_id": userId,
            "user_name": userName
        ]
    }
    
    public static func createImageContent(imageKey: String, width: Int? = nil, height: Int? = nil) -> [String: Any] {
        var content: [String: Any] = [
            "tag": "img",
            "image_key": imageKey
        ]
        if let width = width { content["width"] = width }
        if let height = height { content["height"] = height }
        return content
    }
}

// 简单的日志类
private class Logger {
    func info(_ message: String) {
        print("INFO: \(message)")
    }
    
    func warning(_ message: String) {
        print("WARNING: \(message)")
    }
    
    func error(_ message: String) {
        print("ERROR: \(message)")
    }
} 