import Foundation
import ios_tools_lib

@main
struct OpenAIDemo {
    static func main() async {
        do {
            // 初始化OpenAI客户端
            let openAI = OpenAI(
                apiKey: "sk-xxx",
                organizationId: "", // 可选
                baseURL: "https://api.deepseek.com/v1"
            )
            
            // 聊天完成示例
            print("=== Chat Completion Example ===")
            let messages = [
                ChatMessage(role: "system", content: "你是一个有帮助的助手。"),
                ChatMessage(role: "user", content: "你好！请介绍一下自己。")
            ]
            
            print("Sending chat request...")
            let chatResponse = try await openAI.chat(
                messages: messages,
                model: "deepseek-chat",
                temperature: 0.7
            )
            
            print("Assistant's response:")
            if let message = chatResponse.choices.first?.message {
                print(message.content)
            }
            
            // 继续对话
            print("\n=== Continue Chat ===")
            let followUpMessages = messages + [
                ChatMessage(role: "assistant", content: chatResponse.choices.first?.message.content ?? ""),
                ChatMessage(role: "user", content: "你能使用什么编程语言？")
            ]
            
            print("Sending follow-up request...")
            let followUpResponse = try await openAI.chat(
                messages: followUpMessages,
                model: "deepseek-chat",
                temperature: 0.7
            )
            
            print("Assistant's response:")
            if let message = followUpResponse.choices.first?.message {
                print(message.content)
            }
            
        } catch {
            print("Error occurred: \(error)")
            exit(1)
        }
    }
} 