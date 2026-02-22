import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

enum Logger {
    static func log(_ message: @autoclosure () -> String, level: LogLevel = .debug, category: String = "App") {
        #if DEBUG
        // In Debug builds, log everything
        let shouldLog = true
        #else
        // In Release builds, only log warnings and errors
        let shouldLog = (level == .warn || level == .error)
        #endif
        guard shouldLog else { return }
        print("[\(level.rawValue)][\(category)] \(message())")
    }
}


