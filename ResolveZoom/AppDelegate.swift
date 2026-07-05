import Carbon
import Cocoa
import SwiftUI

struct ShortcutSpec {
    let label: String
    let keycode: UInt32
    let modifiers: UInt32
    let swiftModifiers: NSEvent.ModifierFlags
}

let shortcutOptions: [ShortcutSpec] = [
    .init(
        label: "⌥⌘Z", keycode: UInt32(kVK_ANSI_Z), modifiers: UInt32(optionKey | cmdKey),
        swiftModifiers: [.option, .command]),
    .init(
        label: "⌃⌘Z", keycode: UInt32(kVK_ANSI_Z), modifiers: UInt32(controlKey | cmdKey),
        swiftModifiers: [.control, .command]),
    .init(
        label: "⌥⌘P", keycode: UInt32(kVK_ANSI_P), modifiers: UInt32(optionKey | cmdKey),
        swiftModifiers: [.option, .command]),
    .init(
        label: "⇧⌘Z", keycode: UInt32(kVK_ANSI_Z), modifiers: UInt32(shiftKey | cmdKey),
        swiftModifiers: [.shift, .command]),
    .init(label: "F13", keycode: UInt32(kVK_F13), modifiers: 0, swiftModifiers: []),
    .init(label: "F14", keycode: UInt32(kVK_F14), modifiers: 0, swiftModifiers: []),
    .init(label: "F15", keycode: UInt32(kVK_F15), modifiers: 0, swiftModifiers: []),
]

let resolvePageNames: [String] = [
    "Media", "Cut", "Edit", "Fusion", "Color", "Fairlight", "Deliver",
]

private struct StatusPill: View {
    let isActive: Bool
    let isPaused: Bool
    let pauseReason: String?
    let activePage: String?

    private var color: Color {
        if isPaused { return .gray }
        return isActive ? .green : .orange
    }

    private var text: String {
        if isPaused {
            if let reason = pauseReason { return "Paused (\(reason))" }
            return "Paused"
        }
        if isActive, let page = activePage {
            return "Resolve — \(page)"
        }
        return isActive ? "Resolve active" : "Waiting for Resolve"
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
    }
}


struct PreferencesView: View {
    @State private var multiplier: Double
    @State private var invertZoom: Bool
    @State private var launchAtLogin: Bool
    @State private var smoothingEnabled: Bool
    @State private var smoothingIntensity: Double
    @State private var threshold: Int
    @State private var curveEnabled: Bool
    @State private var autoDetectFusion: Bool
    @State private var shortcutIndex: Int

    let isResolveActive: Bool
    let isPaused: Bool
    let pauseReason: String?
    let activePage: String?
    let onSave: (Double, Bool, Bool, Bool, Double, Int, Bool, Bool, Int) -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    private let defaultMultiplier = 800.0
    private let defaultSmoothingIntensity = 0.3
    private let defaultThreshold = 2

