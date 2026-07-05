#!/usr/bin/env swift
//
// resolve_ax_diag.swift
// Standalone AX diagnostic tool for DaVinci Resolve.
//
// Usage:
//   1. Save as ~/resolve_ax_diag.swift
//   2. Open Terminal
//   3. Grant Terminal (or whichever app runs swift) Accessibility permission:
//      System Settings > Privacy & Security > Accessibility
//   4. Run:  swift ~/resolve_ax_diag.swift
//   5. Open DaVinci Resolve, switch between pages (Edit → Fusion → Color → …)
//   6. Watch the diff log print every change in real time
//   7. Press Ctrl+C to stop
//
// What it does:
//   - Finds Resolve's PID by bundle id
//   - Every 800ms, walks the full AX tree of Resolve's main (or focused) window
//   - Builds a snapshot of every element with: role, title, value, description,
//     identifier, position, size
//   - Compares with previous snapshot
//   - Prints additions / removals / changes — with timestamps
//
// This is purely diagnostic. It does NOT modify any state. Safe to run alongside Resolve.
//

import Cocoa
import ApplicationServices

let resolveBundleId = "com.blackmagic-design.DaVinciResolve"
let pollInterval: TimeInterval = 0.8
let maxDepth = 15

// MARK: - Snapshot

struct AXSnapshotKey: Hashable {
    let role: String
    let title: String
    let desc: String
    let identifier: String
}

struct AXSnapshotEntry {
    let role: String
    let title: String
    let desc: String
    let identifier: String
    let value: String
    let position: String
    let size: String
    let depth: Int
}

func findResolveApp() -> NSRunningApplication? {
    return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == resolveBundleId })
}

func getMainWindow(appElement: AXUIElement) -> AXUIElement? {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &ref)
    if ref == nil {
        AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &ref)
    }
    return ref.map { $0 as! AXUIElement }
}

func getStringAttr(_ element: AXUIElement, _ attr: String) -> String {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attr as CFString, &ref)
    if let s = ref as? String { return s }
    return ""
}

func getValueAttr(_ element: AXUIElement) -> String {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &ref)
    if ref == nil { return "" }
    if let s = ref as? String { return "str:\"\(s)\"" }
    if let i = ref as? Int { return "int:\(i)" }
    if let b = ref as? Bool { return "bool:\(b ? 1 : 0)" }
    if let n = ref as? NSNumber { return "num:\(n)" }
    return "?"
}

func getPositionAttr(_ element: AXUIElement) -> String {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &ref)
    guard let val = ref else { return "" }
    var origin = CGPoint.zero
    AXValueGetValue(val as! AXValue, .cgPoint, &origin)
    return "(\(Int(origin.x)),\(Int(origin.y)))"
}

func getSizeAttr(_ element: AXUIElement) -> String {
    var ref: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &ref)
    guard let val = ref else { return "" }
    var size = CGSize.zero
    AXValueGetValue(val as! AXValue, .cgSize, &size)
    return "\(Int(size.width))x\(Int(size.height))"
}

/// Walk the tree and collect a snapshot.
/// Returns a dict keyed by (role, title, desc, identifier) → entry.
/// If two elements share the same key, last one wins (acceptable for diagnostic).
func snapshotTree(_ element: AXUIElement, depth: Int, maxDepth: Int, into dict: inout [AXSnapshotKey: AXSnapshotEntry]) {
    if depth > maxDepth { return }

    let role = getStringAttr(element, kAXRoleAttribute)
    let title = getStringAttr(element, kAXTitleAttribute)
    let desc = getStringAttr(element, kAXDescriptionAttribute)
    let identifier = getStringAttr(element, kAXIdentifierAttribute)

    // Only keep elements that have at least a title or description (skip noise)
    if !title.isEmpty || !desc.isEmpty || !identifier.isEmpty {
        let key = AXSnapshotKey(role: role, title: title, desc: desc, identifier: identifier)
        let entry = AXSnapshotEntry(
            role: role,
            title: title,
            desc: desc,
            identifier: identifier,
            value: getValueAttr(element),
            position: getPositionAttr(element),
            size: getSizeAttr(element),
            depth: depth
        )
        dict[key] = entry
    }

    var childrenRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
    if let children = childrenRef as? [AXUIElement] {
        for child in children {
            snapshotTree(child, depth: depth + 1, maxDepth: maxDepth, into: &dict)
        }
    }
}

// MARK: - Main loop

print("=== Resolve AX Diagnostic ===")
print("Polling every \(pollInterval)s, max depth \(maxDepth)")
print("Looking for bundle id: \(resolveBundleId)")
print("Press Ctrl+C to stop.")
print("")

