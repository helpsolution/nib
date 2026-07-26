// Nib — минималистичный редактор Markdown для macOS.
// Один файл, ноль зависимостей. Собирается swiftc, без Xcode-проекта.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Настройки

enum Prefs {
    static var fontSize: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "fontSize")
            return v == 0 ? 17 : CGFloat(v)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "fontSize") }
    }
    static var lineWidth: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "lineWidth")
            return v == 0 ? 700 : CGFloat(v)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "lineWidth") }
    }
}

// MARK: - Типографика

enum Typo {
    /// Порядок предпочтений. Если стоят бесплатные шрифты iA Writer (SIL OFL) — берём их.
    static let preferred = [
        "iA Writer Quattro S", "iA Writer Quattro V",
        "iA Writer Duo S", "iA Writer Duospace",
        "iA Writer Mono S",
        "JetBrains Mono", "SF Mono", "Menlo"
    ]

    static func body(_ size: CGFloat) -> NSFont {
        for name in preferred {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func bold(_ f: NSFont) -> NSFont {
        NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
    }
    static func italic(_ f: NSFont) -> NSFont {
        NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
    }
    static func mono(_ size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size * 0.94, weight: .regular)
    }

    static func paragraph(_ size: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.5
        p.paragraphSpacing = size * 0.55
        p.defaultTabInterval = size * 2
        return p
    }
}

// MARK: - Документ

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownDocument: FileDocument {
    var text: String

    init(text: String = "") { self.text = text }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Подсветка: синтаксис гасим, содержимое выделяем

struct Highlighter {

    private static func rx(_ p: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: p, options: [.anchorsMatchLines])
    }

    private static let heading   = rx(#"^(#{1,6})[ \t]+(.*)$"#)
    private static let fence     = rx("^```[^\n]*\n([\\s\\S]*?)^```[ \t]*$")
    private static let quote     = rx(#"^([ \t]*>[ \t]?)(.*)$"#)
    private static let bullet    = rx(#"^([ \t]*(?:[-*+]|\d{1,3}[.)]))[ \t]"#)
    private static let rule      = rx(#"^([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let strong    = rx(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let emph      = rx(#"(?<![*\w])(\*|_)(?=[^*\s])([^*\n]+?)(?<=[^*\s])\1(?![*\w])"#)
    private static let strike    = rx(#"(~~)(?=\S)(.+?)(?<=\S)\1"#)
    private static let code      = rx("`([^`\n]+)`")
    private static let link      = rx(#"(!?\[)([^\]\n]*)(\]\()([^)\n]*)(\))"#)

    static func apply(to storage: NSTextStorage, size: CGFloat) {
        let text = storage.string as NSString
        let full = NSRange(location: 0, length: text.length)
        let base = Typo.body(size)

        let ink    = NSColor.textColor
        let dim    = NSColor.secondaryLabelColor
        let faded  = NSColor.tertiaryLabelColor
        let accent = NSColor.controlAccentColor

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.setAttributes([
            .font: base,
            .foregroundColor: ink,
            .paragraphStyle: Typo.paragraph(size)
        ], range: full)

        func set(_ attrs: [NSAttributedString.Key: Any], _ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0,
                  NSMaxRange(r) <= text.length else { return }
            storage.addAttributes(attrs, range: r)
        }

        // Заголовки: маркер гасим, текст — жирным и чуть крупнее
        heading.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m else { return }
            let level = m.range(at: 1).length
            let scale = 1.0 + (0.30 - 0.04 * CGFloat(level - 1))
            let f = Typo.bold(Typo.body(size * scale))
            let p = NSMutableParagraphStyle()
            p.setParagraphStyle(Typo.paragraph(size))
            p.paragraphSpacingBefore = size * 0.8
            set([.font: f, .paragraphStyle: p], m.range)
            set([.foregroundColor: faded], m.range(at: 1))
        }

        // Блоки кода
        fence.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m else { return }
            set([.font: Typo.mono(size), .foregroundColor: dim], m.range)
        }

        // Цитаты
        quote.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m else { return }
            set([.font: Typo.italic(base), .foregroundColor: dim], m.range(at: 2))
            set([.foregroundColor: faded], m.range(at: 1))
        }

        // Маркеры списков и горизонтальные линии
        for r in [bullet, rule] {
            r.enumerateMatches(in: storage.string, range: full) { m, _, _ in
                guard let m else { return }
                set([.foregroundColor: faded], m.range(at: m.numberOfRanges > 1 ? 1 : 0))
            }
        }

        // Инлайновая разметка
        func inline(_ r: NSRegularExpression, _ font: NSFont?, _ color: NSColor?) {
            r.enumerateMatches(in: storage.string, range: full) { m, _, _ in
                guard let m else { return }
                var attrs: [NSAttributedString.Key: Any] = [:]
                if let font { attrs[.font] = font }
                if let color { attrs[.foregroundColor] = color }
                if !attrs.isEmpty { set(attrs, m.range(at: 2)) }
                // сами звёздочки/подчёркивания гасим
                let open = NSRange(location: m.range.location, length: m.range(at: 1).length)
                let close = NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length,
                                    length: m.range(at: 1).length)
                set([.foregroundColor: faded], open)
                set([.foregroundColor: faded], close)
            }
        }

        inline(strong, Typo.bold(base), nil)
        inline(emph, Typo.italic(base), nil)
        inline(strike, nil, dim)

        code.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m else { return }
            set([.font: Typo.mono(size), .foregroundColor: dim], m.range)
            set([.foregroundColor: faded], NSRange(location: m.range.location, length: 1))
            set([.foregroundColor: faded], NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }

        link.enumerateMatches(in: storage.string, range: full) { m, _, _ in
            guard let m else { return }
            set([.foregroundColor: faded], m.range(at: 1))
            set([.foregroundColor: accent], m.range(at: 2))
            set([.foregroundColor: faded], m.range(at: 3))
            set([.foregroundColor: faded, .font: Typo.mono(size)], m.range(at: 4))
            set([.foregroundColor: faded], m.range(at: 5))
        }
    }
}

// MARK: - NSTextView с центрированной колонкой

final class ColumnTextView: NSTextView {
    var maxLineWidth: CGFloat = Prefs.lineWidth

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshInsets()
    }

    func refreshInsets() {
        let h = max(30, (bounds.width - maxLineWidth) / 2)
        let inset = NSSize(width: h, height: 48)
        if textContainerInset != inset { textContainerInset = inset }
    }
}

struct Editor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineWidth: CGFloat
    var onStats: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.borderType = .noBorder

        let tv = ColumnTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.isEditable = true
        tv.isSelectable = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = true
        tv.isGrammarCheckingEnabled = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.insertionPointColor = .controlAccentColor
        tv.textContainer?.widthTracksTextView = true
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        tv.maxLineWidth = lineWidth
        tv.string = text
        tv.typingAttributes = [
            .font: Typo.body(fontSize),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: Typo.paragraph(fontSize)
        ]

        scroll.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.rehighlight(force: true)
        DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? ColumnTextView else { return }
        context.coordinator.parent = self

        var needsHighlight = false
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            tv.setSelectedRange(NSRange(location: min(sel.location, text.utf16.count), length: 0))
            needsHighlight = true
        }
        if context.coordinator.appliedSize != fontSize || tv.maxLineWidth != lineWidth {
            context.coordinator.appliedSize = fontSize
            tv.maxLineWidth = lineWidth
            tv.refreshInsets()
            tv.typingAttributes = [
                .font: Typo.body(fontSize),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: Typo.paragraph(fontSize)
            ]
            needsHighlight = true
        }
        if needsHighlight { context.coordinator.rehighlight(force: true) }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: Editor
        weak var textView: ColumnTextView?
        var appliedSize: CGFloat
        private var pending: DispatchWorkItem?

        init(_ parent: Editor) {
            self.parent = parent
            self.appliedSize = parent.fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            rehighlight(force: false)
        }

        func rehighlight(force: Bool) {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let tv = self.textView, let storage = tv.textStorage else { return }
                let sel = tv.selectedRanges
                Highlighter.apply(to: storage, size: self.parent.fontSize)
                tv.selectedRanges = sel
                let w = Self.words(tv.string)
                let c = tv.string.count
                DispatchQueue.main.async { self.parent.onStats(w, c) }
            }
            pending = work
            if force {
                work.perform()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: work)
            }
        }

        static func words(_ s: String) -> Int {
            s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
    }
}

// MARK: - Окно

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

// MARK: - Точка входа

@main
struct NibApp: App {
    @FocusedValue(\.zoom) var zoom

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorScreen(document: file.$document)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Крупнее") { zoom?.inc() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Мельче") { zoom?.dec() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Размер по умолчанию") { zoom?.reset() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Колонка шире") { zoom?.wider() }
                    .keyboardShortcut("]", modifiers: [.command, .option])
                Button("Колонка уже") { zoom?.tighter() }
                    .keyboardShortcut("[", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) { }
        }
    }
}
