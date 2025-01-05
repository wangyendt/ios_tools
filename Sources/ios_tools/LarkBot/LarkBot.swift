import Foundation

/// 飞书 API 响应的可发送包装类型
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public struct LarkResponse: @unchecked Sendable {
    public let data: [String: Any]
    
    public init(_ data: [String: Any]) {
        self.data = data
    }
    
    public init() {
        self.data = [:]
    }
}

/// 飞书 API 列表响应的可发送包装类型
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public struct LarkListResponse: @unchecked Sendable {
    public let items: [[String: Any]]
    
    public init(_ items: [[String: Any]]) {
        self.items = items
    }
    
    public init() {
        self.items = []
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public actor LarkBot {
    private let appId: String
    private let appSecret: String
    private let logger = Logger()
    
    public init(appId: String, appSecret: String) {
        self.appId = appId
        self.appSecret = appSecret
    }
    
    // MARK: - Token Management
    private func getTenantAccessToken() async throws -> String {
        let url = URL(string: "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal")!
        let payload: [String: Any] = [
            "app_id": appId,
            "app_secret": appSecret
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
        throw NSError(domain: "LarkBot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get tenant access token"])
    }
    
    // MARK: - User Info
    public func getUserInfo(emails: [String], mobiles: [String]) async throws -> LarkListResponse {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/contact/v3/users/batch_get_id?user_id_type=open_id")!
        
        let payload: [String: Any] = [
            "emails": emails,
            "mobiles": mobiles,
            "include_resigned": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let data = json["data"] as? [String: Any],
           let userList = data["user_list"] as? [[String: Any]] {
            return LarkListResponse(userList)
        }
        return LarkListResponse()
    }
    
    // MARK: - Group Management
    public func getGroupList() async throws -> LarkListResponse {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/chats")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let data = json["data"] as? [String: Any],
           let items = data["items"] as? [[String: Any]] {
            return LarkListResponse(items)
        }
        return LarkListResponse()
    }
    
    public func getGroupChatIdByName(_ groupName: String) async throws -> [String] {
        let groups = try await getGroupList()
        return groups.items.filter { ($0["name"] as? String) == groupName }
                    .compactMap { $0["chat_id"] as? String }
    }
    
    public func getMembersInGroupByGroupChatId(_ groupChatId: String) async throws -> LarkListResponse {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/chats/\(groupChatId)/members")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let data = json["data"] as? [String: Any],
           let items = data["items"] as? [[String: Any]] {
            return LarkListResponse(items)
        }
        return LarkListResponse()
    }
    
    public func getMemberOpenIdByName(groupChatId: String, memberName: String) async throws -> [String] {
        let members = try await getMembersInGroupByGroupChatId(groupChatId)
        return members.items.filter { ($0["name"] as? String) == memberName }
                     .compactMap { $0["member_id"] as? String }
    }
    
    // MARK: - Message Sending
    private func sendMessage(receiveIdType: String, receiveId: String, msgType: String, content: String) async throws -> LarkResponse {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=\(receiveIdType)")!
        
        let payload: [String: Any] = [
            "receive_id": receiveId,
            "msg_type": msgType,
            "content": content
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseData = json["data"] as? [String: Any] {
            return LarkResponse(responseData)
        }
        return LarkResponse()
    }
    
    // Text Messages
    public func sendTextToUser(userOpenId: String, text: String) async throws -> LarkResponse {
        let content = ["text": text]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "text", content: jsonContent)
    }
    
    public func sendTextToChat(chatId: String, text: String) async throws -> LarkResponse {
        let content = ["text": text]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "text", content: jsonContent)
    }
    
    // Image Messages
    public func sendImageToUser(userOpenId: String, imageKey: String) async throws -> LarkResponse {
        let content = ["image_key": imageKey]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "image", content: jsonContent)
    }
    
    public func sendImageToChat(chatId: String, imageKey: String) async throws -> LarkResponse {
        let content = ["image_key": imageKey]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "image", content: jsonContent)
    }
    
    // Interactive Messages
    public func sendInteractiveToUser(userOpenId: String, interactive: [String: Any]) async throws -> LarkResponse {
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: interactive), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "interactive", content: jsonContent)
    }
    
    public func sendInteractiveToChat(chatId: String, interactive: [String: Any]) async throws -> LarkResponse {
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: interactive), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "interactive", content: jsonContent)
    }
    
    // Share Messages
    public func sendSharedChatToUser(userOpenId: String, sharedChatId: String) async throws -> LarkResponse {
        let content = ["chat_id": sharedChatId]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "share_chat", content: jsonContent)
    }
    
    public func sendSharedChatToChat(chatId: String, sharedChatId: String) async throws -> LarkResponse {
        let content = ["chat_id": sharedChatId]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "share_chat", content: jsonContent)
    }
    
    public func sendSharedUserToUser(userOpenId: String, sharedUserId: String) async throws -> LarkResponse {
        let content = ["user_id": sharedUserId]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "share_user", content: jsonContent)
    }
    
    public func sendSharedUserToChat(chatId: String, sharedUserId: String) async throws -> LarkResponse {
        let content = ["user_id": sharedUserId]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "share_user", content: jsonContent)
    }
    
    // File Messages
    public func sendFileToUser(userOpenId: String, fileKey: String) async throws -> LarkResponse {
        let content = ["file_key": fileKey]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "file", content: jsonContent)
    }
    
    public func sendFileToChat(chatId: String, fileKey: String) async throws -> LarkResponse {
        let content = ["file_key": fileKey]
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: content), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "file", content: jsonContent)
    }
    
    // Post Messages
    public func sendPostToUser(userOpenId: String, postContent: [String: Any]) async throws -> LarkResponse {
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: postContent), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "open_id", receiveId: userOpenId, msgType: "post", content: jsonContent)
    }
    
    public func sendPostToChat(chatId: String, postContent: [String: Any]) async throws -> LarkResponse {
        let jsonContent = String(data: try JSONSerialization.data(withJSONObject: postContent), encoding: .utf8) ?? ""
        return try await sendMessage(receiveIdType: "chat_id", receiveId: chatId, msgType: "post", content: jsonContent)
    }
    
    // File Upload/Download
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
            return imageKey
        }
        return ""
    }
    
    public func downloadImage(imageKey: String, imageSavePath: String) async throws {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/images/\(imageKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        try data.write(to: URL(fileURLWithPath: imageSavePath))
    }
    
    public func uploadFile(filePath: String, fileType: String = "stream") async throws -> String {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/files")!
        
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var bodyData = Data()
        // Add file_type
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file_type\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(fileType)\r\n".data(using: .utf8)!)
        
        // Add file_name
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file_name\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(fileName)\r\n".data(using: .utf8)!)
        
        // Add file data
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        bodyData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        bodyData.append(fileData)
        bodyData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = bodyData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseData = json["data"] as? [String: Any],
           let fileKey = responseData["file_key"] as? String {
            return fileKey
        }
        return ""
    }
    
    public func downloadFile(fileKey: String, fileSavePath: String) async throws {
        let token = try await getTenantAccessToken()
        let url = URL(string: "https://open.feishu.cn/open-apis/im/v1/files/\(fileKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        try data.write(to: URL(fileURLWithPath: fileSavePath))
    }
} 