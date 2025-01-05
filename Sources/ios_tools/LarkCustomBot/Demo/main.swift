import Foundation
import ios_tools_lib

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
struct Main {
    static func main() async throws {
        // 创建机器人实例
        let bot = LarkCustomBot(webhook: "https://open.feishu.cn/open-apis/bot/v2/hook/xxx", 
                          secret: "xxx",
                          botAppId: "cli_xxx",
                          botSecret: "xxx")
        
        // 1. 发送文本消息
        _ = try await bot.sendText("Hello, this is a text message")
        print("发送文本消息成功")
        
        // 2. 发送富文本消息
        let post = PostContent(title: "我是标题")
        
        // 添加文本内容
        let line1 = post.makeTextContent(text: "这是第一行", styles: ["bold"])
        post.addContentInNewLine(line1)
        
        // 添加表情和Markdown
        let line2_1 = post.makeEmojiContent(emojiType: "OK")
        let line2_2 = post.makeMarkdownContent(mdText: "**helloworld**")
        post.addContentInNewLine(line2_1)
        post.addContentInLine(line2_2)
        
        // 添加代码块
        let line3 = post.makeCodeBlockContent(language: "swift", text: "print(\"Hello, World!\")")
        post.addContentInNewLine(line3)
        
        // 发送富文本消息
        let content = post.getContent()
        let postContent = content["content"] as? [[String: Any]] ?? []
        let anyContent = postContent.map { dict -> [Any] in
            var result: [Any] = []
            for (key, value) in dict {
                result.append(key)
                result.append(value)
            }
            return result
        }
        _ = try await bot.sendPost(content: anyContent, title: "我是标题")
        print("发送富文本消息成功")
        
        // 3. 发送图片消息
        let imagePath = "/Users/wayne/Downloads/IMU标定和姿态结算.drawio.png"
        let imageKey = try await bot.uploadImage(filePath: imagePath)
        _ = try await bot.sendImage(imageKey: imageKey)
        print("发送图片消息成功")
        
        print("所有示例完成")
    }
}

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