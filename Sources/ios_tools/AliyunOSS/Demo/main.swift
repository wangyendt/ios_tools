import Foundation
import ios_tools_lib

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@main
enum Runner {
    static func main() async {
        do {
            try await Main.main()
        } catch {
            WaynePrint.print("错误: \(error)", color: "red")
        }
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
struct Main {
    static func main() async throws {
        let manager = AliyunOSS(
            endpoint: "xxx",
            bucketName: "xxx",
            apiKey: "xxx",
            apiSecret: "xxx"
        )
        
        // 创建测试文件
        let testFilePath = "test.txt"
        let testContent = "Hello, World!"
        try testContent.write(to: URL(fileURLWithPath: testFilePath), atomically: true, encoding: .utf8)
        
        // 创建测试文件夹
        let testDirPath = "test_dir"
        try FileManager.default.createDirectory(atPath: testDirPath, withIntermediateDirectories: true, attributes: nil)
        try "File 1".write(to: URL(fileURLWithPath: "\(testDirPath)/file1.txt"), atomically: true, encoding: .utf8)
        try "File 2".write(to: URL(fileURLWithPath: "\(testDirPath)/file2.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(atPath: "\(testDirPath)/subdir", withIntermediateDirectories: true, attributes: nil)
        try "File 3".write(to: URL(fileURLWithPath: "\(testDirPath)/subdir/file3.txt"), atomically: true, encoding: .utf8)
        
        // 1. 上传文件
        WaynePrint.print("\n1. 测试上传文件", color: "cyan")
        _ = try await manager.uploadFile(key: "test.txt", filePath: testFilePath)
        _ = try await manager.uploadFile(key: "1/test.txt", filePath: testFilePath)
        _ = try await manager.uploadFile(key: "1/test2.txt", filePath: testFilePath)
        _ = try await manager.uploadFile(key: "2/test3.txt", filePath: testFilePath)
        _ = try await manager.uploadFile(key: "2/test4.txt", filePath: testFilePath)
        
        // 2. 测试上传文件夹
        WaynePrint.print("\n2. 测试上传文件夹", color: "cyan")
        _ = try await manager.uploadDirectory(localPath: testDirPath, prefix: "test_dir")
        
        // 3. 上传文本
        WaynePrint.print("\n3. 测试上传文本", color: "cyan")
        _ = try await manager.uploadText(key: "hello.txt", text: "Hello, World!")
        _ = try await manager.uploadText(key: "test.txt", text: "Hello, World!")
        
        // 4. 列举所有文件
        WaynePrint.print("\n4. 测试列举文件", color: "cyan")
        let files = try await manager.listAllKeys()
        WaynePrint.print("文件列表：", color: "magenta")
        for file in files {
            WaynePrint.print("  - \(file)", color: "magenta")
        }
        
        // 5. 列举指定前缀的文件
        WaynePrint.print("\n5. 测试列举指定前缀的文件", color: "cyan")
        let filesWithPrefix1 = try await manager.listKeysWithPrefix("1/")
        WaynePrint.print("前缀为 '1/' 的文件列表：", color: "magenta")
        for file in filesWithPrefix1 {
            WaynePrint.print("  - \(file)", color: "magenta")
        }
        
        // 6. 下载文件
        WaynePrint.print("\n6. 测试下载文件", color: "cyan")
        _ = try await manager.downloadFile(key: "test.txt")
        _ = try await manager.downloadFile(key: "1/test.txt", rootDir: "downloads")
        
        // 7. 测试下载文件夹
        WaynePrint.print("\n7. 测试下载文件夹", color: "cyan")
        _ = try await manager.downloadDirectory(prefix: "test_dir/", localPath: "downloads")
        
        // 8. 下载指定前缀的文件
        WaynePrint.print("\n8. 测试下载指定前缀的文件", color: "cyan")
        _ = try await manager.downloadFilesWithPrefix("2/", rootDir: "downloads")
        
        // 9. 删除文件
        WaynePrint.print("\n9. 测试删除文件", color: "cyan")
        _ = try await manager.deleteFile(key: "test.txt")
        _ = try await manager.deleteFile(key: "hello.txt")
        
        // 10. 删除指定前缀的文件
        WaynePrint.print("\n10. 测试删除指定前缀的文件", color: "cyan")
        _ = try await manager.deleteFilesWithPrefix("1/")
        _ = try await manager.deleteFilesWithPrefix("2/")
        _ = try await manager.deleteFilesWithPrefix("test_dir/")
        
        // 清理测试文件
        try? FileManager.default.removeItem(atPath: testFilePath)
        try? FileManager.default.removeItem(atPath: testDirPath)
        
        WaynePrint.print("\n所有测试完成", color: "green")
    }
} 