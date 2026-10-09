#!/usr/bin/env swift

import ApplicationServices
import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case runtime(String)

    var description: String {
        switch self {
        case .usage(let message), .runtime(let message):
            return message
        }
    }
}

enum MouseButton: String {
    case left
    case right

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        }
    }

    var downType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        }
    }

    var upType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        }
    }
}

enum ModifierName: String {
    case command = "cmd"
    case control = "ctrl"
    case option = "alt"
    case shift = "shift"

    var flag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        }
    }
}

let usage = """
Usage:
  swift computer_use.swift screenshot <output.png>
  swift computer_use.swift activate <app name>
  swift computer_use.swift click <x> <y> [left|right]
  swift computer_use.swift double-click <x> <y>
  swift computer_use.swift move <x> <y>
  swift computer_use.swift scroll <deltaY> [deltaX]
  swift computer_use.swift type <text>
  swift computer_use.swift key <name>
  swift computer_use.swift hotkey <modifiers+key>
  swift computer_use.swift frontmost-app
  swift computer_use.swift window-bounds <app name>

Examples:
  swift computer_use.swift screenshot ./shot.png
  swift computer_use.swift activate "iPhone Mirroring"
  swift computer_use.swift click 320 480
  swift computer_use.swift hotkey cmd+l
"""

func fail(_ error: Error) -> Never {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

func parseDouble(_ text: String, name: String) throws -> Double {
    guard let value = Double(text) else {
        throw CLIError.usage("Invalid \(name): \(text)")
    }
    return value
}

func keyCode(for key: String) -> CGKeyCode? {
    switch key.lowercased() {
    case "a": return 0
    case "s": return 1
    case "d": return 2
    case "f": return 3
    case "h": return 4
    case "g": return 5
    case "z": return 6
    case "x": return 7
    case "c": return 8
    case "v": return 9
    case "b": return 11
    case "q": return 12
    case "w": return 13
    case "e": return 14
    case "r": return 15
    case "y": return 16
    case "t": return 17
    case "1": return 18
    case "2": return 19
    case "3": return 20
    case "4": return 21
    case "6": return 22
    case "5": return 23
    case "=": return 24
    case "9": return 25
    case "7": return 26
    case "-": return 27
    case "8": return 28
    case "0": return 29
    case "]": return 30
    case "o": return 31
    case "u": return 32
    case "[": return 33
    case "i": return 34
    case "p": return 35
    case "l": return 37
    case "j": return 38
    case "'": return 39
    case "k": return 40
    case ";": return 41
    case "\\": return 42
    case ",": return 43
    case "/": return 44
    case "n": return 45
    case "m": return 46
    case ".": return 47
    case "tab": return 48
    case "space": return 49
    case "grave", "`": return 50
    case "delete", "backspace": return 51
    case "enter", "return": return 36
    case "escape", "esc": return 53
    case "command", "cmd": return 55
    case "shift": return 56
    case "capslock": return 57
    case "option", "alt": return 58
    case "control", "ctrl": return 59
    case "rightshift": return 60
    case "rightoption": return 61
    case "rightcontrol": return 62
    case "function", "fn": return 63
    case "f17": return 64
    case "volumeup": return 72
    case "volumedown": return 73
    case "mute": return 74
    case "f18": return 79
    case "f19": return 80
    case "f20": return 90
    case "f5": return 96
    case "f6": return 97
    case "f7": return 98
    case "f3": return 99
    case "f8": return 100
    case "f9": return 101
    case "f11": return 103
    case "f13": return 105
    case "f16": return 106
    case "f14": return 107
    case "f10": return 109
    case "f12": return 111
    case "f15": return 113
    case "help": return 114
    case "home": return 115
    case "pageup": return 116
    case "forwarddelete": return 117
    case "f4": return 118
    case "end": return 119
    case "f2": return 120
    case "pagedown": return 121
    case "f1": return 122
    case "left": return 123
    case "right": return 124
    case "down": return 125
    case "up": return 126
    default: return nil
    }
}

@discardableResult
func runProcess(_ launchPath: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        let detail = error.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CLIError.runtime(detail.isEmpty ? "Command failed: \(launchPath)" : detail)
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

func saveScreenshot(to outputPath: String) throws {
    let url = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = try runProcess("/usr/sbin/screencapture", ["-x", url.path])
    print(url.path)
}

func postMouseEvent(type: CGEventType, point: CGPoint, button: CGMouseButton, clickState: Int64 = 1) throws {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
        throw CLIError.runtime("Failed to create mouse event.")
    }
    event.setIntegerValueField(.mouseEventClickState, value: clickState)
    event.post(tap: .cghidEventTap)
}

func moveMouse(to point: CGPoint) throws {
    try postMouseEvent(type: .mouseMoved, point: point, button: .left)
}

func click(at point: CGPoint, button: MouseButton = .left, clickState: Int64 = 1) throws {
    try moveMouse(to: point)
    usleep(30_000)
    try postMouseEvent(type: button.downType, point: point, button: button.cgButton, clickState: clickState)
    usleep(30_000)
    try postMouseEvent(type: button.upType, point: point, button: button.cgButton, clickState: clickState)
}

func scroll(deltaY: Int32, deltaX: Int32) throws {
    guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else {
        throw CLIError.runtime("Failed to create scroll event.")
    }
    event.post(tap: .cghidEventTap)
}

func typeText(_ text: String) throws {
    let utf16 = Array(text.utf16)
    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
        throw CLIError.runtime("Failed to create keyboard event.")
    }

    keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
    keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
}

