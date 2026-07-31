// Подсветка: синтаксис гасим, содержимое выделяем.

import AppKit

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
