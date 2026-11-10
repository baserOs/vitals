import AppKit
import SwiftUI

/// Opens the dashboard and settings windows. The windows are created on
/// demand and thrown away when closed, so a closed window costs nothing.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()

    private var windows: [String: NSWindow] = [:]

    /// True while any window opened here is on screen.
    var hasVisibleWindow: Bool {
        windows.values.contains { $0.isVisible }
    }

    func show<Content: View>(id: String, title: String, size: NSSize, minSize: NSSize?,
                             @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let resizable = minSize != nil
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style,
                              backing: .buffered, defer: false)
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        if let minSize = minSize { window.contentMinSize = minSize }
        window.center()
        window.delegate = self
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = window.identifier?.rawValue else { return }
        windows[id] = nil
    }
}

/// Tracks whether the menu bar popover is on screen.
final class PopoverVisibility: ObservableObject {
    static let shared = PopoverVisibility()

    /// Starts true and only turns false on a clear signal that the popover
    /// closed, so a missed signal costs a little CPU rather than a blank popover.
    @Published var isVisible = true

    /// False until the popover has been opened for the first time.
    var hasAppeared = false

    /// True while the popover is actually open.
    var isOpen: Bool { hasAppeared && isVisible }
}

/// An invisible view that reports when the window it sits in is shown or hidden.
struct WindowVisibilityReporter: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onChange = onChange
    }

    final class ReportingView: NSView {
        var onChange: ((Bool) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            guard let window = window else { return }
            center.addObserver(self, selector: #selector(occlusionChanged(_:)),
                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
            center.addObserver(self, selector: #selector(becameKey(_:)),
                               name: NSWindow.didBecomeKeyNotification, object: window)
        }

        @objc private func occlusionChanged(_ notification: Notification) {
            guard let window = window else { return }
            onChange?(window.occlusionState.contains(.visible))
        }

        @objc private func becameKey(_ notification: Notification) {
            onChange?(true)
        }
    }
}