    init(
        multiplier: Double, invertZoom: Bool, launchAtLogin: Bool,
        smoothingEnabled: Bool, smoothingIntensity: Double, threshold: Int,
        curveEnabled: Bool, autoDetectFusion: Bool, shortcutIndex: Int,
        isResolveActive: Bool, isPaused: Bool, pauseReason: String?, activePage: String?,
        onSave: @escaping (Double, Bool, Bool, Bool, Double, Int, Bool, Bool, Int) -> Void,
        onCancel: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) {
        _multiplier = State(initialValue: multiplier)
        _invertZoom = State(initialValue: invertZoom)
        _launchAtLogin = State(initialValue: launchAtLogin)
        _smoothingEnabled = State(initialValue: smoothingEnabled)
        _smoothingIntensity = State(initialValue: smoothingIntensity)
        _threshold = State(initialValue: threshold)
        _curveEnabled = State(initialValue: curveEnabled)
        _autoDetectFusion = State(initialValue: autoDetectFusion)
        _shortcutIndex = State(initialValue: shortcutIndex)
        self.isResolveActive = isResolveActive
        self.isPaused = isPaused
        self.pauseReason = pauseReason
        self.activePage = activePage
        self.onSave = onSave
        self.onCancel = onCancel
        self.onReset = onReset
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ResolveZoom")
                        .font(.headline)
                    Text("Pinch the trackpad to zoom the timeline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(
                    isActive: isResolveActive, isPaused: isPaused,
                    pauseReason: pauseReason, activePage: activePage)

                Button(action: onReset) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset all settings to defaults")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            Form {
                Section {
                    HStack {
                        Slider(value: $multiplier, in: 100...1500) { Text("Sensitivity") }
                        Text("\(Int(multiplier))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                } header: {
                    Text("Sensitivity")
                } footer: {
                    Text("Higher = more zoom per pinch. 600–800 is a good starting point.")
                }

                Section {
                    Toggle("Enable smoothing", isOn: $smoothingEnabled)
                    if smoothingEnabled {
                        HStack {
                            Slider(value: $smoothingIntensity, in: 0.1...0.9) { Text("Intensity") }
                            Text("\(Int(smoothingIntensity * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                } header: {
                    Text("Apple-like smoothing")
                } footer: {
                    Text("Low-pass filter for a softer feel. 15–25% is plenty.")
                }

                Section {
                    Toggle("Non-linear zoom curve (acceleration)", isOn: $curveEnabled)
                } header: {
                    Text("Precision")
                } footer: {
                    Text("Small pinches become extra-precise, large pinches zoom faster.")
                }

                Section {
                    Toggle("Auto-detect Fusion page", isOn: $autoDetectFusion)
                    Picker("Pause shortcut", selection: $shortcutIndex) {
                        ForEach(shortcutOptions.indices, id: \.self) { idx in
                            Text(shortcutOptions[idx].label).tag(idx)
                        }
                    }
                } header: {
                    Text("Fusion page handling")
                } footer: {
                    Text(
                        "Watches Resolve's page checkboxes via the Accessibility API and auto-pauses when Fusion is active. Event-driven — zero CPU when idle."
                    )
                }

                Section {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Stepper(value: $threshold, in: 1...5) {
                            Text("\(threshold) event\(threshold == 1 ? "" : "s")")
                                .monospacedDigit()
                        }
                    }
                    Toggle("Invert zoom direction", isOn: $invertZoom)
                } header: {
                    Text("Gesture recognition")
                } footer: {
                    Text("Consecutive events required before the gesture is recognized.")
                }

                Section {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                } header: {
                    Text("System")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Apply") {
                    onSave(
                        multiplier, invertZoom, launchAtLogin,
                        smoothingEnabled, smoothingIntensity, threshold,
                        curveEnabled, autoDetectFusion, shortcutIndex)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 820)
    }
}

class DebugLogWindow {
    private var window: NSWindow?
    private var textView: NSTextView?
    private var lines: [String] = []
    private let maxLines = 500

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false)
        w.title = "ResolveZoom — Debug Log"
        w.isReleasedWhenClosed = false
        w.center()

        let scrollView = NSScrollView(frame: w.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder

        let tv = NSTextView(frame: scrollView.bounds)
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.backgroundColor = NSColor.textBackgroundColor
        tv.textColor = NSColor.textColor
        tv.autoresizingMask = [.width, .height]
        tv.isHorizontallyResizable = true
        tv.isVerticallyResizable = true
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.size = NSSize(width: 10000, height: 10000)

        scrollView.documentView = tv
        w.contentView = scrollView

        textView = tv
        window = w

        // Re-render accumulated lines
        let allText = lines.joined(separator: "\n")
        tv.string = allText
        scrollToBottom()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func append(_ line: String) {
        let stamped = "[\(timestamp())] \(line)"
        lines.append(stamped)
        if lines.count > maxLines { lines.removeFirst(lines.count - maxLines) }

        guard let tv = textView else { return }
        let attributed = NSAttributedString(
            string: stamped + "\n",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.textColor,
            ])
        tv.textStorage?.append(attributed)
        scrollToBottom()
    }

    private func scrollToBottom() {
        guard let tv = textView else { return }
        let len = tv.string.count
        let range = NSRange(location: len, length: 0)
        tv.scrollRangeToVisible(range)
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var tap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var permissionTimer: Timer?
    var fusionPollTimer: Timer?

    var statusMenuItem: NSMenuItem!
    var pauseMenuItem: NSMenuItem!
    var debugMenuItem: NSMenuItem!
    var permissionsWindow: NSWindow?
    var preferencesWindow: NSWindow?

    let debugLog = DebugLogWindow()

    let defaults = UserDefaults.standard

    let defaultMultiplier: Double = 800.0
    let defaultSmoothingIntensity: Double = 0.3
    let defaultThreshold: Int = 2
    let defaultCurveEnabled: Bool = true
    let defaultAutoDetectFusion: Bool = false
    let defaultShortcutIndex: Int = 0

    var multiplier: Double = 800.0
    var invertZoom: Bool = false
    var smoothingEnabled: Bool = false
    var smoothingIntensity: Double = 0.3
    var magnifyCountThreshold: Int = 2
    var curveEnabled: Bool = true
    var autoDetectFusionEnabled: Bool = false
    var shortcutIndex: Int = 0
    var isManuallyPaused: Bool = false
    var autoPausedForFusion: Bool = false

    var isPaused: Bool { isManuallyPaused || autoPausedForFusion }

    var pauseReason: String? {
        if isManuallyPaused && autoPausedForFusion { return "manual + fusion" }
        if isManuallyPaused { return "manual" }
        if autoPausedForFusion { return "fusion" }
        return nil
    }
    var lastMagnifyTime: Double = 0
    var lastMagnifySign: Double = 0
    var lastHorizontalScrollTime: Double = 0
    var consecutiveMagnifyCount: Int = 0
    let magnifyTimeWindow: Double = 0.3
    var zoomAccumulator: Double = 0
    var smoothedMag: Double = 0
    var cachedFrontmostBundleId: String? = nil
    var currentActivePage: String? = nil
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadSettings()
        setupMenuBar()
        registerGlobalHotKey()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(resolveLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(resolveTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        refreshFrontmostApp()

        checkAccessibilityAndStart()

        log("ResolveZoom started. Auto-detect Fusion: \(autoDetectFusionEnabled ? "ON" : "OFF")")
    }
    func log(_ msg: String) {
        debugLog.append(msg)
        // Also print to Console.app for developer debugging
        NSLog("[ResolveZoom] %@", msg)
    }
    func loadSettings() {
        multiplier =
            defaults.object(forKey: "multiplier") == nil
            ? defaultMultiplier : defaults.double(forKey: "multiplier")
        invertZoom = defaults.bool(forKey: "invertZoom")
        smoothingEnabled = defaults.bool(forKey: "smoothingEnabled")
        smoothingIntensity =
            defaults.object(forKey: "smoothingIntensity") == nil
            ? defaultSmoothingIntensity : defaults.double(forKey: "smoothingIntensity")
        let storedThreshold = defaults.integer(forKey: "threshold")
        magnifyCountThreshold = storedThreshold == 0 ? defaultThreshold : storedThreshold
        curveEnabled =
            defaults.object(forKey: "curveEnabled") == nil
            ? defaultCurveEnabled : defaults.bool(forKey: "curveEnabled")
        autoDetectFusionEnabled = defaults.bool(forKey: "autoDetectFusion")
        shortcutIndex =
            defaults.object(forKey: "shortcutIndex") == nil
            ? defaultShortcutIndex : defaults.integer(forKey: "shortcutIndex")
    }

    func saveSettings(
        mult: Double, invert: Bool, login: Bool,
        smooth: Bool, intensity: Double, threshold: Int,
        curve: Bool, autoFusion: Bool, shortcutIdx: Int
    ) {
        multiplier = mult
        invertZoom = invert
        smoothingEnabled = smooth
        smoothingIntensity = intensity
        magnifyCountThreshold = threshold
        curveEnabled = curve
        autoDetectFusionEnabled = autoFusion
        shortcutIndex = shortcutIdx

        defaults.set(mult, forKey: "multiplier")
        defaults.set(invert, forKey: "invertZoom")
        defaults.set(smooth, forKey: "smoothingEnabled")
        defaults.set(intensity, forKey: "smoothingIntensity")
        defaults.set(threshold, forKey: "threshold")
        defaults.set(curve, forKey: "curveEnabled")
        defaults.set(autoFusion, forKey: "autoDetectFusion")
        defaults.set(shortcutIdx, forKey: "shortcutIndex")

        setAutolaunch(login)

        smoothedMag = 0
        zoomAccumulator = 0

        unregisterGlobalHotKey()
        registerGlobalHotKey()
        updatePauseMenuItem()

        // Re-evaluate observers based on autoDetectFusionEnabled
        reconfigureFusionDetection()
    }

    func resetToDefaults() {
        saveSettings(
            mult: defaultMultiplier,
            invert: false,
            login: isAutolaunchEnabled(),
            smooth: false,
            intensity: defaultSmoothingIntensity,
            threshold: defaultThreshold,
            curve: defaultCurveEnabled,
            autoFusion: defaultAutoDetectFusion,
            shortcutIdx: defaultShortcutIndex)
    }
    @objc func frontmostAppChanged() {
        DispatchQueue.main.async {
            self.refreshFrontmostApp()
            self.updateStatus()
        }
    }

    func refreshFrontmostApp() {
        cachedFrontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    // Strategy: Resolve is a Qt app. Qt on macOS is known to destroy and
    // recreate AX elements when the UI changes (rather than mutating existing
    // ones). Testing confirmed that page checkboxes are reparented under
    // different windows when switching pages — so AXObserver references
    // captured at startup become stale and never fire.
    //
    // The robust approach: poll every 1 second, re-scan the AX tree each
    // time (don't cache), early-exit as soon as the active checkbox is found.
    // 4 early-returns keep the cost near zero when polling isn't needed.

    func reconfigureFusionDetection() {
        if autoDetectFusionEnabled && AXIsProcessTrusted() {
            startFusionPolling()
        } else {
            stopFusionPolling()
            if autoPausedForFusion {
                autoPausedForFusion = false
                currentActivePage = nil
                updateStatus()
            }
        }
    }

    func startFusionPolling() {
        fusionPollTimer?.invalidate()
        // Run one immediate poll so the user sees the effect without waiting 1s
        pollActiveResolvePage()
        fusionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            self?.pollActiveResolvePage()
        }
    }

    func stopFusionPolling() {
        fusionPollTimer?.invalidate()
        fusionPollTimer = nil
    }

    @objc func resolveLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier == "com.blackmagic-design.DaVinciResolve"
        else { return }
        log("Resolve launched. Polling will pick it up automatically.")
    }

    @objc func resolveTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier == "com.blackmagic-design.DaVinciResolve"
        else { return }
        log("Resolve terminated.")
        if autoPausedForFusion || currentActivePage != nil {
            autoPausedForFusion = false
            currentActivePage = nil
            updateStatus()
        }
    }

    /// Single poll pass: re-scan Resolve's AX tree, find the active page checkbox.
    /// 4 early returns keep cost near zero when polling isn't actually needed.
    func pollActiveResolvePage() {
        // Early return 1: feature disabled
        guard autoDetectFusionEnabled else { return }

        // Early return 2: manually paused — we're paused anyway, no need to detect
        if isManuallyPaused { return }

        // Early return 3: no accessibility permission
        guard AXIsProcessTrusted() else { return }

        // Early return 4: Resolve not running / not frontmost
        guard
            let resolveApp = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.blackmagic-design.DaVinciResolve" }),
            resolveApp.isActive
        else { return }

        let pid = resolveApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get main window — re-fetched each poll because Qt may swap windows too
        var mainWindowRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
            appElement, kAXMainWindowAttribute as CFString, &mainWindowRef)
        // Fallback to focused window if main window is nil (modal panels etc.)
        if mainWindowRef == nil {
            AXUIElementCopyAttributeValue(
                appElement, kAXFocusedWindowAttribute as CFString, &mainWindowRef)
        }
        guard let mainWindow = mainWindowRef else { return }

        // Re-scan the tree each poll. Don't cache — elements may have been destroyed.
        let activePage = scanForActivePage(in: mainWindow as! AXUIElement, depth: 0, maxDepth: 10)

        // Only update state + log if it actually changed
        if activePage != currentActivePage {
            currentActivePage = activePage
            if let page = activePage {
                log("✓ Active page: \(page)")
                let shouldPause = (page.lowercased() == "fusion")
                if shouldPause != autoPausedForFusion {
                    autoPausedForFusion = shouldPause
                    log("  → auto-pause set to \(shouldPause)")
                    updateStatus()
                }
            } else {
                log("No active page checkbox found this poll (Resolve UI may be loading).")
                if autoPausedForFusion {
                    autoPausedForFusion = false
                    updateStatus()
                }
            }
            updateStatus()
        }
    }

    /// Recursive scan that returns the name of the page checkbox whose value == 1.
    /// Returns nil if no active page is found. Stops early as soon as found.
    /// Re-scans every call — no caching — because Qt destroys AX elements on page changes.
    ///
    /// IMPORTANT: Resolve's page tab checkboxes (Media/Cut/Edit/Fusion/Color/Fairlight/Deliver)
    /// have an EMPTY AXTitle. The page name is in AXDescription. This was the bug
    /// that prevented detection from working — confirmed via resolve_ax_diag.swift.
    func scanForActivePage(in element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        if depth > maxDepth { return nil }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""

        if role == "AXCheckBox" {
            // Try AXTitle first (standard) — falls back to AXDescription (Resolve's case)
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            var title = (titleRef as? String) ?? ""

            // Resolve stores page names in AXDescription, not AXTitle
            if title.isEmpty {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(
                    element, kAXDescriptionAttribute as CFString, &descRef)
                title = (descRef as? String) ?? ""
            }

            if resolvePageNames.contains(title) {
                var valueRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
                let v: Int
                if let intVal = valueRef as? Int {
                    v = intVal
                } else if let boolVal = valueRef as? Bool {
                    v = boolVal ? 1 : 0
                } else if let numVal = valueRef as? NSNumber {
                    v = numVal.intValue
                } else {
                    v = 0
                }

                if v == 1 {
                    return title  // found it — bubble up
                }
                // Wrong checkbox — don't recurse from here, but keep scanning siblings
                return nil
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = scanForActivePage(in: child, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        return nil
    }
    func registerGlobalHotKey() {
        let eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData = userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                delegate.toggleManuallyPaused()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback, 1, [eventSpec], selfPtr, &eventHandlerRef)

        guard shortcutIndex >= 0 && shortcutIndex < shortcutOptions.count else { return }
        let spec = shortcutOptions[shortcutIndex]
        let hotKeyID = EventHotKeyID(signature: OSType(0x525A_5F48), id: 1)
        RegisterEventHotKey(
            spec.keycode, spec.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregisterGlobalHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    @objc func toggleManuallyPaused() {
        isManuallyPaused = !isManuallyPaused
        smoothedMag = 0
        zoomAccumulator = 0
        consecutiveMagnifyCount = 0
        updatePauseMenuItem()
        updateStatus()
        log("Manual pause toggled: \(isManuallyPaused)")
    }

    func updatePauseMenuItem() {
        let spec = shortcutOptions[shortcutIndex]
        pauseMenuItem.title =
            isManuallyPaused
            ? "Resume ResolveZoom"
            : "Pause ResolveZoom"
        pauseMenuItem.keyEquivalent = keycodeToKeyEquivalent(spec.keycode)
        pauseMenuItem.keyEquivalentModifierMask = spec.swiftModifiers
    }

    func keycodeToKeyEquivalent(_ keycode: UInt32) -> String {
        switch Int(keycode) {
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_P: return "p"
        default: return ""
        }
    }
    func checkAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            setupEventTap()
            updateStatus()
            startPermissionWatchdog()
            reconfigureFusionDetection()
        } else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            AXIsProcessTrustedWithOptions(options as CFDictionary)

            showPermissionsWindow()

            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    DispatchQueue.main.async {
                        self?.permissionsWindow?.close()
                        self?.permissionsWindow = nil
                        self?.setupEventTap()
                        self?.updateStatus()
                        self?.startPermissionWatchdog()
                        self?.reconfigureFusionDetection()
                    }
                }
            }
        }
    }

    func startPermissionWatchdog() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            if !AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self.disableEventTap()
                    self.updateStatus()
                    self.stopFusionPolling()
                    self.checkAccessibilityAndStart()
                }
            }
        }
    }

    func disableEventTap() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    func showPermissionsWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "ResolveZoom"
        w.isReleasedWhenClosed = false
        w.center()
        w.level = .floating

        let cv = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 190))

        let icon = NSImageView(frame: NSRect(x: 24, y: 120, width: 44, height: 44))
        icon.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
        icon.contentTintColor = .systemOrange
        cv.addSubview(icon)

        let titleLabel = NSTextField(labelWithString: "Accessibility permission required")
        titleLabel.frame = NSRect(x: 82, y: 146, width: 340, height: 20)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        cv.addSubview(titleLabel)

        let desc = NSTextField(
            wrappingLabelWithString:
                "ResolveZoom needs Accessibility access to detect pinch gestures. Click the button below, then find ResolveZoom in the list and toggle the switch ON."
        )
        desc.frame = NSRect(x: 82, y: 82, width: 340, height: 60)
        desc.font = NSFont.systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        cv.addSubview(desc)

        let quitBtn = NSButton(title: "Quit", target: self, action: #selector(quit))
        quitBtn.frame = NSRect(x: 24, y: 24, width: 80, height: 32)
        quitBtn.bezelStyle = .rounded
        cv.addSubview(quitBtn)

        let openBtn = NSButton(
            title: "Open Accessibility Settings", target: self,
            action: #selector(openAccessibilitySettings))
        openBtn.frame = NSRect(x: 220, y: 24, width: 200, height: 32)
        openBtn.bezelStyle = .rounded
        openBtn.keyEquivalent = "\r"
        cv.addSubview(openBtn)

        w.contentView = cv
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        permissionsWindow = w
    }

    @objc func openAccessibilitySettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }
    func setupEventTap() {
        disableEventTap()

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, userInfoPtr in
            return autoreleasepool {
                guard let ptr = userInfoPtr else { return Unmanaged.passUnretained(event) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(ptr).takeUnretainedValue()

                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    DispatchQueue.main.async {
                        if AXIsProcessTrusted(), let tap = delegate.tap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        } else {
                            delegate.disableEventTap()
                            delegate.updateStatus()
                            delegate.checkAccessibilityAndStart()
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                let kMagnify = CGEventType(rawValue: 29)!
                let kField = CGEventField(rawValue: 113)!

                if type == CGEventType.scrollWheel {
                    let deltaH1 = event.getDoubleValueField(CGEventField(rawValue: 12)!)
                    let deltaH2 = event.getDoubleValueField(CGEventField(rawValue: 97)!)
                    if abs(deltaH1) > 0 || abs(deltaH2) > 0 {
                        delegate.lastHorizontalScrollTime = CFAbsoluteTimeGetCurrent()
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == kMagnify else { return Unmanaged.passUnretained(event) }

                if delegate.isPaused {
                    return Unmanaged.passUnretained(event)
                }

                if CFAbsoluteTimeGetCurrent() - delegate.lastHorizontalScrollTime < 0.1 {
                    return Unmanaged.passUnretained(event)
                }

                guard
                    delegate.cachedFrontmostBundleId
                        == "com.blackmagic-design.DaVinciResolve"
                else {
                    return Unmanaged.passUnretained(event)
                }

                let rawMag = event.getDoubleValueField(kField)
                guard abs(rawMag) < 0.5 && abs(rawMag) > 0.005 else {
                    return Unmanaged.passUnretained(event)
                }

                let now = CFAbsoluteTimeGetCurrent()
                let timeSinceLastMagnify = now - delegate.lastMagnifyTime

                let currentSign = rawMag > 0 ? 1.0 : -1.0
                let isSignFlip =
                    currentSign != delegate.lastMagnifySign && delegate.lastMagnifySign != 0
                let isQuickFlip = timeSinceLastMagnify < 0.1

                if timeSinceLastMagnify > delegate.magnifyTimeWindow {
                    delegate.consecutiveMagnifyCount = 0
                    delegate.zoomAccumulator = 0
                    delegate.smoothedMag = 0
                }

                delegate.lastMagnifySign = currentSign
                delegate.lastMagnifyTime = now
                delegate.consecutiveMagnifyCount += 1

                if isSignFlip && isQuickFlip {
                    delegate.zoomAccumulator = 0
                    delegate.smoothedMag = 0
                    return Unmanaged.passUnretained(event)
                }

                guard delegate.consecutiveMagnifyCount >= delegate.magnifyCountThreshold else {
                    return Unmanaged.passUnretained(event)
                }

                let curvedMag: Double
                if delegate.curveEnabled {
                    let sign: Double = rawMag > 0 ? 1 : -1
                    curvedMag = sign * pow(abs(rawMag), 1.3)
                } else {
                    curvedMag = rawMag
                }

                let effectiveMag: Double
                if delegate.smoothingEnabled {
                    let alpha = 1.0 - delegate.smoothingIntensity
                    delegate.smoothedMag = alpha * curvedMag + (1 - alpha) * delegate.smoothedMag
                    effectiveMag = delegate.smoothedMag
                } else {
                    delegate.smoothedMag = curvedMag
                    effectiveMag = curvedMag
                }

                let direction: Double = delegate.invertZoom ? 1.0 : -1.0
                let delta = effectiveMag * direction * delegate.multiplier

                delegate.zoomAccumulator += delta
                let intDelta = Int32(delegate.zoomAccumulator)

                guard intDelta != 0 else {
                    return Unmanaged.passUnretained(event)
                }

                delegate.zoomAccumulator -= Double(intDelta)

                let cgPoint = event.location

                let absDelta = abs(intDelta)
                let sign: Int32 = intDelta > 0 ? 1 : -1
                let chunkSize: Int32 = 4

                var remaining = absDelta
                while remaining > 0 {
                    let chunk = min(remaining, chunkSize) * sign
                    if let scrollEvent = CGEvent(
                        scrollWheelEvent2Source: nil, units: .pixel,
                        wheelCount: 1, wheel1: chunk, wheel2: 0, wheel3: 0
                    ) {
                        scrollEvent.flags = .maskAlternate
                        scrollEvent.location = cgPoint
                        scrollEvent.post(tap: .cghidEventTap)
                    }
                    remaining -= abs(chunk)
                }

                return nil
            }
        }

        let mask: CGEventMask = (1 << 29) | (1 << 22)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        )
        guard let tap = tap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true

        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = NSMenuItem()
        let titleStr = NSMutableAttributedString(
            string: "ResolveZoom\n",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        titleStr.append(
            NSAttributedString(
                string: "Version: 0.8  ·  © Marcin Kuśnierz",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        titleItem.attributedTitle = titleStr
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        statusMenuItem = NSMenuItem(title: "Checking permissions…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        pauseMenuItem = NSMenuItem(
            title: "Pause ResolveZoom",
            action: #selector(toggleManuallyPaused),
            keyEquivalent: "z")
        pauseMenuItem.keyEquivalentModifierMask = [.option, .command]
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)
        updatePauseMenuItem()

        debugMenuItem = NSMenuItem(
            title: "Show Debug Log",
            action: #selector(showDebugLog),
            keyEquivalent: "d")
        debugMenuItem.keyEquivalentModifierMask = [.option, .command]
        debugMenuItem.target = self
        menu.addItem(debugMenuItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit ResolveZoom", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateMenuBarIcon()
    }

    @objc func showDebugLog() {
        debugLog.show()
    }

    func updateMenuBarIcon() {
        guard let btn = statusItem.button else { return }
        let symbolName =
            isPaused
            ? "arrow.up.left.and.arrow.down.right.circle.dashed"
            : "arrow.up.left.and.arrow.down.right"
        let img = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "ResolveZoom")
        img?.isTemplate = true
        btn.image = img
    }
    @objc func openPreferences() {
        if let win = preferencesWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let isResolveActive =
            cachedFrontmostBundleId
            == "com.blackmagic-design.DaVinciResolve"

        let view = PreferencesView(
            multiplier: multiplier,
            invertZoom: invertZoom,
            launchAtLogin: isAutolaunchEnabled(),
            smoothingEnabled: smoothingEnabled,
            smoothingIntensity: smoothingIntensity,
            threshold: magnifyCountThreshold,
            curveEnabled: curveEnabled,
            autoDetectFusion: autoDetectFusionEnabled,
            shortcutIndex: shortcutIndex,
            isResolveActive: isResolveActive,
            isPaused: isPaused,
            pauseReason: pauseReason,
            activePage: currentActivePage,
            onSave: {
                [weak self]
                mult, invert, login, smooth, intensity, thresh, curve, autoFusion, shortcutIdx in
                guard let self = self else { return }
                self.saveSettings(
                    mult: mult, invert: invert, login: login,
                    smooth: smooth, intensity: intensity,
                    threshold: thresh, curve: curve,
                    autoFusion: autoFusion, shortcutIdx: shortcutIdx)
                self.preferencesWindow?.close()
                self.reopenPreferencesToShowNewValues()
            },
            onCancel: { [weak self] in
                self?.preferencesWindow?.close()
            },
            onReset: { [weak self] in
                guard let self = self else { return }
                self.resetToDefaults()
                self.preferencesWindow?.close()
                self.reopenPreferencesToShowNewValues()
            }
        )

        let controller = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: controller)
        w.title = "Preferences"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = w
    }

    private func reopenPreferencesToShowNewValues() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.openPreferences()
        }
    }
    func updateStatus() {
        guard let item = statusMenuItem else { return }
        let (text, color): (String, NSColor) = {
            if !AXIsProcessTrusted() {
                return ("⬤  No accessibility permission", .systemRed)
            }
            if isPaused {
                let reason = pauseReason ?? "?"
                return ("⬤  Paused (\(reason)) — native pinch active", .systemOrange)
            }
            let isResolve =
                cachedFrontmostBundleId
                == "com.blackmagic-design.DaVinciResolve"
            if isResolve, let page = currentActivePage {
                return ("⬤  Resolve — \(page)", .systemGreen)
            }
            return isResolve
                ? ("⬤  DaVinci Resolve active", .systemGreen)
                : ("⬤  Waiting for Resolve…", .secondaryLabelColor)
        }()
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 13),
            ])
        updateMenuBarIcon()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func isAutolaunchEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL().path)
    }

    func setAutolaunch(_ enable: Bool) {
        let url = launchAgentURL()
        if enable {
            let execPath = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
            let plist: [String: Any] = [
                "Label": "com.resolvezoom.app",
                "ProgramArguments": [execPath],
                "RunAtLoad": true,
                "KeepAlive": false,
            ]
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            (plist as NSDictionary).write(to: url, atomically: true)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func launchAgentURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.resolvezoom.app.plist")
    }
}
