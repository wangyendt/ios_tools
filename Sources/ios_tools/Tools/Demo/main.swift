import Foundation
import ios_tools

// 基本用法
WaynePrint.print("这是默认颜色的文本")
WaynePrint.print("这是红色的文本", color: .red)
WaynePrint.print("这是绿色的文本", color: .green)
WaynePrint.print("这是黄色的文本", color: .yellow)
WaynePrint.print("这是蓝色的文本", color: .blue)
WaynePrint.print("这是品红色的文本", color: .magenta)
WaynePrint.print("这是青色的文本", color: .cyan)
WaynePrint.print("这是白色的文本", color: .white)

// 加粗效果
WaynePrint.print("这是加粗的文本", bold: true)
WaynePrint.print("这是红色加粗的文本", color: .red, bold: true)

// 预定义的日志级别
WaynePrint.info("这是一条信息")
WaynePrint.warning("这是一条警告")
WaynePrint.error("这是一条错误")
WaynePrint.success("这是一条成功消息") 