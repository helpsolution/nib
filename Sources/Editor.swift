// NSTextView с центрированной колонкой и мост в SwiftUI.

import SwiftUI
import AppKit

final class ColumnTextView: NSTextView {
    var maxLineWidth: CGFloat = Prefs.lineWidth

    enum Layout {
        /// Отступ сверху и снизу: текст не должен упираться в тайтлбар.
        static let verticalInset: CGFloat = 48
        /// Минимальное боковое поле, когда окно уже колонки.
        static let minSideInset: CGFloat = 30
        /// Размер до первой раскладки. Через мгновение его заменит настоящий,
        /// но с нулевым текстовый контейнер успевает посчитать себя пустым.
        static let initialFrame = NSRect(x: 0, y: 0, width: 800, height: 600)
    }

    override func setFrameSize(_ newSize: NSSize) {
        // Ширину диктует видимая область, а не сам textview: его собственная ширина
        // равна container + 2×inset, и считать inset от неё — замкнутый круг,
        // в котором любая ширина ≥ maxLineWidth+60 самоподдерживается (текст уезжает за край).
        var size = newSize
        if let clip = enclosingScrollView?.contentView {
            size.width = clip.bounds.width
        }
        super.setFrameSize(size)
        refreshInsets()
    }

    func refreshInsets() {
        // Верхняя граница bounds.width/2 нужна для самого первого layout с нулевой шириной:
        // без неё контейнер получил бы отрицательную ширину.
        let side = min(max(Layout.minSideInset, (bounds.width - maxLineWidth) / 2),
                       bounds.width / 2)
        let inset = NSSize(width: side, height: Layout.verticalInset)
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
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.frame = ColumnTextView.Layout.initialFrame
        tv.maxLineWidth = lineWidth
        tv.string = text
        tv.textStorage?.delegate = context.coordinator
        tv.typingAttributes = Self.typingAttributes(fontSize)

        scroll.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.highlight(dirty: nil)
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
            tv.typingAttributes = Self.typingAttributes(fontSize)
            needsHighlight = true
        }
        if needsHighlight { context.coordinator.highlight(dirty: nil) }
    }

    /// Оформление ещё не набранного текста. Без него первый символ на пустой
    /// строке появляется системным шрифтом и прыгает при перекраске.
    static func typingAttributes(_ size: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: Typo.body(size),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: Typo.paragraph(size)
        ]
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: Editor
        weak var textView: ColumnTextView?
        var appliedSize: CGFloat
        private var dirty: NSRange?
        private var pendingStats: DispatchWorkItem?

        init(_ parent: Editor) {
            self.parent = parent
            self.appliedSize = parent.fontSize
        }

        /// Хранилище само сообщает, какой кусок изменился, — это точнее и дешевле,
        /// чем сравнивать со снимком прошлого текста. Снимок вдобавок пришлось бы
        /// копировать целиком: `NSTextView.string` отдаёт живую ссылку на хранилище,
        /// и сохранённое значение менялось бы вместе с текстом.
        func textStorage(_ storage: NSTextStorage,
                         didProcessEditing edited: NSTextStorageEditActions,
                         range: NSRange,
                         changeInLength delta: Int) {
            // Правка атрибутов — это работа самой подсветки, реагировать не на что.
            guard edited.contains(.editedCharacters) else { return }
            dirty = dirty.map { NSUnionRange($0, range) } ?? range
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            highlight(dirty: dirty)
        }

        /// Перекраска. `dirty == nil` — весь документ: открытие файла, смена
        /// шрифта или ширины колонки. Идёт синхронно: инкрементальный проход
        /// стоит доли миллисекунды, и откладывать его незачем — раньше из-за
        /// дебаунса стиль приезжал только после паузы в наборе.
        func highlight(dirty scope: NSRange?) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let sel = tv.selectedRanges
            Highlighter.apply(to: storage, size: parent.fontSize, in: scope)
            tv.selectedRanges = sel
            dirty = nil
            scheduleStats()
        }

        /// Счётчик слов — единственное, что осталось отложенным: он считает
        /// весь документ, а видит его читатель боковым зрением.
        private func scheduleStats() {
            pendingStats?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let tv = self.textView else { return }
                self.parent.onStats(Self.words(tv.string), tv.string.count)
            }
            pendingStats = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }

        static func words(_ s: String) -> Int {
            s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
    }
}
