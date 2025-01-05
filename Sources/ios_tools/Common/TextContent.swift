import Foundation

public struct TextContent {
    /// 创建 @所有人 的提醒模式
    public static func makeAtAllPattern() -> String {
        return "<at user_id=\"all\"></at>"
    }
    
    /// 创建 @某人 的提醒模式
    public static func makeAtSomeonePattern(someoneOpenId: String, username: String, idType: String) -> String {
        let mentionType: String
        switch idType {
        case "open_id":
            mentionType = "user_id"
        case "union_id":
            mentionType = "union_id"
        case "user_id":
            mentionType = "user_id"
        default:
            mentionType = "user_id"
        }
        
        return "<at \(mentionType)=\"\(someoneOpenId)\">\(username)</at>"
    }
    
    /// 创建加粗文本
    public static func makeBoldPattern(_ content: String) -> String {
        return "<b>\(content)</b>"
    }
    
    /// 创建斜体文本
    public static func makeItalianPattern(_ content: String) -> String {
        return "<i>\(content)</i>"
    }
    
    /// 创建下划线文本
    public static func makeUnderlinePattern(_ content: String) -> String {
        return "<u>\(content)</u>"
    }
    
    /// 创建删除线文本
    public static func makeDeleteLinePattern(_ content: String) -> String {
        return "<s>\(content)</s>"
    }
    
    /// 创建URL链接
    public static func makeUrlPattern(url: String, text: String) -> String {
        return "[\(text)](\(url))"
    }
} 