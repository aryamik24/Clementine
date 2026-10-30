//
//  ClementineApp.swift
//  Clementine
//
//  Created by Aryamik Singh on 30/10/26.
//
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct ClementineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @State private var radialMenuWindow = RadialMenuWindow()

    var body: some Scene {
        MenuBarExtra("Clementine", image: "ClementineMenuBar") {
            Button("Preview Radial Menu") {
                radialMenuWindow.show(at: NSEvent.mouseLocation)
            }

            Divider()

            Button("Test Image Conversion") {
                testImageConversion()
            }

            Divider()

            Button("About Clementine") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }

            Button("Quit Clementine") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }

    private func testImageConversion() {
        let panel = NSOpenPanel()

        panel.title = "Select an Image to Convert"
        panel.allowedContentTypes = [
            .png,
            .jpeg,
            .heic,
            .tiff
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let inputURL = panel.url else {
            return
        }

        let converter = FileConverter()

        do {
            let outputURL = try converter.convertImage(
                at: inputURL,
                to: .png
            )

            NSWorkspace.shared.activateFileViewerSelecting([
                outputURL
            ])
        } catch {
            let alert = NSAlert()

            alert.messageText = "Conversion Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning

            alert.runModal()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let interactionMonitor = InteractionMonitor()
    private let radialMenuWindow = RadialMenuWindow()

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(.accessory)

        interactionMonitor.onShiftChanged = { isPressed in
            print("Shift pressed: \(isPressed)")
        }

        interactionMonitor.onFinderDragWithShift = {
            [weak self] fileURL, point in
            self?.radialMenuWindow.show(
                at: point,
                draggedFileURL: fileURL
            )
        }

        interactionMonitor.start()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        interactionMonitor.stop()
        radialMenuWindow.hide()
    }
}
