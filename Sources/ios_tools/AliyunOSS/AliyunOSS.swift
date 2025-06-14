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
    
    public func downloadFile(key: String, rootDir: String? = nil, useBasename: Bool = false) async throws -> Bool {
        let savePath: String
        if let rootDir = rootDir {
            if useBasename {
                let filename = (key as NSString).lastPathComponent
                savePath = (rootDir as NSString).appendingPathComponent(filename)
            } else {
                savePath = (rootDir as NSString).appendingPathComponent(key)
            }
        } else {
            if useBasename {
                savePath = (key as NSString).lastPathComponent
            } else {
                savePath = key
            }
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
        var marker: String? = nil
        
        repeat {
            let date = getDate()
            let authorization = getAuthorizationHeader(method: "GET", date: date, resource: "")
            
            var urlString = "\(getBaseURL())/?max-keys=1000"
            if let marker = marker {
                urlString += "&marker=\(marker)"
            }
            
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "GET"
            request.setValue(date, forHTTPHeaderField: "Date")
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        let xmlString = String(data: data, encoding: .utf8) ?? ""
                        
                        // 解析所有的 Key
                        let keyPattern = "<Key>(.*?)</Key>"
                        if let regex = try? NSRegularExpression(pattern: keyPattern) {
                            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
                            let newKeys = matches.compactMap { match in
                                if let range = Range(match.range(at: 1), in: xmlString) {
                                    return String(xmlString[range])
                                }
                                return nil
                            }
                            keys.append(contentsOf: newKeys)
                        }
                        
                        // 检查是否有下一页
                        let isTruncatedPattern = "<IsTruncated>(true|false)</IsTruncated>"
                        let nextMarkerPattern = "<NextMarker>(.*?)</NextMarker>"
                        
                        if let regex = try? NSRegularExpression(pattern: isTruncatedPattern),
                           let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                           let range = Range(match.range(at: 1), in: xmlString),
                           xmlString[range] == "true",
                           let markerRegex = try? NSRegularExpression(pattern: nextMarkerPattern),
                           let markerMatch = markerRegex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                           let markerRange = Range(markerMatch.range(at: 1), in: xmlString) {
                            marker = String(xmlString[markerRange])
                        } else {
                            marker = nil
                        }
                        
                    } else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                        printWarning("获取文件列表失败：\(errorMessage)")
                        break
                    }
                } else {
                    printWarning("获取文件列表失败：服务器返回错误")
                    break
                }
            } catch {
                printWarning("获取文件列表失败：\(error.localizedDescription)")
                break
            }
        } while marker != nil
        
        if sort {
            keys.sort()
        }
        
        printInfo("成功获取所有 key，共 \(keys.count) 个")
        return keys
    }
    
    public func listKeysWithPrefix(_ prefix: String, sort: Bool = true) async throws -> [String] {
        var keys: [String] = []
        var marker: String? = nil
        
        repeat {
            let date = getDate()
            let authorization = getAuthorizationHeader(method: "GET", date: date, resource: "")
            
            var urlString = "\(getBaseURL())/?prefix=\(prefix)&max-keys=1000"
            if let marker = marker {
                urlString += "&marker=\(marker)"
            }
            
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "GET"
            request.setValue(date, forHTTPHeaderField: "Date")
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        let xmlString = String(data: data, encoding: .utf8) ?? ""
                        
                        // 解析所有的 Key
                        let keyPattern = "<Key>(.*?)</Key>"
                        if let regex = try? NSRegularExpression(pattern: keyPattern) {
                            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
                            let newKeys = matches.compactMap { match in
                                if let range = Range(match.range(at: 1), in: xmlString) {
                                    return String(xmlString[range])
                                }
                                return nil
                            }
                            keys.append(contentsOf: newKeys)
                        }
                        
                        // 检查是否有下一页
                        let isTruncatedPattern = "<IsTruncated>(true|false)</IsTruncated>"
                        let nextMarkerPattern = "<NextMarker>(.*?)</NextMarker>"
                        
                        if let regex = try? NSRegularExpression(pattern: isTruncatedPattern),
                           let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                           let range = Range(match.range(at: 1), in: xmlString),
                           xmlString[range] == "true",
                           let markerRegex = try? NSRegularExpression(pattern: nextMarkerPattern),
                           let markerMatch = markerRegex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                           let markerRange = Range(markerMatch.range(at: 1), in: xmlString) {
                            marker = String(xmlString[markerRange])
                        } else {
                            marker = nil
                        }
                        
                    } else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                        printWarning("获取文件列表失败：\(errorMessage)")
                        break
                    }
                } else {
                    printWarning("获取文件列表失败：服务器返回错误")
                    break
                }
            } catch {
                printWarning("获取文件列表失败：\(error.localizedDescription)")
                break
            }
        } while marker != nil
        
        if sort {
            keys.sort()
        }
        
        printInfo("成功获取前缀为 \(prefix) 的 key，共 \(keys.count) 个")
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
    
    public func downloadFilesWithPrefix(_ prefix: String, rootDir: String? = nil, useBasename: Bool = false) async throws -> Bool {
        let keys = try await listKeysWithPrefix(prefix)
        var success = true
        
        for key in keys {
            if !(try await downloadFile(key: key, rootDir: rootDir, useBasename: useBasename)) {
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
    
    public func downloadDirectory(prefix: String, localPath: String, useBasename: Bool = false) async throws -> Bool {
        let keys = try await listKeysWithPrefix(prefix)
        guard !keys.isEmpty else {
            printWarning("未找到前缀为 \(prefix) 的文件")
            return false
        }
        
        var success = true
        for key in keys {
            if try await downloadFile(key: key, rootDir: localPath, useBasename: useBasename) == false {
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
    
    public func readFileContent(key: String) async throws -> String? {
        // 检查是否为文件夹（通过检查是否以'/'结尾）
        if key.hasSuffix("/") {
            printWarning("指定的键值 '\(key)' 是一个文件夹")
            return nil
        }
        
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "GET", date: date, resource: key)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "GET"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            // 检查是否为文件夹（通过检查是否有子文件）
            let dirContents = try await listKeysWithPrefix(key + "/")
            if !dirContents.isEmpty {
                printWarning("指定的键值 '\(key)' 是一个文件夹")
                return nil
            }
            
            // 获取文件内容
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    if let content = String(data: data, encoding: .utf8) {
                        printInfo("成功读取文件内容：\(key)")
                        return content
                    } else {
                        printWarning("文件内容解码失败")
                        return nil
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    printWarning("读取文件失败：\(errorMessage)")
                    return nil
                }
            } else {
                printWarning("读取文件失败：服务器返回错误")
                return nil
            }
        } catch {
            printWarning("读取文件失败：\(error.localizedDescription)")
            return nil
        }
    }
    
    public func keyExists(key: String) async throws -> Bool {
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "HEAD", date: date, resource: key)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "HEAD"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    printInfo("文件存在：\(key)")
                    return true
                } else {
                    printInfo("文件不存在：\(key)")
                    return false
                }
            } else {
                printWarning("检查文件失败：服务器返回错误")
                return false
            }
        } catch {
            printWarning("检查文件失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func getFileMetadata(key: String) async throws -> [String: Any]? {
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "HEAD", date: date, resource: key)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(key)")!)
        request.httpMethod = "HEAD"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    var metadata: [String: Any] = [:]
                    
                    // 处理响应头
                    for (headerKey, headerValue) in httpResponse.allHeaderFields {
                        if let key = headerKey as? String, let value = headerValue as? String {
                            metadata[key] = value
                        }
                    }
                    
                    // 添加文件大小
                    metadata["content_length"] = httpResponse.expectedContentLength
                    
                    printInfo("成功获取文件元数据：\(key)")
                    return metadata
                } else {
                    printWarning("获取文件元数据失败：文件不存在或权限不足")
                    return nil
                }
            } else {
                printWarning("获取文件元数据失败：服务器返回错误")
                return nil
            }
        } catch {
            printWarning("获取文件元数据失败：\(error.localizedDescription)")
            return nil
        }
    }
    
    public func copyObject(sourceKey: String, targetKey: String) async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        // 首先检查源文件是否存在
        if !(try await keyExists(key: sourceKey)) {
            printWarning("复制失败：源文件不存在 \(sourceKey)")
            return false
        }
        
        // 获取源文件内容
        let date = getDate()
        let authorization = getAuthorizationHeader(method: "GET", date: date, resource: sourceKey)
        
        var request = URLRequest(url: URL(string: "\(getBaseURL())/\(sourceKey)")!)
        request.httpMethod = "GET"
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        
        do {
            // 下载源文件
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                printWarning("复制失败：无法读取源文件内容")
                return false
            }
            
            // 上传到新位置
            let contentMD5 = calculateMD5(data: data)
            let uploadDate = getDate()
            let uploadAuthorization = getAuthorizationHeader(
                method: "PUT",
                contentType: "application/octet-stream",
                contentMD5: contentMD5,
                date: uploadDate,
                resource: targetKey
            )
            
            var uploadRequest = URLRequest(url: URL(string: "\(getBaseURL())/\(targetKey)")!)
            uploadRequest.httpMethod = "PUT"
            uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            uploadRequest.setValue(contentMD5, forHTTPHeaderField: "Content-MD5")
            uploadRequest.setValue(uploadDate, forHTTPHeaderField: "Date")
            uploadRequest.setValue(uploadAuthorization, forHTTPHeaderField: "Authorization")
            uploadRequest.httpBody = data
            
            let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
            if let uploadHttpResponse = uploadResponse as? HTTPURLResponse {
                if (200...299).contains(uploadHttpResponse.statusCode) {
                    printInfo("成功复制文件：\(sourceKey) -> \(targetKey)")
                    return true
                } else {
                    let errorMessage = String(data: uploadData, encoding: .utf8) ?? "未知错误"
                    printWarning("复制文件失败：\(errorMessage)")
                    return false
                }
            } else {
                printWarning("复制文件失败：服务器返回错误")
                return false
            }
        } catch {
            printWarning("复制文件失败：\(error.localizedDescription)")
            return false
        }
    }
    
    public func moveObject(sourceKey: String, targetKey: String) async throws -> Bool {
        guard checkWritePermission() else { return false }
        
        // 先复制文件
        if try await copyObject(sourceKey: sourceKey, targetKey: targetKey) {
            // 复制成功后删除源文件
            if try await deleteFile(key: sourceKey) {
                printInfo("成功移动文件：\(sourceKey) -> \(targetKey)")
                return true
            } else {
                printWarning("移动文件部分失败：文件已复制到 \(targetKey)，但删除源文件 \(sourceKey) 失败")
                return false
            }
        } else {
            printWarning("移动文件失败：无法复制 \(sourceKey) 到 \(targetKey)")
            return false
        }
    }
} 