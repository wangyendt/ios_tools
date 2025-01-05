import Foundation
import CryptoKit

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public actor LarkCustomBot {
    private let webhook: String
    private let secret: String
    private let botAppId: String
    private let botSecret: String
    
    public init(webhook: String, secret: String, botAppId: String, botSecret: String) {
        self.webhook = webhook
        self.secret = secret
        self.botAppId = botAppId
        self.botSecret = botSecret
    }
    
    private func sign(_ timestamp: Int64) -> String {
        let stringToSign = "\(timestamp)\n\(secret)"
        let key = SymmetricKey(data: secret.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        return Data(signature).base64EncodedString()
    }
    
    private func sendRequest(payload: [String: Any]) async throws -> [String: Any] {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let sign = sign(timestamp)
        
        var request = URLRequest(url: URL(string: webhook)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(timestamp)", forHTTPHeaderField: "X-Lark-Request-Timestamp")
        request.setValue(sign, forHTTPHeaderField: "X-Lark-Request-Sign")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let code = json["code"] as? Int, code == 0 {
                WaynePrint.print("请求成功", color: "green")
                return json
            } else if let msg = json["msg"] as? String {
                WaynePrint.print("请求失败: \(msg)", color: "red")
                throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
            } else {
                WaynePrint.print("请求失败: 未知错误", color: "red")
                throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            }
        }
        WaynePrint.print("请求失败: 未知错误", color: "red")
        throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }
    
    public func sendText(_ text: String) async throws {
        let payload: [String: Any] = [
            "msg_type": "text",
            "content": ["text": text]
        ]
        _ = try await sendRequest(payload: payload)
        WaynePrint.print("发送文本消息成功", color: "green")
    }
    
    public func sendPost(content: [[Any]], title: String) async throws {
        let payload: [String: Any] = [
            "msg_type": "post",
            "content": [
                "post": [
                    "zh_cn": [
                        "title": title,
                        "content": content
                    ]
                ]
            ]
        ]
        _ = try await sendRequest(payload: payload)
        WaynePrint.print("发送富文本消息成功", color: "green")
    }
    
    public func uploadImage(filePath: String) async throws -> String {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images")!
        
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let imageData = try Data(contentsOf: fileURL)
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var bodyData = Data()
        // Add image_type
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"image_type\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("message\r\n".data(using: .utf8)!)
        
        // Add image data
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
            WaynePrint.print("上传图片成功", color: "green")
            return imageKey
        } else {
            WaynePrint.print("上传图片失败", color: "red")
            return ""
        }
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
            WaynePrint.print("获取到 tenant access token", color: "blue")
            return token
        } else {
            WaynePrint.print("获取 tenant access token 失败", color: "red")
            throw NSError(domain: "LarkCustomBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get tenant access token"])
        }
    }
    
    public func sendImage(imageKey: String) async throws {
        let payload: [String: Any] = [
            "msg_type": "image",
            "content": ["image_key": imageKey]
        ]
        _ = try await sendRequest(payload: payload)
        WaynePrint.print("发送图片消息成功", color: "green")
    }
} 