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
    var isPreview: Bool
    var onStats: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Оба режима — живые вью, спрятанные друг за другом. Пересоздавать их при
    /// каждом переключении означало бы терять выделение, позицию прокрутки
    /// и историю правок.
    func makeNSView(context: Context) -> NSView {
        let box = NSView(frame: ColumnTextView.Layout.initialFrame)
        let source = makeSource(context)
        let preview = makePreview(context)
        for view in [source, preview] {
            view.frame = box.bounds
            view.autoresizingMask = [.width, .height]
            box.addSubview(view)
        }
        preview.isHidden = !isPreview
        source.isHidden = isPreview

        context.coordinator.highlight(dirty: nil)
        if isPreview { context.coordinator.refreshPreview() }
        DispatchQueue.main.async { context.coordinator.focus() }
        return box
    }

    private func makeSource(_ context: Context) -> NSScrollView {
        let scroll = Self.makeScroll()

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
        return scroll
    }

    /// Вью просмотра сознательно откатывается на TextKit 1: `NSTextTable`
    /// в TextKit 2 не раскладывается, а каретки, ради которой редактор держится
    /// за TextKit 2, здесь нет — текст только читают.
    private func makePreview(_ context: Context) -> NSScrollView {
        let scroll = Self.makeScroll()

        let tv = ColumnTextView()
        // Обращение к layoutManager откатывает вью на TextKit 1 — делаем его первым,
        // до настройки контейнера, чтобы движок не менялся под уже готовой раскладкой.
        _ = tv.layoutManager
        tv.isEditable = false
        tv.isSelectable = true
        // isRichText здесь не выставляем: вью только для чтения, ограничивать ввод
        // нечего, а флаг мешает хранилищу нести готовое оформление.
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.linkTextAttributes = [.cursor: NSCursor.pointingHand]
        tv.textContainer?.widthTracksTextView = true
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.frame = ColumnTextView.Layout.initialFrame
        tv.maxLineWidth = lineWidth

        scroll.documentView = tv
        context.coordinator.previewView = tv
        return scroll
    }

    private static func makeScroll() -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.borderType = .noBorder
        return scroll
    }

    func updateNSView(_ box: NSView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        let wasPreview = context.coordinator.appliedPreview
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

            if let preview = context.coordinator.previewView {
                preview.maxLineWidth = lineWidth
                preview.refreshInsets()
            }
        }
        if needsHighlight { context.coordinator.highlight(dirty: nil) }

        if isPreview { context.coordinator.refreshPreview() }
        context.coordinator.appliedPreview = isPreview
        context.coordinator.sourceScroll?.isHidden = isPreview
        context.coordinator.previewScroll?.isHidden = !isPreview
        // Фокус переносим только на самом переключении: иначе любое обновление
        // SwiftUI забирало бы его у find bar или у панели поиска.
        if wasPreview != isPreview { context.coordinator.focus() }
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
        weak var previewView: ColumnTextView?
        var appliedSize: CGFloat
        var appliedPreview = false
        private var dirty: NSRange?
        private var pendingStats: DispatchWorkItem?
        /// Из чего собрано текущее превью. Пересборка стоит десяток миллисекунд,
        /// и повторять её на каждое обновление SwiftUI незачем.
        private var rendered: (text: String, size: CGFloat, width: CGFloat)?

        init(_ parent: Editor) {
            self.parent = parent
            self.appliedSize = parent.fontSize
        }

        var sourceScroll: NSScrollView? { textView?.enclosingScrollView }
        var previewScroll: NSScrollView? { previewView?.enclosingScrollView }

        /// Пересобирает превью, если изменился текст, кегль или ширина колонки.
        func refreshPreview() {
            guard let tv = previewView, let storage = tv.textStorage else { return }
            let key = (parent.text, parent.fontSize, parent.lineWidth)
            if let rendered, rendered == key { return }
            storage.setAttributedString(
                Renderer.attributed(parent.text, size: parent.fontSize, width: parent.lineWidth))
            rendered = key
        }

        /// Клавиатура уходит видимому режиму — иначе ⌘F ищет в скрытой вью.
        func focus() {
            let target = parent.isPreview ? previewView : textView
            guard let target, let window = target.window else { return }
            window.makeFirstResponder(target)
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
