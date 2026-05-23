import Foundation
import os

/// Central place to read AIYO Wisper logs. Categories are namespaced under the
/// `com.aiyo.wisper` subsystem so filtering in Console.app or `log stream` works
/// regardless of how the app was launched (Finder, Xcode, Terminal, LaunchDaemon).
///
/// Live tail from Terminal:
///   log stream --predicate 'subsystem == "com.aiyo.wisper"' --level debug
///
/// One-shot dump of the last 5 minutes:
///   log show --predicate 'subsystem == "com.aiyo.wisper"' --last 5m
enum Log {
    static let subsystem = "com.aiyo.wisper"
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    static let transcribe = Logger(subsystem: subsystem, category: "transcribe")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let learner = Logger(subsystem: subsystem, category: "learner")
    static let dictionary = Logger(subsystem: subsystem, category: "dictionary")
    static let appstate = Logger(subsystem: subsystem, category: "appstate")
}
