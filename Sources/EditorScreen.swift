// Окно редактора: холст, счётчик, хромировка, действия масштаба.

import SwiftUI
import AppKit

struct EditorScreen: View {
    @Binding var document: MarkdownDocument
    @State private var fontSize = Prefs.fontSize
    @State private var lineWidth = Prefs.lineWidth
    @State private var words = 0
    @State private var chars = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Editor(text: $document.text,
                   fontSize: fontSize,
                   lineWidth: lineWidth,
                   onStats: { w, c in words = w; chars = c })

            Text("\(words) сл · \(chars)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.background.opacity(0.75), in: Capsule())
                .padding(12)
                .allowsHitTesting(false)
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(WindowChrome())
        .focusedSceneValue(\.zoom, ZoomActions(
            inc:   { set(fontSize + 1) },
            dec:   { set(fontSize - 1) },
            reset: { set(17) },
            wider: { setWidth(lineWidth + 60) },
            tighter: { setWidth(lineWidth - 60) }
        ))
    }

    private func set(_ v: CGFloat) {
        let clamped = min(32, max(11, v))
        fontSize = clamped
        Prefs.fontSize = clamped
    }
    private func setWidth(_ v: CGFloat) {
        let clamped = min(1100, max(420, v))
        lineWidth = clamped
        Prefs.lineWidth = clamped
    }
}

/// Прозрачный тайтлбар без тулбара — вся хромировка уходит на задний план.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.titlebarAppearsTransparent = true
            w.backgroundColor = .textBackgroundColor
            w.isMovableByWindowBackground = false
            w.toolbar = nil
            w.tabbingMode = .preferred
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ZoomActions {
    var inc: () -> Void
    var dec: () -> Void
    var reset: () -> Void
    var wider: () -> Void
    var tighter: () -> Void
}

struct ZoomKey: FocusedValueKey { typealias Value = ZoomActions }
extension FocusedValues {
    var zoom: ZoomActions? {
        get { self[ZoomKey.self] }
        set { self[ZoomKey.self] = newValue }
    }
}
