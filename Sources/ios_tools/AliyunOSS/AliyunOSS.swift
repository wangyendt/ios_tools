import Foundation
import CryptoKit

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
public actor AliyunOSS {
    private let endpoint: String
    private let bucketName: String
    private let apiKey: String?
    private let apiSecret: String?
    private let verbose: Bool
    private let hasWritePermission: Bool
    
    public init(endpoint: String, bucketName: String, apiKey: String? = nil, apiSecret: String? = nil, verbose: Bool = true) {
        self.endpoint = endpoint
        self.bucketName = bucketName
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.verbose = verbose
        self.hasWritePermission = apiKey != nil && apiSecret != nil
    }
    
    private func printInfo(_ message: String) {
        if verbose {
            WaynePrint.print(message, color: "green")
        }
    }
    
    private func printWarning(_ message: String) {
        if verbose {
            WaynePrint.print("WARNING: " + message, color: "yellow")
        }
    }
    
    private func printError(_ message: String) {
        if verbose {
            WaynePrint.print("ERROR: " + message, color: "red")
        }
    }
    
    private func checkWritePermission() -> Bool {
        if !hasWritePermission {
            printWarning("没有写入权限：未提供 API Key 或 API Secret")
            return false
        }
        return true
    }
    
    private func sign(_ content: String) -> String {
        guard let apiSecret = apiSecret else { return "" }
        let key = apiSecret.data(using: .utf8)!
        let message = content.data(using: .utf8)!
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: .init(data: key))
        return Data(signature).base64EncodedString()
    }
    
    private func getAuthorizationHeader(method: String, contentType: String = "", contentMD5: String = "", date: String, resource: String) -> String {
        guard let apiKey = apiKey else { return "" }
        
        let canonicalizedResource = resource.isEmpty ? "/\(bucketName)/" : "/\(bucketName)/\(resource)"
        let stringToSign = [
            method,
            contentMD5,
            contentType,
            date,
            canonicalizedResource
        ].joined(separator: "\n")
        
        let signature = sign(stringToSign)
        return "OSS \(apiKey):\(signature)"
    }
    
    private func getDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: Date())
    }
    
    private func getBaseURL() -> String {
        return "https://\(bucketName).\(endpoint)"
    }
    
    public func downloadFile(key: String, rootDir: String? = nil) async throws -> Bool {
        let savePath: String
        if let rootDir = rootDir {
            savePath = (rootDir as NSString).appendingPathComponent(key)
        } else {
            savePath = key
        }
        
        // 创建必要的目录
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: savePath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "GET", date: date, resource: key)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "GET"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            try data.write(to: URL(fileURLWithPath: savePath))
            printInfo("成功下载文件：\(key) -> \(savePath)")
            return true
        } catch {
            printWarning("下载文件失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func uploadFile(key: String, filePath: String) async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            printWarning("文件不存在：\(filePath)")
            return false
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let contentMD5 = calculateMD5(data: fileData)
        let date = getDate()
        let authorization = getAuthorizationHeader(
            method: "PUT",
            contentType: "application/octet-stream",
            contentMD5: contentMD5,
            date: date,
            resource: key
        )
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(contentMD5, forHTTPHeaderField: "Content-MD5")
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = fileData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    printInfo("成功上传文件：\(key)")
                    return true
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("上传文件失败：\(errorMessage)")
                    return false
                }
            } else {
                printWarning("上传文件失败：服务器返回错误")
                return false
            }
        } catch {
            printWarning("上传文件失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func uploadText(key: String, text: String) async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        let data = text.data(using: .utf8)!
        let contentMD5 = calculateMD5(data: data)
        let date = getDate()
        let authorization = getAuthorizationHeader(
            method: "PUT",
            contentType: "text/plain",
            contentMD5: contentMD5,
            date: date,
            resource: key
        )
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "PUT"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue(contentMD5, forHTTPHeaderField: "Content-MD5")
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    printInfo("成功上传文本：\(key)")
                    return true
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("上传文本失败：\(errorMessage)")
                    return false
                }
            } else {
                printWarning("上传文本失败：服务器返回错误")
                return false
            }
        } catch {
            printWarning("上传文本失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func deleteFile(key: String) async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "DELETE", date: date, resource: key)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "DELETE"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    printInfo("成功删除文件：\(key)")
                    return true
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("删除文件失败：\(errorMessage)")
                    return false
                }
            } else {
                printWarning("删除文件失败：服务器返回错误")
                return false
            }
        } catch {
            printWarning("删除文件失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func listAllKeys(sort: Bool = true) async throws -> [String] {
        var keys: [String] = []
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "GET", date: date, resource: "")
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/?max-keys=1000")!)
        request.httpMethod = "GET"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    let xmlString = String(data: data, encoding: .utf8) ?? ""
                    let keyPattern = "<Key>(.*?)</Key>"
                    if let regex = try? NSRegularExpression(pattern: keyPattern) {
                        let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
                        keys = matches.compactMap { match in
                            if let range = Range(match.range(at: 1), in: xmlString) {
                                return String(xmlString[range])
                            }
                            return nil
                        }
                        if sort {
                            keys.sort()
                        }
                        printInfo("成功获取所有 key，共 \(keys.count) 个")
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("获取文件列表失败：\(errorMessage)")
                }
            } else {
                printWarning("获取文件列表失败：服务器返回错误")
            }
        } catch {
            printWarning("获取文件列表失败：\(error.localizedDescription)")
        }
        
        return keys
    }
    
    public func listKeysWithPrefix(_ prefix: String, sort: Bool = true) async throws -> [String] {
        var keys: [String] = []
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "GET", date: date, resource: "")
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/?prefix=\(prefix)&max-keys=1000")!)
        request.httpMethod = "GET"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    let xmlString = String(data: data, encoding: .utf8) ?? ""
                    let keyPattern = "<Key>(.*?)</Key>"
                    if let regex = try? NSRegularExpression(pattern: keyPattern) {
                        let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
                        keys = matches.compactMap { match in
                            if let range = Range(match.range(at: 1), in: xmlString) {
                                return String(xmlString[range])
                            }
                            return nil
                        }
                        if sort {
                            keys.sort()
                        }
                        printInfo("成功获取前缀为 \(prefix) 的 key，共 \(keys.count) 个")
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("获取文件列表失败：\(errorMessage)")
                }
            } else {
                printWarning("获取文件列表失败：服务器返回错误")
            }
        } catch {
            printWarning("获取文件列表失败：\(error.localizedDescription)")
        }
        
        return keys
    }
    
    public func deleteFilesWithPrefix(_ prefix: String) async throws -> Bool {
        let keys = try await listKeysWithPrefix(prefix)
        var success = true
        
        for key in keys {
            if !(try await deleteFile(key: key)) {
                success = false
            }
        }
        
        return success
    }
    
    public func downloadFilesWithPrefix(_ prefix: String, rootDir: String? = nil) async throws -> Bool {
        let keys = try await listKeysWithPrefix(prefix)
        var success = true
        
        for key in keys {
            if !(try await downloadFile(key: key, rootDir: rootDir)) {
                success = false
            }
        }
        
        return success
    }
    
    private func calculateMD5(data: Data) -> String {
        let hash = Insecure.MD5.hash(data: data)
        return Data(hash).base64EncodedString()
    }
    
    public func uploadDirectory(localPath: String, prefix: String = "") async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: localPath) else {
            printWarning("无法访问目录：\(localPath)")
            return false
        }
        
        var success = true
        while let filePath = enumerator.nextObject() as? String {
            let fullPath = (localPath as NSString).appendingPathComponent(filePath)
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue { continue }
            
            let key = prefix.isEmpty ? filePath : (prefix as NSString).appendingPathComponent(filePath)
            if try await uploadFile(key: key, filePath: fullPath) == false {
                success = false
            }
        }
        
        return success
    }
    
    public func downloadDirectory(prefix: String, localPath: String) async throws -> Bool {
        let keys = try await listKeysWithPrefix(prefix)
        guard !keys.isEmpty else {
            printWarning("未找到前缀为 \(prefix) 的文件")
            return false
        }
        
        var success = true
        for key in keys {
            if try await downloadFile(key: key, rootDir: localPath) == false {
                success = false
            }
        }
        
        return success
    }
    
    public func listDirectoryContents(_ prefix: String, sort: Bool = true) async throws -> [(name: String, isDirectory: Bool)] {
        var contents: [(name: String, isDirectory: Bool)] = []
        let normalizedPrefix = prefix.hasSuffix("/") ? prefix : prefix + "/"
        
        // 获取所有以该前缀开头的文件
        let allKeys = try await listKeysWithPrefix(normalizedPrefix)
        
        // 处理每个 key
        for key in allKeys {
            // 移除前缀，得到相对路径
            let relativePath = String(key.dropFirst(normalizedPrefix.count))
            let components = relativePath.components(separatedBy: "/")
            
            // 只处理第一级目录下的内容
            if components.count > 0 && components[0].count > 0 {
                if components.count == 1 {
                    // 这是一个文件
                    contents.append((name: components[0], isDirectory: false))
                } else {
                    // 这是一个目录
                    let dirName = components[0]
                    // 检查是否已经添加过这个目录
                    if !contents.contains(where: { $0.name == dirName }) {
                        contents.append((name: dirName, isDirectory: true))
                    }
                }
            }
        }
        
        if sort {
            // 先按类型排序（目录在前），再按名称排序
            contents.sort { (a, b) in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name < b.name
            }
        }
        
        printInfo("成功获取目录 '\(normalizedPrefix)' 的内容，共 \(contents.count) 项")
        return contents
    }
} 