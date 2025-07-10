# ios_tools

![Platform](https://img.shields.io/badge/platform-iOS%2013%2B%20%7C%20macOS%2010.15%2B%20%7C%20watchOS%206.2%2B%20%7C%20tvOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

全平台苹果生态开发工具集合，包含以下模块：
- 🤖 OpenAI API 调用
- 🚀 飞书机器人 (官方 API)
- 🔗 飞书自定义机器人 (Webhook)
- ☁️ 阿里云OSS (对象存储)
- 🌐 跨语言通信库 (CrossComm) - **完整支持文件传输功能** ⚡
- 🛠️ 工具类集合

## 环境要求
- iOS 13.0+ / macOS 10.15+ / watchOS 6.2+ （完整跨平台支持）
- Swift 5.9+

### 平台支持详情
- 📱 **iPhone/iPad**: iOS 13.0+ (支持设备唯一标识符)
- ⌚ **Apple Watch**: watchOS 6.2+ (需要6.2+以支持identifierForVendor)
- 💻 **Mac**: macOS 10.15+ (使用随机UUID作为设备标识)
- 📺 **Apple TV**: tvOS 13.0+ (支持设备唯一标识符)

## 安装方法

### Swift Package Manager
在你的 `Package.swift` 文件中添加依赖：

```swift
dependencies: [
    .package(url: "你的仓库地址", branch: "main")
]
```

或者在 Xcode 中：
1. File > Add Packages
2. 输入仓库地址
3. 选择 "main" 分支

## 本地测试

### 1. 克隆仓库
```bash
git clone 你的仓库地址
cd ios_tools
```

### 2. 配置各模块的密钥

#### OpenAI
在 `Sources/ios_tools/OpenAI/Demo/main.swift` 中设置你的 API Key：
```swift
let openAI = OpenAI(apiKey: "your-api-key")
```

#### 飞书机器人
在 `Sources/ios_tools/LarkBot/Demo/main.swift` 中设置你的 App ID 和 App Secret：
```swift
let larkBot = LarkBot(appId: "your-app-id", appSecret: "your-app-secret")
```

#### 飞书自定义机器人
在 `Sources/ios_tools/LarkCustomBot/Demo/main.swift` 中设置 Webhook URL：
```swift
let customBot = LarkCustomBot(webhookURL: "your-webhook-url")
```

#### 阿里云OSS
在 `Sources/ios_tools/AliyunOSS/Demo/main.swift` 中设置相关配置：
```swift
let oss = AliyunOSS(
    endpoint: "your-endpoint",
    accessKeyId: "your-access-key-id",
    accessKeySecret: "your-access-key-secret",
    bucketName: "your-bucket-name"
)
```

#### CrossComm 跨语言通信（包含文件传输功能）
在 `Sources/ios_tools/CrossComm/Demo/main.swift` 中配置OSS参数以启用文件传输：
```swift
// 🔧 AliyunOSS配置 - 修改这里以启用文件传输功能
static let OSS_ENDPOINT = "oss-cn-beijing.aliyuncs.com"
static let OSS_ACCESS_KEY_ID = "your-access-key-id"
static let OSS_ACCESS_KEY_SECRET = "your-access-key-secret"
static let OSS_BUCKET_NAME = "your-bucket-name"
```

CrossComm 默认连接到 `39.105.45.101:9898`，你可以通过命令行参数指定其他服务器：
```bash
# 使用默认服务器
swift run CrossCommDemo listen

# 指定服务器地址
swift run CrossCommDemo listen localhost 9898
swift run CrossCommDemo send 192.168.1.100

# 交互模式（既监听又可发送）
swift run CrossCommDemo both
```

### 3. 运行测试
每个模块都有对应的Demo可以运行测试：
```bash
swift run OpenAIDemo
swift run LarkBotDemo
swift run LarkCustomBotDemo
swift run AliyunOSSDemo

# CrossComm 测试
swift run CrossCommDemo listen    # 监听模式
swift run CrossCommDemo send      # 发送模式（包含文件传输测试）
swift run CrossCommDemo both      # 交互模式
```

## 使用示例

### OpenAI
```swift
import ios_tools_lib

let openAI = OpenAI(apiKey: "your-api-key")
let response = try await openAI.chat(messages: [
    .init(role: .user, content: "Hello!")
])
print(response)
```

### 飞书机器人
```swift
import ios_tools_lib

let larkBot = LarkBot(appId: "your-app-id", appSecret: "your-app-secret")
try await larkBot.sendMessage(
    chatId: "your-chat-id",
    msg: "Hello from LarkBot!"
)
```

### 飞书自定义机器人
```swift
import ios_tools_lib

let customBot = LarkCustomBot(webhookURL: "your-webhook-url")
try await customBot.sendMessage("Hello from CustomBot!")
```

### 阿里云OSS
```swift
import ios_tools_lib

let oss = AliyunOSS(
    endpoint: "your-endpoint",
    accessKeyId: "your-access-key-id",
    accessKeySecret: "your-access-key-secret",
    bucketName: "your-bucket-name"
)

// 上传文件
try await oss.uploadFile(key: "path/file.txt", filePath: "/local/file.txt")

// 下载文件
let success = try await oss.downloadFile(key: "path/file.txt", rootDir: "./downloads")

// 上传整个文件夹
try await oss.uploadDirectory(localPath: "/local/folder", prefix: "remote/folder/")

// 下载整个文件夹
try await oss.downloadDirectory(prefix: "remote/folder/", localPath: "./downloads")
```

### CrossComm 跨语言通信（完整文件传输支持）
```swift
import ios_tools_lib

// 创建通信客户端（包含文件传输功能需要配置OSS）
let client = CrossCommClient(
    ip: "39.105.45.101",              // 服务器IP
    port: 9898,                       // 服务器端口
    clientId: "my_ios_app",           // 可选：自定义客户端ID（不设置会自动生成）
    ossEndpoint: "your-oss-endpoint", // OSS配置（文件传输必需）
    ossAccessKeyId: "your-key-id",
    ossAccessKeySecret: "your-secret",
    ossBucketName: "your-bucket"
)

// 自动设备标识符：
// - iPhone/iPad: 使用 UIDevice.identifierForVendor
// - Apple Watch: 使用 WKInterfaceDevice.identifierForVendor (需要 watchOS 6.2+)
// - Mac: 使用随机 UUID（每次启动不同）
// - Apple TV: 使用 UIDevice.identifierForVendor

// 添加基础消息监听器
await client.addMessageListener(msgType: .text) { message in
    print("收到文本消息: \(message.content)")
    print("来自: \(message.fromClientId)")
}

// 添加文件监听器（自动下载到指定目录）
await client.addMessageListener(
    msgType: .file, 
    downloadDirectory: "./downloads/files"
) { message in
    print("收到文件: \(message.content)")  // 本地下载后的文件路径
    print("OSS Key: \(message.ossKey ?? "N/A")")
}

// 添加图片监听器
await client.addMessageListener(
    msgType: .image,
    downloadDirectory: "./downloads/images"
) { message in
    print("收到图片: \(message.content)")  // 本地下载后的图片路径
}

// 添加文件夹监听器
await client.addMessageListener(
    msgType: .folder,
    downloadDirectory: "./downloads/folders"
) { message in
    print("收到文件夹: \(message.content)")  // 本地下载后的文件夹路径
}

// 连接到服务器
let connected = await client.connect()
if connected {
    // 发送基础消息
    await client.sendText("Hello from iOS!")
    await client.sendJSON(["type": "greeting", "message": "Hello"])
    await client.sendBytes(Data("Binary data".utf8))
    
    // 🚀 发送文件（自动上传到OSS）
    await client.sendFile("/path/to/document.txt")      // 发送文件
    await client.sendImage("/path/to/photo.jpg")        // 发送图片
    await client.sendFolder("/path/to/project/")        // 发送整个文件夹
    
    // 获取客户端列表
    if let clientList = await client.listClients() {
        print("在线客户端: \(clientList)")
    }
}
```

#### 支持的消息类型
- ✅ `text`: 文本消息
- ✅ `json`: JSON格式消息  
- ✅ `dict`: 字典消息
- ✅ `bytes`: 二进制数据
- 🚀 `file`: **文件消息（自动上传/下载）**
- 🚀 `image`: **图片消息（自动上传/下载）**
- 🚀 `folder`: **文件夹消息（自动上传/下载）**

#### 🌟 文件传输特性

**核心功能：**
- 🔄 **自动文件上传**: 发送文件时自动上传到阿里云OSS
- 📥 **智能文件下载**: 接收文件时自动从OSS下载到本地指定目录
- 📁 **完整文件夹支持**: 支持发送和接收整个文件夹（包括子文件夹）
- 🖼️ **图片传输优化**: 专门优化的图片传输流程
- 🔗 **跨平台兼容**: 与Python版本完全兼容的消息格式

**文件类型支持：**
- 📄 任意格式文件（文本、文档、代码、数据文件等）
- 🖼️ 图片文件（PNG、JPG、SVG、GIF等）
- 📁 文件夹（递归上传/下载所有子文件和子文件夹）

**自动化特性：**
- 🎯 **智能路径处理**: 自动处理文件路径和文件名冲突
- ⚡ **异步传输**: 非阻塞的异步文件传输
- 🛡️ **错误处理**: 完善的错误处理和重试机制
- 📊 **传输状态**: 实时的传输状态和进度反馈

**配置选项：**
```swift
// 为不同类型的文件配置不同的下载目录
await client.addMessageListener(msgType: .file, downloadDirectory: "./downloads/files") { ... }
await client.addMessageListener(msgType: .image, downloadDirectory: "./downloads/images") { ... }
await client.addMessageListener(msgType: .folder, downloadDirectory: "./downloads/folders") { ... }

// 不设置下载目录的监听器不会自动下载，节省流量
await client.addMessageListener(msgType: .file) { message in
    print("收到文件消息但不自动下载: \(message.ossKey)")
    
    // 可以选择手动下载
    // await client.downloadFileManually(ossKey: message.ossKey, saveDirectory: "./manual/")
}
```

#### CrossComm Demo 测试模式

**监听模式** (`swift run CrossCommDemo listen`):
- 连接到服务器并监听所有类型的消息
- 自动下载接收到的文件、图片、文件夹
- 显示详细的消息信息和文件状态

**发送模式** (`swift run CrossCommDemo send`):
- 发送完整的测试消息套件，包括：
  1. 文本消息测试
  2. JSON消息测试  
  3. 字典消息测试
  4. 字节数据测试
  5. 客户端列表获取
  6. 🚀 **文件发送测试**（自动创建测试文件并发送）
  7. 🚀 **图片发送测试**（自动创建SVG测试图片并发送）
  8. 🚀 **文件夹发送测试**（自动创建包含多文件的测试文件夹并发送）

**交互模式** (`swift run CrossCommDemo both`):
- 既可以监听消息，也可以发送消息
- 包含独立的文件、图片、文件夹发送选项
- 适合实时测试和调试

## 注意事项
1. 请确保所有的密钥和敏感信息都保存在安全的地方，不要直接提交到代码仓库
2. 在生产环境中使用时，建议使用环境变量或配置文件来管理密钥
3. 每个模块的Demo文件夹中都有更详细的使用示例
4. **CrossComm 文件传输功能需要配置阿里云OSS参数**
5. **支持的平台**：
   - 📱 iOS 13.0+ / iPadOS 13.0+
   - 💻 macOS 10.15+
   - ⌚ watchOS 6.2+（CrossComm需要6.2+支持设备标识符API）
   - 📺 tvOS 13.0+

### 平台特殊说明
- **Apple Watch**: 需要 watchOS 6.2+ 才能使用 CrossComm 的设备标识符功能
- **Mac**: CrossComm 在 Mac 上使用随机 UUID 作为设备标识，每次启动应用会生成新的标识
- **所有平台**: 其他功能模块（OpenAI、LarkBot、阿里云OSS等）在所有支持平台上功能完全一致

## 许可证
MIT-License
