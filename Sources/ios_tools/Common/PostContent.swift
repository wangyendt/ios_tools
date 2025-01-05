import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public class PostContent {
    private var content: [String: [String: Any]]
    
    public init(title: String = "") {
        self.content = [
            "zh_cn": [
                "title": title,
                "content": [[Any]]()
            ]
        ]
    }
    
    public func getContent() -> [String: [String: Any]] {
        return content
    }
    
    public func setTitle(_ title: String) {
        content["zh_cn"]?["title"] = title
    }
    
    public static func listTextStyles() -> [String] {
        return ["bold", "underline", "lineThrough", "italic"]
    }
    
    public func makeTextContent(text: String, styles: [String]? = nil, unescape: Bool = false) -> [String: Any] {
        return [
            "tag": "text",
            "text": text,
            "style": styles ?? [],
            "unescape": unescape
        ]
    }
    
    public func makeLinkContent(text: String, link: String, styles: [String]? = nil) -> [String: Any] {
        return [
            "tag": "a",
            "text": text,
            "href": link,
            "style": styles ?? []
        ]
    }
    
    public func makeAtContent(atUserId: String, styles: [String]? = nil) -> [String: Any] {
        return [
            "tag": "at",
            "user_id": atUserId,
            "style": styles ?? []
        ]
    }
    
    public func makeImageContent(imageKey: String) -> [String: Any] {
        return [
            "tag": "img",
            "image_key": imageKey
        ]
    }
    
    public func makeMediaContent(fileKey: String, imageKey: String = "") -> [String: Any] {
        return [
            "tag": "media",
            "image_key": imageKey,
            "file_key": fileKey
        ]
    }
    
    public func makeEmojiContent(emojiType: String) -> [String: Any] {
        return [
            "tag": "emotion",
            "emoji_type": emojiType
        ]
    }
    
    public func makeHrContent() -> [String: Any] {
        return [
            "tag": "hr"
        ]
    }
    
    public func makeCodeBlockContent(language: String, text: String) -> [String: Any] {
        return [
            "tag": "code_block",
            "language": language,
            "text": text
        ]
    }
    
    public func makeMarkdownContent(mdText: String) -> [String: Any] {
        return [
            "tag": "md",
            "text": mdText
        ]
    }
    
    public func addContentInLine(_ content: [String: Any]) {
        if var contents = self.content["zh_cn"]?["content"] as? [[Any]] {
            if contents.isEmpty {
                contents.append([])
            }
            contents[contents.count - 1].append(content)
            self.content["zh_cn"]?["content"] = contents
        }
    }
    
    public func addContentsInLine(_ contents: [[String: Any]]) {
        if var existingContents = self.content["zh_cn"]?["content"] as? [[Any]] {
            if existingContents.isEmpty {
                existingContents.append([])
            }
            existingContents[existingContents.count - 1].append(contentsOf: contents)
            self.content["zh_cn"]?["content"] = existingContents
        }
    }
    
    public func addContentInNewLine(_ content: [String: Any]) {
        if var contents = self.content["zh_cn"]?["content"] as? [[Any]] {
            contents.append([content])
            self.content["zh_cn"]?["content"] = contents
        }
    }
    
    public func addContentsInNewLine(_ contents: [[String: Any]]) {
        if var existingContents = self.content["zh_cn"]?["content"] as? [[Any]] {
            existingContents.append(contents)
            self.content["zh_cn"]?["content"] = existingContents
        }
    }
    
    public func listEmojiTypes() {
        let url = "https://open.feishu.cn/document/server-docs/im-v1/message-reaction/emojis-introduce"
        #if os(macOS)
        if let nsUrl = URL(string: url) {
            NSWorkspace.shared.open(nsUrl)
        }
        #elseif os(iOS)
        if let nsUrl = URL(string: url) {
            UIApplication.shared.open(nsUrl)
        }
        #endif
    }
} 