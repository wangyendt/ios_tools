import Foundation

public struct WaynePrint {
    private static let endCode = "\u{001B}[0m"
    
    private static func rgbToAnsi(r: Int, g: Int, b: Int) -> String {
        return "\u{001B}[38;2;\(r);\(g);\(b)m"
    }
    
    private static func parseColor(_ color: String) -> String {
        // 处理预定义的颜色名称
        let predefinedColors: [String: (Int, Int, Int)] = [
            "red": (255, 0, 0),
            "green": (0, 255, 0),
            "blue": (0, 0, 255),
            "yellow": (255, 255, 0),
            "magenta": (255, 0, 255),
            "cyan": (0, 255, 255),
            "white": (255, 255, 255),
            "black": (0, 0, 0)
        ]
        
        if let (r, g, b) = predefinedColors[color.lowercased()] {
            return rgbToAnsi(r: r, g: g, b: b)
        }
        
        // 处理十六进制颜色代码
        if color.count == 6 {
            let scanner = Scanner(string: color)
            var hexNumber: UInt64 = 0
            if scanner.scanHexInt64(&hexNumber) {
                let r = Int((hexNumber & 0xFF0000) >> 16)
                let g = Int((hexNumber & 0x00FF00) >> 8)
                let b = Int(hexNumber & 0x0000FF)
                return rgbToAnsi(r: r, g: g, b: b)
            }
        }
        
        // 处理 RGB 元组字符串，格式如 "(255,0,0)"
        if color.hasPrefix("(") && color.hasSuffix(")") {
            let rgbStr = color.dropFirst().dropLast()
            let components = rgbStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if components.count == 3 {
                return rgbToAnsi(r: components[0], g: components[1], b: components[2])
            }
        }
        
        // 默认返回白色
        return rgbToAnsi(r: 255, g: 255, b: 255)
    }
    
    public static func print(_ text: Any, color: String = "white") {
        let colorCode = parseColor(color)
        Swift.print("\(colorCode)\(text)\(endCode)")
    }
} 