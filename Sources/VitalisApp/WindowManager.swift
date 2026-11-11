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

/// An invisible view that reports when the window it sits in is shown or
/// hidden, and thins out the system panel drawn behind that window.
struct WindowVisibilityReporter: NSViewRepresentable {
    /// 1 leaves the system panel as it is; lower lets more of the desktop through.
    var backdropOpacity: Double = 1
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onChange = onChange
        view.backdropOpacity = backdropOpacity
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onChange = onChange
        nsView.backdropOpacity = backdropOpacity
    }

    final class ReportingView: NSView {
        var onChange: ((Bool) -> Void)?
        var backdropOpacity: Double = 1 {
            didSet {
                if backdropOpacity != oldValue { applyBackdropOpacity() }
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            guard let window = window else { return }
            center.addObserver(self, selector: #selector(occlusionChanged(_:)),
                               name: NSWindow.didChangeOcclusionStateNotification, object: window)
            center.addObserver(self, selector: #selector(becameKey(_:)),
                               name: NSWindow.didBecomeKeyNotification, object: window)
            applyBackdropOpacity()
        }

        @objc private func occlusionChanged(_ notification: Notification) {
            guard let window = window else { return }
            applyBackdropOpacity()
            onChange?(window.occlusionState.contains(.visible))
        }

        @objc private func becameKey(_ notification: Notification) {
            applyBackdropOpacity()
            onChange?(true)
        }

        /// Fades the system's own background panel, and nothing else: a
        /// panel that holds the content is left alone, because fading it
        /// would fade the text with it, and the content itself is never
        /// entered. Does nothing if the system draws no such panel.
        private func applyBackdropOpacity() {
            guard let window = window, let content = window.contentView else { return }
            let alpha = CGFloat(min(1, max(0.2, backdropOpacity)))
            var pending: [NSView] = [content.superview ?? content]
            var visited = 0
            while let view = pending.popLast(), visited < 200 {
                visited += 1
                let isBackdrop = view is NSVisualEffectView
                    || String(describing: type(of: view)).contains("GlassEffect")
                if isBackdrop, !isDescendant(of: view) {
                    if view.alphaValue != alpha { view.alphaValue = alpha }
                    continue
                }
                // The views that draw the readings start here.
                if String(describing: type(of: view)).contains("Hosting") {
                    continue
                }
                pending.append(contentsOf: view.subviews)
            }
        }
    }
}
