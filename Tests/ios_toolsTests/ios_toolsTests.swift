import Testing
@testable import ios_tools

final class LarkCustomBotTests {
    // 替换成你的实际配置
    let webhook = "xxx"  // ⚠️ 这里需要替换成实际的webhook地址
    let secret = ""  // 如果没有可以留空
    // ⚠️ 这里需要填写机器人的 App ID 和 Secret，否则无法上传图片
    let botAppId = "xxx"  
    let botSecret = "xxx"  
    
    @Test func testSendText() async throws {
        let bot = LarkCustomBot(webhook: webhook, secret: secret, botAppId: botAppId, botSecret: botSecret)
        // 测试普通文本消息
        await bot.sendText("这是一条测试消息")
        // 测试@所有人的文本消息
        await bot.sendText("这是一条测试@所有人的消息", mentionAll: true)
    }
    
    @Test func testSendPost() async throws {
        let bot = LarkCustomBot(webhook: webhook, secret: secret, botAppId: botAppId, botSecret: botSecret)
        
        // 创建富文本消息内容
        let textContent = LarkCustomBot.createTextContent(text: "这是一段普通文本")
        let linkContent = LarkCustomBot.createLinkContent(href: "https://www.example.com", text: "这是一个链接")
        let atContent = LarkCustomBot.createAtContent(userId: "all", userName: "所有人")
        
        let content = [
            [textContent, linkContent],
            [atContent]
        ]
        
        await bot.sendPost(content: content, title: "测试富文本消息")
    }
    
    @Test func testUploadAndSendImage() async throws {
        let bot = LarkCustomBot(webhook: webhook, secret: secret, botAppId: botAppId, botSecret: botSecret)
        // 上传图片
        let imagePath = "/path/to/your/image.jpg"
        let imageKey = try await bot.uploadImage(filePath: imagePath)
        #expect(!imageKey.isEmpty, "上传图片失败，请确保填写了正确的 botAppId 和 botSecret")
        
        // 发送图片
        if !imageKey.isEmpty {
            await bot.sendImage(imageKey: imageKey)
        }
    }
    
    @Test func testSendInteractive() async throws {
        let bot = LarkCustomBot(webhook: webhook, secret: secret, botAppId: botAppId, botSecret: botSecret)
        
        // 创建一个简单的消息卡片
        let card: [String: Any] = [
            "config": [
                "wide_screen_mode": true
            ],
            "header": [
                "title": [
                    "tag": "plain_text",
                    "content": "这是一个测试卡片"
                ]
            ],
            "elements": [
                [
                    "tag": "div",
                    "text": [
                        "tag": "plain_text",
                        "content": "这是卡片内容"
                    ]
                ]
            ]
        ]
        
        await bot.sendInteractive(card: card)
    }
}
