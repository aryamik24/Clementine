import AppKit

final class InteractionMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var didTriggerFinderDrag = false

    var onShiftChanged: ((Bool) -> Void)?
    var onFinderDragWithShift: ((URL, NSPoint) -> Void)?

    func start() {
        guard globalMonitor == nil, localMonitor == nil else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [
                .flagsChanged,
                .leftMouseDragged,
                .leftMouseUp
            ]
        ) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleGlobalEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged]
        ) { [weak self] event in
            self?.onShiftChanged?(
                event.modifierFlags.contains(.shift)
            )

            return event
        }
    }

    private func handleGlobalEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            onShiftChanged?(
                event.modifierFlags.contains(.shift)
            )

        case .leftMouseDragged:
            guard !didTriggerFinderDrag else {
                return
            }

            guard event.modifierFlags.contains(.shift) else {
                return
            }

            guard NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier == "com.apple.finder" else {
                return
            }

            let pasteboard = NSPasteboard(name: .drag)

            guard let draggedFiles = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) as? [URL],
                  let draggedFile = draggedFiles.first else {
                print("[Drag] Unable to identify the dragged file.")
                return
            }

            didTriggerFinderDrag = true
            print("[Drag] Detected file: \(draggedFile.path)")

            onFinderDragWithShift?(
                draggedFile,
                NSEvent.mouseLocation
            )

        case .leftMouseUp:
            didTriggerFinderDrag = false

        default:
            break
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
