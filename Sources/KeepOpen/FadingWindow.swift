import AppKit
import SwiftUI

/// MenuBarExtra's window ships with no order-out animation, so it vanishes on an
/// outside click. Giving it the utility-window behavior makes AppKit fade it out,
/// like the system's own menu bar popovers.
struct FadingWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowHook() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowHook: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window.animationBehavior != .utilityWindow else { return }
            log.debug("Menu bar window animation was \(window.animationBehavior.rawValue)")
            window.animationBehavior = .utilityWindow
        }
    }
}
