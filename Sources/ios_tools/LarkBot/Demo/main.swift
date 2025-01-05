import Foundation
import ios_tools_lib

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@main
struct Main {
    static func main() async {
        do {
            try await run()
        } catch {
            print("错误: \(error)")
        }
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
private func run() async throws {
    // 创建机器人实例
    let bot = LarkBot(appId: "xxx", appSecret: "xxx")
    
    // 1. 获取群组列表
    let groupList = try await bot.getGroupList()
    print("群组列表:")
    dump(groupList.items)
    
    // 2. 获取特定群组的ID
    let groupChatIds = try await bot.getGroupChatIdByName("测试2")
    guard let groupChatId = groupChatIds.first else {
        print("未找到群组")
        return
    }
    
    // 3. 获取群成员信息
    let members = try await bot.getMembersInGroupByGroupChatId(groupChatId)
    print("群成员:")
    dump(members.items)
    
    // 4. 获取特定成员的 open_id
    let memberOpenIds = try await bot.getMemberOpenIdByName(groupChatId: groupChatId, memberName: "王也")
    guard let specificMemberUserOpenId = memberOpenIds.first else {
        print("未找到指定成员")
        return
    }
    
    // 5. 获取用户信息
    let userInfos = try await bot.getUserInfo(emails: [], mobiles: ["13267080069"])
    print("用户信息:")
    dump(userInfos.items)
    
    guard let userInfo = userInfos.items.first,
          let userOpenId = userInfo["user_id"] as? String else {
        print("未找到用户信息")
        return
    }
    
    // 6. 发送文本消息
    // 6.1 发送普通文本消息
    let textResponse = try await bot.sendTextToUser(userOpenId: userOpenId, text: "Hello, this is a single chat.\nYou know?")
    print("发送文本消息响应:", textResponse.data)
    
    // 6.2 发送带格式的文本消息
    var someText = TextContent.makeAtSomeonePattern(someoneOpenId: specificMemberUserOpenId, username: "hi", idType: "haha")
    someText += TextContent.makeAtAllPattern()
    someText += TextContent.makeBoldPattern("notice")
    someText += TextContent.makeItalianPattern("italian")
    someText += TextContent.makeUnderlinePattern("underline")
    someText += TextContent.makeDeleteLinePattern("delete line")
    someText += TextContent.makeUrlPattern(url: "www.baidu.com", text: "百度")
    
    let formattedTextResponse = try await bot.sendTextToChat(chatId: groupChatId, text: "Hi, this is a group.\n\(someText)")
    print("发送格式化文本消息响应:", formattedTextResponse.data)
    
    // 7. 上传和发送图片
    let imagePath = "/Users/wayne/Downloads/IMU标定和姿态结算.drawio.png"
    let imageKey = try await bot.uploadImage(filePath: imagePath)
    if !imageKey.isEmpty {
        let imageToUserResponse = try await bot.sendImageToUser(userOpenId: userOpenId, imageKey: imageKey)
        print("发送图片到用户响应:", imageToUserResponse.data)
        
        let imageToChatResponse = try await bot.sendImageToChat(chatId: groupChatId, imageKey: imageKey)
        print("发送图片到群组响应:", imageToChatResponse.data)
    }
    
    // 8. 分享群组和用户
    let shareChatToUserResponse = try await bot.sendSharedChatToUser(userOpenId: userOpenId, sharedChatId: groupChatId)
    print("分享群组到用户响应:", shareChatToUserResponse.data)
    
    let shareChatToChatResponse = try await bot.sendSharedChatToChat(chatId: groupChatId, sharedChatId: groupChatId)
    print("分享群组到群组响应:", shareChatToChatResponse.data)
    
    let shareUserToUserResponse = try await bot.sendSharedUserToUser(userOpenId: userOpenId, sharedUserId: userOpenId)
    print("分享用户到用户响应:", shareUserToUserResponse.data)
    
    let shareUserToChatResponse = try await bot.sendSharedUserToChat(chatId: groupChatId, sharedUserId: userOpenId)
    print("分享用户到群组响应:", shareUserToChatResponse.data)
    
    // 9. 上传和发送文件
    let filePath = "/Users/wayne/Downloads/test.txt"
    let fileKey = try await bot.uploadFile(filePath: filePath)
    if !fileKey.isEmpty {
        let fileToUserResponse = try await bot.sendFileToUser(userOpenId: userOpenId, fileKey: fileKey)
        print("发送文件到用户响应:", fileToUserResponse.data)
        
        let fileToChatResponse = try await bot.sendFileToChat(chatId: groupChatId, fileKey: fileKey)
        print("发送文件到群组响应:", fileToChatResponse.data)
    }
    
    // 10. 发送富文本消息
    let post = PostContent(title: "我是标题")
    
    // 添加文本内容
    let line1 = post.makeTextContent(text: "这是第一行", styles: ["bold"])
    post.addContentInNewLine(line1)
    
    // 添加@提醒
    let line3 = post.makeAtContent(atUserId: specificMemberUserOpenId, styles: ["bold", "italic"])
    post.addContentInNewLine(line3)
    
    // 添加表情和Markdown
    let line4_1 = post.makeEmojiContent(emojiType: "OK")
    let line4_2 = post.makeMarkdownContent(mdText: "**helloworld**")
    post.addContentInNewLine(line4_1)
    post.addContentInLine(line4_2)
    
    // 添加代码块
    let line6 = post.makeCodeBlockContent(language: "swift", text: "print(\"Hello, World!\")")
    post.addContentInNewLine(line6)
    
    // 发送富文本消息
    let postResponse = try await bot.sendPostToChat(chatId: groupChatId, postContent: post.getContent())
    print("发送富文本消息响应:", postResponse.data)
    
    print("所有示例执行完成")
} 