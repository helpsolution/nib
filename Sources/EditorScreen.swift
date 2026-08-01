// Окно редактора: холст, счётчик, хромировка, действия масштаба.

import SwiftUI
import AppKit

struct EditorScreen: View {
    @Binding var document: MarkdownDocument

    // @AppStorage, а не @State: окон у DocumentGroup много, и каждое должно
    // подхватывать изменение кегля из соседнего, а не жить со своей копией.
    @AppStorage(Prefs.Key.fontSize) private var fontSize = Double(Prefs.defaultFontSize)
    @AppStorage(Prefs.Key.lineWidth) private var lineWidth = Double(Prefs.defaultLineWidth)

    @State private var words = 0
    @State private var chars = 0

    private enum Layout {
        static let minWindow = CGSize(width: 480, height: 360)
        static let counterInset: CGFloat = 12
        static let counterFontSize: CGFloat = 11
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Editor(text: $document.text,
                   fontSize: CGFloat(fontSize),
                   lineWidth: CGFloat(lineWidth),
                   onStats: { w, c in words = w; chars = c })

            Text("\(words) сл · \(chars)")
                .font(.system(size: Layout.counterFontSize, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.background.opacity(0.75), in: Capsule())
                .padding(Layout.counterInset)
                .allowsHitTesting(false)
        }
        .frame(minWidth: Layout.minWindow.width, minHeight: Layout.minWindow.height)
        .background(WindowChrome())
        .focusedSceneValue(\.zoom, ZoomActions(
            inc:     { setFont(CGFloat(fontSize) + 1) },
            dec:     { setFont(CGFloat(fontSize) - 1) },
            reset:   { setFont(Prefs.defaultFontSize) },
            wider:   { setWidth(CGFloat(lineWidth) + Prefs.widthStep) },
            tighter: { setWidth(CGFloat(lineWidth) - Prefs.widthStep) }
        ))
    }

    private func setFont(_ value: CGFloat) { fontSize = Double(Prefs.clampFont(value)) }
    private func setWidth(_ value: CGFloat) { lineWidth = Double(Prefs.clampWidth(value)) }
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