func pressKey(_ key: String, modifiers: [ModifierName] = []) throws {
    guard let code = keyCode(for: key) else {
        throw CLIError.usage("Unsupported key: \(key)")
    }

    var flags: CGEventFlags = []
    modifiers.forEach { flags.insert($0.flag) }

    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else {
        throw CLIError.runtime("Failed to create keyboard event.")
    }

    keyDown.flags = flags
    keyUp.flags = flags
    keyDown.post(tap: .cghidEventTap)
    usleep(30_000)
    keyUp.post(tap: .cghidEventTap)
}

func activateApp(_ appName: String) throws {
    let script = """
    tell application "\(appName)" to activate
    """
    _ = try runProcess("/usr/bin/osascript", ["-e", script])
}

func frontmostAppName() -> String? {
    let script = """
    tell application "System Events" to get name of first application process whose frontmost is true
    """
    return try? runProcess("/usr/bin/osascript", ["-e", script])
}

func windowBounds(appName: String) throws {
    let script = """
    tell application "System Events"
      tell process "\(appName)"
        if (count of windows) is 0 then
          return ""
        end if
        set {xPos, yPos} to position of window 1
        set {w, h} to size of window 1
        return (xPos as text) & "," & (yPos as text) & "," & (w as text) & "," & (h as text)
      end tell
    end tell
    """

    let output = try runProcess("/usr/bin/osascript", ["-e", script])
    print(output)
}

func parseHotkey(_ spec: String) throws -> (String, [ModifierName]) {
    let tokens = spec.split(separator: "+").map(String.init)
    guard let last = tokens.last else {
        throw CLIError.usage("Invalid hotkey: \(spec)")
    }

    let modifiers = try tokens.dropLast().map { token -> ModifierName in
        guard let modifier = ModifierName(rawValue: token.lowercased()) else {
            throw CLIError.usage("Unsupported modifier: \(token)")
        }
        return modifier
    }
    return (last, modifiers)
}

let args = Array(CommandLine.arguments.dropFirst())

guard let command = args.first else {
    fail(CLIError.usage(usage))
}

do {
    switch command {
    case "screenshot":
        guard args.count == 2 else { throw CLIError.usage(usage) }
        try saveScreenshot(to: args[1])

    case "activate":
        guard args.count >= 2 else { throw CLIError.usage(usage) }
        try activateApp(args.dropFirst().joined(separator: " "))

    case "click":
        guard args.count >= 3 && args.count <= 4 else { throw CLIError.usage(usage) }
        let x = try parseDouble(args[1], name: "x")
        let y = try parseDouble(args[2], name: "y")
        let button = args.count == 4 ? MouseButton(rawValue: args[3].lowercased()) ?? .left : .left
        try click(at: CGPoint(x: x, y: y), button: button)

    case "double-click":
        guard args.count == 3 else { throw CLIError.usage(usage) }
        let x = try parseDouble(args[1], name: "x")
        let y = try parseDouble(args[2], name: "y")
        let point = CGPoint(x: x, y: y)
        try click(at: point, clickState: 1)
        usleep(120_000)
        try click(at: point, clickState: 2)

    case "move":
        guard args.count == 3 else { throw CLIError.usage(usage) }
        let x = try parseDouble(args[1], name: "x")
        let y = try parseDouble(args[2], name: "y")
        try moveMouse(to: CGPoint(x: x, y: y))

    case "scroll":
        guard args.count == 2 || args.count == 3 else { throw CLIError.usage(usage) }
        let deltaY = Int32(try parseDouble(args[1], name: "deltaY"))
        let deltaX = args.count == 3 ? Int32(try parseDouble(args[2], name: "deltaX")) : 0
        try scroll(deltaY: deltaY, deltaX: deltaX)

    case "type":
        guard args.count >= 2 else { throw CLIError.usage(usage) }
        try typeText(args.dropFirst().joined(separator: " "))

    case "key":
        guard args.count == 2 else { throw CLIError.usage(usage) }
        try pressKey(args[1])

    case "hotkey":
        guard args.count == 2 else { throw CLIError.usage(usage) }
        let (key, modifiers) = try parseHotkey(args[1])
        try pressKey(key, modifiers: modifiers)

    case "frontmost-app":
        print(frontmostAppName() ?? "")

    case "window-bounds":
        guard args.count >= 2 else { throw CLIError.usage(usage) }
        try windowBounds(appName: args.dropFirst().joined(separator: " "))

    case "help", "--help", "-h":
        print(usage)

    default:
        throw CLIError.usage(usage)
    }
} catch {
    fail(error)
}
