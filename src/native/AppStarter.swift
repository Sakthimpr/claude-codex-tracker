import Foundation

@discardableResult
func runLaunchctl(_ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return 1
    }
}

let uid = getuid()
let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.sakthivel.claudetracker.plist"
let service = "gui/\(uid)/com.sakthivel.claudetracker"

let status = runLaunchctl(["kickstart", "-k", service])
if status != 0 {
    _ = runLaunchctl(["unload", plistPath])
    _ = runLaunchctl(["load", plistPath])
}
