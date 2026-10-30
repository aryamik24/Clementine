import SwiftUI
import UniformTypeIdentifiers

struct RadialMenuView: View {
    let draggedFileURL: URL?
    let dismiss: () -> Void

    private let actions = ["PNG", "JPEG", "HEIC", "PDF", "More"]
    private let innerRadius: CGFloat = 65
    private let outerRadius: CGFloat = 145

    @State private var selectedAction: String?
    @State private var hoveredAction: String?
    @State private var feedback: Feedback?
    @State private var isConverting = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.88))
                .frame(width: 310, height: 310)
                .allowsHitTesting(false)

            ForEach(actions.indices, id: \.self) { index in
                segmentButton(for: actions[index], at: index)
            }

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: innerRadius * 2, height: innerRadius * 2)
                .allowsHitTesting(false)

            centerContent
                .allowsHitTesting(false)
        }
        .frame(width: 310, height: 310)
        .background(.clear)
        .onDrop(
            of: [.fileURL],
            delegate: RadialMenuDropDelegate(
                actions: actions,
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                hoveredAction: $hoveredAction,
                performSelection: { action, fileURL in
                    print("[Menu] File dropped on segment: \(action)")
                    handleSelection(action, inputURL: fileURL)
                }
            )
        )
    }

    private var centerContent: some View {
        VStack(spacing: 4) {
            Image(systemName: feedback?.isError == true
                  ? "exclamationmark.triangle"
                  : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 25, weight: .medium))

            Text(feedback?.message ?? selectedAction ?? "Clementine")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(feedback?.isError == true ? Color.orange : Color.white)
        .frame(width: innerRadius * 1.7)
    }

    private func segmentButton(for action: String, at index: Int) -> some View {
        let startAngle = Double(index) * 360 / Double(actions.count) - 90
        let endAngle = Double(index + 1) * 360 / Double(actions.count) - 90
        let segment = RadialSegment(
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle
        )
        let isHighlighted = selectedAction == action || hoveredAction == action

        return Button {
            print("[Menu] Segment clicked: \(action)")
            handleSelection(action)
        } label: {
            ZStack {
                segment
                    .fill(
                        isHighlighted
                            ? Color.cyan.opacity(0.85)
                            : Color.white.opacity(0.10)
                    )

                segment
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)

                Text(action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .position(
                        x: 155 + cos((startAngle + endAngle) / 2 * .pi / 180) * 100,
                        y: 155 + sin((startAngle + endAngle) / 2 * .pi / 180) * 100
                    )
                    .allowsHitTesting(false)
            }
            .frame(width: 310, height: 310)
            .contentShape(segment)
        }
        .buttonStyle(.plain)
        .disabled(isConverting)
        .onHover { isHovering in
            hoveredAction = isHovering ? action : nil
        }
    }

    private func handleSelection(_ action: String, inputURL: URL? = nil) {
        guard !isConverting else {
            return
        }

        selectedAction = action

        guard action != "More" else {
            feedback = Feedback(
                message: "More to come",
                isError: false
            )
            return
        }

        guard let format = ImageFormat(rawValue: action) else {
            feedback = Feedback(
                message: "\(action) is not available",
                isError: true
            )
            return
        }

        guard let inputURL = inputURL ?? draggedFileURL else {
            feedback = Feedback(
                message: "No dragged file was supplied",
                isError: true
            )
            print("[Conversion] Failed: No dragged file was supplied.")
            return
        }

        isConverting = true
        feedback = Feedback(message: "Converting…", isError: false)
        print("[Conversion] Started: \(inputURL.path) → \(format.rawValue)")

        do {
            let outputURL = try FileConverter().convertImage(at: inputURL, to: format)
            print("[Conversion] Succeeded: \(outputURL.path)")
            feedback = Feedback(message: "Saved", isError: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        } catch {
            let message = error.localizedDescription
            print("[Conversion] Failed: \(message)")
            feedback = Feedback(message: message, isError: true)
            isConverting = false
        }
    }
}

private struct Feedback {
    let message: String
    let isError: Bool
}

private struct RadialMenuDropDelegate: DropDelegate {
    let actions: [String]
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    @Binding var hoveredAction: String?
    let performSelection: (String, URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        updateHoveredAction(for: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateHoveredAction(for: info.location)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        hoveredAction = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let action = action(at: info.location),
              let provider = info.itemProviders(for: [.fileURL]).first else {
            return false
        }

        _ = provider.loadObject(ofClass: URL.self) { fileURL, _ in
            guard let fileURL else {
                return
            }

            DispatchQueue.main.async {
                performSelection(action, fileURL)
            }
        }
        return true
    }

    private func updateHoveredAction(for location: CGPoint) {
        hoveredAction = action(at: location)
    }

    private func action(at location: CGPoint) -> String? {
        let center = CGPoint(x: 155, y: 155)
        let deltaX = location.x - center.x
        let deltaY = location.y - center.y
        let distance = hypot(deltaX, deltaY)

        guard distance >= innerRadius, distance <= outerRadius else {
            return nil
        }

        let angle = atan2(deltaY, deltaX) * 180 / .pi
        let normalizedAngle = (angle + 90 + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(normalizedAngle / (360 / Double(actions.count)))
        return actions.indices.contains(index) ? actions[index] : nil
    }
}

struct RadialSegment: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle(degrees: startAngle)
        let end = Angle(degrees: endAngle)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        path.addLine(
            to: CGPoint(
                x: center.x + innerRadius * cos(end.radians),
                y: center.y + innerRadius * sin(end.radians)
            )
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: end,
            endAngle: start,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
