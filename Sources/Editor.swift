// NSTextView с центрированной колонкой и мост в SwiftUI.

import SwiftUI
import AppKit

final class ColumnTextView: NSTextView {
    var maxLineWidth: CGFloat = Prefs.lineWidth

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
        let h = min(max(30, (bounds.width - maxLineWidth) / 2), bounds.width / 2)
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
                // Подсветка сначала сбрасывает атрибуты на весь документ и только потом
                // возвращает крупные шрифты заголовков. В этот момент документ короче,
                // и прокрутка подрезается под временную высоту — без сохранения позиции
                // правка в конце файла отбрасывала на сотни точек вверх.
                let clip = tv.enclosingScrollView?.contentView
                let origin = clip?.bounds.origin
                Highlighter.apply(to: storage, size: self.parent.fontSize)
                tv.selectedRanges = sel
                if let clip, let origin {
                    let restore = {
                        guard clip.bounds.origin != origin else { return }
                        clip.scroll(to: origin)
                        tv.enclosingScrollView?.reflectScrolledClipView(clip)
                    }
                    restore()
                    // Раскладка досчитывается уже после текущего прохода runloop,
                    // и подрезает прокрутку повторно — возвращаем позицию ещё раз.
                    DispatchQueue.main.async(execute: restore)
                }
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
