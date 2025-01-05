import Foundation

public enum WayneColor: String {
    case `default` = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
}

public struct WaynePrint {
    private static let boldCode = "\u{001B}[1m"
    private static let endCode = WayneColor.default.rawValue
    
    public static func print(_ text: Any, color: WayneColor = .default, bold: Bool = false) {
        let colorCode = color.rawValue
        let boldCode = bold ? self.boldCode : ""
        Swift.print("\(colorCode)\(boldCode)\(text)\(endCode)")
    }
    
    public static func info(_ text: Any) {
        print("INFO: \(text)", color: .blue)
    }
    
    public static func warning(_ text: Any) {
        print("WARNING: \(text)", color: .yellow)
    }
    
    public static func error(_ text: Any) {
        print("ERROR: \(text)", color: .red, bold: true)
    }
    
    public static func success(_ text: Any) {
        print("SUCCESS: \(text)", color: .green)
    }
} 