if !AXIsProcessTrusted() {
    print("⚠️  Accessibility permission NOT granted for this process.")
    print("    Open System Settings > Privacy & Security > Accessibility")
    print("    and add the app running this script (Terminal, iTerm, or swift).")
    print("    Then re-run this script.")
    print("")
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
    _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    exit(1)
}

var previousSnapshot: [AXSnapshotKey: AXSnapshotEntry] = [:]
var pollCount = 0
var resolveWasRunning = false

// Schedule the polling timer
let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
    pollCount += 1

    guard let resolveApp = findResolveApp() else {
        if resolveWasRunning {
            print("[\(timestamp())] Resolve quit.")
            resolveWasRunning = false
            previousSnapshot.removeAll()
        }
        return
    }
    if !resolveWasRunning {
        print("[\(timestamp())] Resolve found. PID=\(resolveApp.processIdentifier). Active: \(resolveApp.isActive)")
        resolveWasRunning = true
    }

    let appElement = AXUIElementCreateApplication(resolveApp.processIdentifier)
    guard let mainWindow = getMainWindow(appElement: appElement) else {
        print("[\(timestamp())] poll #\(pollCount): no main/focused window")
        return
    }

    var snapshot: [AXSnapshotKey: AXSnapshotEntry] = [:]
    snapshotTree(mainWindow, depth: 0, maxDepth: maxDepth, into: &snapshot)

    // First poll: just dump stats + every checkbox/button/toggle we found
    if previousSnapshot.isEmpty {
        print("[\(timestamp())] poll #\(pollCount): INITIAL SNAPSHOT — \(snapshot.count) elements with title/desc/id")

        // Print every AXCheckBox, AXButton, AXRadioButton, AXTab we found
        let interestingRoles = ["AXCheckBox", "AXButton", "AXRadioButton", "AXTab", "AXTabGroup", "AXPopUpButton"]
        var found = 0
        for (key, entry) in snapshot.sorted(by: { $0.key.title < $1.key.title }) {
            if interestingRoles.contains(key.role) {
                print("  → [\(key.role)] title=\"\(key.title)\" desc=\"\(key.desc)\" id=\"\(key.identifier)\" value=\(entry.value) pos=\(entry.position) size=\(entry.size)")
                found += 1
            }
        }
        if found == 0 {
            print("  ⚠️  No checkboxes/buttons/tabs found. Dumping ALL titled elements:")
            for (key, entry) in snapshot.sorted(by: { $0.key.title < $1.key.title }) {
                print("    [\(key.role)] title=\"\(key.title)\" desc=\"\(key.desc)\" value=\(entry.value)")
            }
        }

        previousSnapshot = snapshot
        return
    }

    // Subsequent polls: print diff
    var additions: [AXSnapshotEntry] = []
    var removals: [AXSnapshotEntry] = []
    var valueChanges: [(old: AXSnapshotEntry, new: AXSnapshotEntry)] = []

    for (key, newEntry) in snapshot {
        if let oldEntry = previousSnapshot[key] {
            if oldEntry.value != newEntry.value {
                valueChanges.append((old: oldEntry, new: newEntry))
            }
        } else {
            additions.append(newEntry)
        }
    }
    for (key, oldEntry) in previousSnapshot {
        if snapshot[key] == nil {
            removals.append(oldEntry)
        }
    }

    if additions.isEmpty && removals.isEmpty && valueChanges.isEmpty {
        // No change — print a heartbeat every 10 polls so user knows it's alive
        if pollCount % 10 == 0 {
            print("[\(timestamp())] poll #\(pollCount): no change (\(snapshot.count) elements)")
        }
    } else {
        print("[\(timestamp())] poll #\(pollCount): CHANGE DETECTED")
        for e in additions {
            print("  + [\(e.role)] title=\"\(e.title)\" desc=\"\(e.desc)\" id=\"\(e.identifier)\" value=\(e.value) pos=\(e.position)")
        }
        for e in removals {
            print("  - [\(e.role)] title=\"\(e.title)\" desc=\"\(e.desc)\" id=\"\(e.identifier)\" value=\(e.value)")
        }
        for c in valueChanges {
            print("  ~ [\(c.old.role)] title=\"\(c.old.title)\" desc=\"\(c.old.desc)\" id=\"\(c.old.identifier)\"")
            print("      \(c.old.value)  →  \(c.new.value)")
        }
    }

    previousSnapshot = snapshot
}

// Keep the run loop alive
RunLoop.current.add(timer, forMode: .common)
RunLoop.current.run()

// MARK: - Helpers

func timestamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}
