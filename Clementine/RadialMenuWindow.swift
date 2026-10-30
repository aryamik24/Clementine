import AppKit
import SwiftUI

final class RadialMenuWindow: NSObject, NSWindowDelegate {
    private var window: RadialMenuPanel?
    private let menuSize = NSSize(width: 310, height: 310)

    func show(
        at screenPoint: NSPoint? = nil,
        draggedFileURL: URL? = nil
    ) {
        let point = screenPoint ?? NSEvent.mouseLocation
        let hostingView = NSHostingView(
            rootView: RadialMenuView(
                draggedFileURL: draggedFileURL,
                dismiss: { [weak self] in
                    self?.hide()
                }
            )
            .frame(width: menuSize.width, height: menuSize.height)
        )

        let window: RadialMenuPanel
        if let existingWindow = self.window {
            existingWindow.contentView = hostingView
            window = existingWindow
        } else {
            let newWindow = RadialMenuPanel(
                contentRect: NSRect(origin: .zero, size: menuSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newWindow.contentView = hostingView
            newWindow.isOpaque = false
            newWindow.backgroundColor = .clear
            newWindow.hasShadow = true
            newWindow.level = .floating
            newWindow.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary
            ]
            newWindow.hidesOnDeactivate = false
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            self.window = newWindow
            window = newWindow
        }

        position(window, at: point)
        window.makeKeyAndOrderFront(nil)
        print("[Menu] Presented for: \(draggedFileURL?.path ?? "preview")")
    }

    func hide() {
        window?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !(window?.isVisible == false) else {
            return
        }

        hide()
    }

    private func position(
        _ window: NSWindow,
        at point: NSPoint
    ) {
        let screen = NSScreen.screens.first {
            NSMouseInRect(point, $0.frame, false)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        var origin = NSPoint(
            x: point.x - menuSize.width / 2,
            y: point.y - menuSize.height / 2
        )

        origin.x = min(
            max(origin.x, visibleFrame.minX),
            visibleFrame.maxX - menuSize.width
        )
        origin.y = min(
            max(origin.y, visibleFrame.minY),
            visibleFrame.maxY - menuSize.height
        )
        window.setFrameOrigin(origin)
    }
}

private final class RadialMenuPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
