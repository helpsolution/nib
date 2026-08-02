// Окно редактора: холст, счётчик, переключатель режима, хромировка, действия масштаба.

import SwiftUI
import AppKit

struct EditorScreen: View {
    @Binding var document: MarkdownDocument
    @State private var fontSize = Prefs.fontSize
    @State private var lineWidth = Prefs.lineWidth
    @State private var preview: Bool
    @State private var chromeHovered = false
    @State private var words = 0
    @State private var chars = 0

    init(document: Binding<MarkdownDocument>) {
        _document = document
        // Пустой документ открываем в исходнике: показывать нечего, а первый
        // символ пришлось бы набирать после переключения режима.
        _preview = State(initialValue: Prefs.preview && !document.wrappedValue.text.isEmpty)
    }

    enum Layout {
        /// Меньше этого окно складывается: колонка упирается в минимальные поля.
        static let minWindow = CGSize(width: 480, height: 360)
        static let counterFontSize: CGFloat = 11
        static let counterInset: CGFloat = 12
        static let counterPaddingH: CGFloat = 14
        static let counterPaddingV: CGFloat = 6
        /// Счётчик лежит поверх текста, поэтому подложка полупрозрачная.
        static let counterBackgroundOpacity: CGFloat = 0.75
        /// Зазор между счётчиком и переключателем.
        static let chromeSpacing: CGFloat = 8
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Editor(text: $document.text,
                   fontSize: fontSize,
                   lineWidth: lineWidth,
                   isPreview: preview,
                   onStats: { w, c in words = w; chars = c })

            chrome
        }
        .frame(minWidth: Layout.minWindow.width, minHeight: Layout.minWindow.height)
        .background(WindowChrome())
        .focusedSceneValue(\.editor, EditorActions(
            inc:     { set(fontSize + Prefs.fontStep) },
            dec:     { set(fontSize - Prefs.fontStep) },
            reset:   { set(Prefs.defaultFontSize) },
            wider:   { setWidth(lineWidth + Prefs.widthStep) },
            tighter: { setWidth(lineWidth - Prefs.widthStep) },
            isPreview: preview,
            togglePreview: { setPreview(!preview) }
        ))
    }

    /// Счётчик и переключатель — один кластер в углу. У окна намеренно один
    /// локус хромировки: второй на пустом экране конкурировал бы с текстом.
    private var chrome: some View {
        HStack(spacing: Layout.chromeSpacing) {
            Text("\(words) сл · \(chars)")
                .font(.system(size: Layout.counterFontSize, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Layout.counterPaddingH)
                .padding(.vertical, Layout.counterPaddingV)
                .background(.background.opacity(Layout.counterBackgroundOpacity), in: Capsule())
                .allowsHitTesting(false)

            ModeToggle(isPreview: preview, revealed: chromeHovered, select: setPreview)
        }
        .padding(Layout.counterInset)
        // Наведение ловит весь кластер, а не сам переключатель: мишень в 56 pt
        // мышью не поймать, счётчик расширяет её втрое.
        .onHover { hovering in
            withAnimation(.easeOut(duration: ModeToggle.Layout.revealDuration)) {
                chromeHovered = hovering
            }
        }
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
    private func setPreview(_ v: Bool) {
        preview = v
        Prefs.preview = v
    }
}

/// Переключатель «просмотр / исходник». В покое — два бледных глифа, дорожка
/// и плашка проявляются под курсором: пока переключатель не нужен, его не видно.
struct ModeToggle: View {
    var isPreview: Bool
    var revealed: Bool
    var select: (Bool) -> Void
    @Namespace private var pill

    enum Layout {
        static let symbolSize: CGFloat = 11
        static let segment = CGSize(width: 24, height: 19)
        static let radius: CGFloat = 5
        static let trackPadding: CGFloat = 2
        /// В покое видны только глифы — ни дорожки, ни плашки.
        static let restingOpacity: CGFloat = 0.45
        static let revealDuration: CGFloat = 0.15
        static let slideResponse: CGFloat = 0.22
        static let slideDamping: CGFloat = 0.9
    }

    private struct Mode {
        var preview: Bool
        var symbol: String
        var title: String
    }

    /// `chevron.left.slash.chevron.right`, а не вариант с `forwardslash`:
    /// тот появился в SF Symbols 4, ровно на минимуме macOS 13, без запаса.
    private static let modes = [
        Mode(preview: true, symbol: "eye", title: "Просмотр"),
        Mode(preview: false, symbol: "chevron.left.slash.chevron.right", title: "Исходник")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.modes, id: \.symbol) { mode in
                let active = mode.preview == isPreview
                Button {
                    withAnimation(.spring(response: Layout.slideResponse,
                                          dampingFraction: Layout.slideDamping)) {
                        select(mode.preview)
                    }
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: Layout.symbolSize, weight: .medium))
                        .frame(width: Layout.segment.width, height: Layout.segment.height)
                        .foregroundStyle(active ? AnyShapeStyle(.secondary)
                                                : AnyShapeStyle(.quaternary))
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
                                    .fill(.background)
                                    .opacity(revealed ? 1 : 0)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode.title)
            }
        }
        .padding(Layout.trackPadding)
        .background {
            // Радиус дорожки на паддинг больше внутреннего, иначе плашка
            // «плывёт» в углах.
            RoundedRectangle(cornerRadius: Layout.radius + Layout.trackPadding, style: .continuous)
                .fill(.quaternary)
                .opacity(revealed ? 1 : 0)
        }
        .opacity(revealed ? 1 : Layout.restingOpacity)
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

/// Действия сфокусированного редактора, доступные меню приложения.
struct EditorActions {
    var inc: () -> Void
    var dec: () -> Void
    var reset: () -> Void
    var wider: () -> Void
    var tighter: () -> Void
    var isPreview: Bool
    var togglePreview: () -> Void
}

struct EditorKey: FocusedValueKey { typealias Value = EditorActions }
extension FocusedValues {
    var editor: EditorActions? {
        get { self[EditorKey.self] }
        set { self[EditorKey.self] = newValue }
    }
}
