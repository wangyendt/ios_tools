# ios_tools

iOS开发工具集合，包含以下模块：
- OpenAI API 调用
- 飞书机器人
- 飞书自定义机器人
- 阿里云OSS
- 工具类

## 环境要求
- iOS 16.0+
- macOS 13.0+
- Swift 5.9+

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

### 3. 运行测试
每个模块都有对应的Demo可以运行测试：
```bash
swift run OpenAIDemo
swift run LarkBotDemo
swift run LarkCustomBotDemo
swift run AliyunOSSDemo
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
try await oss.upload(
    fileData: data,
    toPath: "path/in/bucket/file.txt"
)

// 下载文件
let downloadedData = try await oss.download(
    fromPath: "path/in/bucket/file.txt"
)
```

## 注意事项
1. 请确保所有的密钥和敏感信息都保存在安全的地方，不要直接提交到代码仓库
2. 在生产环境中使用时，建议使用环境变量或配置文件来管理密钥
3. 每个模块的Demo文件夹中都有更详细的使用示例

## 许可证
MIT-License
