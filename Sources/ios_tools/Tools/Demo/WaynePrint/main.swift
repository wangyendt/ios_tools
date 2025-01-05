import Foundation
import ios_tools_lib

// 测试预定义的颜色名称
WaynePrint.print("这是红色的文本", color: "red")
WaynePrint.print("这是绿色的文本", color: "green")
WaynePrint.print("这是蓝色的文本", color: "blue")
WaynePrint.print("这是黄色的文本", color: "yellow")
WaynePrint.print("这是品红色的文本", color: "magenta")
WaynePrint.print("这是青色的文本", color: "cyan")
WaynePrint.print("这是白色的文本", color: "white")
WaynePrint.print("这是黑色的文本", color: "black")

print("\n") // 空行

// 测试十六进制颜色代码
WaynePrint.print("这是使用十六进制颜色代码的文本 (FF0000 - 红色)", color: "FF0000")
WaynePrint.print("这是使用十六进制颜色代码的文本 (00FF00 - 绿色)", color: "00FF00")
WaynePrint.print("这是使用十六进制颜色代码的文本 (0000FF - 蓝色)", color: "0000FF")
WaynePrint.print("这是使用十六进制颜色代码的文本 (FF00FF - 品红)", color: "FF00FF")

print("\n") // 空行

// 测试 RGB 元组
WaynePrint.print("这是使用 RGB 元组的文本 (255,0,0 - 红色)", color: "(255,0,0)")
WaynePrint.print("这是使用 RGB 元组的文本 (0,255,0 - 绿色)", color: "(0,255,0)")
WaynePrint.print("这是使用 RGB 元组的文本 (0,0,255 - 蓝色)", color: "(0,0,255)")
WaynePrint.print("这是使用 RGB 元组的文本 (255,0,255 - 品红)", color: "(255,0,255)")

print("\n") // 空行

// 测试不同的颜色组合
WaynePrint.print("这是使用自定义 RGB 的橙色文本", color: "(255,165,0)")
WaynePrint.print("这是使用十六进制的粉色文本", color: "FFC0CB")
WaynePrint.print("这是使用预定义的青色文本", color: "cyan") 