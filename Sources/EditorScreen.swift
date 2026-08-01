// Окно редактора: холст, счётчик, хромировка, действия масштаба.

import SwiftUI
import AppKit

struct EditorScreen: View {
    @Binding var document: MarkdownDocument
    @State private var fontSize = Prefs.fontSize
    @State private var lineWidth = Prefs.lineWidth
    @State private var words = 0
    @State private var chars = 0

    enum Layout {
        /// Меньше этого окно складывается: колонка упирается в минимальные поля.
        static let minWindow = CGSize(width: 480, height: 360)
        static let counterFontSize: CGFloat = 11
        static let counterInset: CGFloat = 12
        static let counterPaddingH: CGFloat = 14
        static let counterPaddingV: CGFloat = 6
        /// Счётчик лежит поверх текста, поэтому подложка полупрозрачная.
        static let counterBackgroundOpacity: CGFloat = 0.75
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Editor(text: $document.text,
                   fontSize: fontSize,
                   lineWidth: lineWidth,
                   onStats: { w, c in words = w; chars = c })

            Text("\(words) сл · \(chars)")
                .font(.system(size: Layout.counterFontSize, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Layout.counterPaddingH)
                .padding(.vertical, Layout.counterPaddingV)
                .background(.background.opacity(Layout.counterBackgroundOpacity), in: Capsule())
                .padding(Layout.counterInset)
                .allowsHitTesting(false)
        }
        .frame(minWidth: Layout.minWindow.width, minHeight: Layout.minWindow.height)
        .background(WindowChrome())
        .focusedSceneValue(\.zoom, ZoomActions(
            inc:     { set(fontSize + Prefs.fontStep) },
            dec:     { set(fontSize - Prefs.fontStep) },
            reset:   { set(Prefs.defaultFontSize) },
            wider:   { setWidth(lineWidth + Prefs.widthStep) },
            tighter: { setWidth(lineWidth - Prefs.widthStep) }
        ))
    }

    private func set(_ v: CGFloat) {
        let clamped = Prefs.clampFont(v)
        fontSize = clamped
        Prefs.fontSize = clamped
    }
    private func setWidth(_ v: CGFloat) {
        let clamped = Prefs.clampWidth(v)
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
