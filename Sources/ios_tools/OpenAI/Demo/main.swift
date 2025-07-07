import Foundation
import ios_tools_lib

@available(iOS 15.0, macOS 12.0, watchOS 8.0, *)
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
            
            // 1. 常规调用示例
            print("=== Regular Chat ===")
            let response = try await openAI.chat(
                messages: [ChatMessage(role: "user", content: "1+1=？")],
                model: "deepseek-chat",
                temperature: 0.7
            )
            print("Response:", response.choices.first?.message.content ?? "", "\n")
            
            // 2. 流式调用示例
            print("=== Streaming Chat ===")
            try await openAI.chatStream(
                messages: [ChatMessage(role: "user", content: "1+2等于几？")],
                model: "deepseek-chat",
                temperature: 0.7
            ) { chunk in
                print(chunk, terminator: "")
            }
            print("\n")
            
        } catch {
            print("\nError:", error)
            exit(1)
        }
    }
} 