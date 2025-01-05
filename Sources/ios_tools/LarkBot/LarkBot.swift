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
            WaynePrint.print("获取到 tenant access token", color: "blue")
            return token
        }
        WaynePrint.print("获取 tenant access token 失败", color: "red")
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
            WaynePrint.print("获取用户信息成功", color: "green")
            return LarkListResponse(userList)
        }
        WaynePrint.print("未找到用户信息", color: "yellow")
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
            WaynePrint.print("获取群组列表成功", color: "green")
            return LarkListResponse(items)
        }
        WaynePrint.print("未找到群组", color: "yellow")
        return LarkListResponse()
    }
    
    public func getGroupChatIdByName(_ groupName: String) async throws -> [String] {
        let groups = try await getGroupList()
        let chatIds = groups.items.filter { ($0["name"] as? String) == groupName }
                    .compactMap { $0["chat_id"] as? String }
        if chatIds.isEmpty {
            WaynePrint.print("未找到名为 \(groupName) 的群组", color: "yellow")
            return []
        } else {
            WaynePrint.print("找到 \(chatIds.count) 个名为 \(groupName) 的群组", color: "green")
            return chatIds
        }
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
            WaynePrint.print("获取群成员列表成功", color: "green")
            return LarkListResponse(items)
        }
        WaynePrint.print("未找到群成员", color: "yellow")
        return LarkListResponse()
    }
    
    public func getMemberOpenIdByName(groupChatId: String, memberName: String) async throws -> [String] {
        let members = try await getMembersInGroupByGroupChatId(groupChatId)
        let memberIds = members.items.filter { ($0["name"] as? String) == memberName }
                     .compactMap { $0["member_id"] as? String }
        if memberIds.isEmpty {
            WaynePrint.print("未找到名为 \(memberName) 的成员", color: "yellow")
            return []
        } else {
            WaynePrint.print("找到 \(memberIds.count) 个名为 \(memberName) 的成员", color: "green")
            return memberIds
        }
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
            WaynePrint.print("发送消息成功", color: "green")
            return LarkResponse(responseData)
        }
        WaynePrint.print("发送消息失败", color: "red")
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
            WaynePrint.print("上传图片成功", color: "green")
            return imageKey
        }
        WaynePrint.print("上传图片失败", color: "red")
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
        WaynePrint.print("下载图片成功", color: "green")
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
            WaynePrint.print("上传文件成功", color: "green")
            return fileKey
        }
        WaynePrint.print("上传文件失败", color: "red")
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
        WaynePrint.print("下载文件成功", color: "green")
    }
} 