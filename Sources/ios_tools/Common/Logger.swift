import Foundation

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
actor Logger {
    func info(_ message: String) {
        print("INFO: \(message)")
    }
    
    func warning(_ message: String) {
        print("WARNING: \(message)")
    }
    
    func error(_ message: String) {
        print("ERROR: \(message)")
    }
} 