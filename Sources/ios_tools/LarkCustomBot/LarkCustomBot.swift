import Foundation
import CommonCrypto

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public actor LarkCustomBot {
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
    public func sendText(_ text: String, mentionAll: Bool = false) async {
        let content: [String: Any] = [
            "text": mentionAll ? "\(text) <at user_id=\"all\">所有人</at>" : text
        ]
        
        let data: [String: Any] = [
            "msg_type": "text",
            "content": content
        ]
        
        await sendRequest(data)
    }
    
    // 发送富文本消息
    public func sendPost(content: [[Any]], title: String) async {
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
        
        await sendRequest(data)
    }
    
    // 发送群名片
    public func sendShareChat(shareChatId: String) async {
        let data: [String: Any] = [
            "msg_type": "share_chat",
            "content": ["share_chat_id": shareChatId]
        ]
        
        await sendRequest(data)
    }
    
    // 发送图片
    public func sendImage(imageKey: String) async {
        let data: [String: Any] = [
            "msg_type": "image",
            "content": ["image_key": imageKey]
        ]
        
        await sendRequest(data)
    }
    
    // 发送消息卡片
    public func sendInteractive(card: [String: Any]) async {
        let data: [String: Any] = [
            "msg_type": "interactive",
            "card": card
        ]
        
        await sendRequest(data)
    }
    
    // 上传图片
    public func uploadImage(filePath: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: filePath),
              !botAppId.isEmpty, !botSecret.isEmpty else {
            await logger.warning("Image file does not exist or bot credentials missing")
            return ""
        }
        
        let token = try await getTenantAccessToken()
        guard !token.isEmpty else { return "" }
        
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images")!
        
        do {
            let fileURL = URL(fileURLWithPath: filePath)
            let fileName = fileURL.lastPathComponent
            let imageData = try Data(contentsOf: fileURL)
            
            let boundary = UUID().uuidString
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var bodyData = Data()
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"image_type\"\r\n\r\n".data(using: .utf8)!)
            bodyData.append("message\r\n".data(using: .utf8)!)
            
            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            bodyData.append(imageData)
            bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = bodyData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let imageKey = responseData["image_key"] as? String {
                return imageKey
            }
        } catch {
            await logger.error("Failed to upload image: \(error.localizedDescription)")
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
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["tenant_access_token"] as? String {
            return token
        }
        throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get tenant access token"])
    }
    
    private func sendRequest(_ data: [String: Any]) async {
        do {
            var requestData = data
            if !secret.isEmpty {
                let timestamp = Int(Date().timeIntervalSince1970)
                requestData["timestamp"] = timestamp
            }
            
            guard let url = URL(string: webhook) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                if json["code"] != nil {
                    await logger.warning("Message sending failed: \(json)")
                } else if let statusCode = json["StatusCode"] as? Int, statusCode == 0 {
                    await logger.info("Message sent successfully")
                }
            }
        } catch {
            await logger.error("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    private func generateSignature(timestamp: Int, secret: String) -> String {
        let stringToSign = "\(timestamp)\n\(secret)"
        guard let data = stringToSign.data(using: .utf8),
              let keyData = secret.data(using: .utf8) else {
            return ""
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                      keyPtr.baseAddress,
                      keyData.count,
                      dataPtr.baseAddress,
                      data.count,
                      &digest)
            }
        }
        
        return Data(digest).base64EncodedString()
    }
}

// 辅助方法
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public extension LarkCustomBot {
    static func createTextContent(text: String, unescape: Bool = false) -> [String: Any] {
        return [
            "tag": "text",
            "text": text,
            "un_escape": unescape
        ]
    }
    
    static func createLinkContent(href: String, text: String) -> [String: Any] {
        return [
            "tag": "a",
            "href": href,
            "text": text
        ]
    }
    
    static func createAtContent(userId: String, userName: String) -> [String: Any] {
        return [
            "tag": "at",
            "user_id": userId,
            "user_name": userName
        ]
    }
    
    static func createImageContent(imageKey: String, width: Int? = nil, height: Int? = nil) -> [String: Any] {
        var content: [String: Any] = [
            "tag": "img",
            "image_key": imageKey
        ]
        if let width = width { content["width"] = width }
        if let height = height { content["height"] = height }
        return content
    }
} 