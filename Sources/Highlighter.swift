// Подсветка: синтаксис гасим, содержимое выделяем.

import AppKit

struct Highlighter {

    /// Паттерны заданы литералами и разбираются один раз при первом обращении.
    /// Ошибка в них — это опечатка в исходнике, а не ситуация времени выполнения,
    /// поэтому падаем сразу, а не тащим Optional через весь файл.
    private static func rx(_ p: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: p, options: [.anchorsMatchLines])
    }

    private static let heading   = rx(#"^(#{1,6})[ \t]+(.*)$"#)
    private static let fence     = rx("^```[^\n]*\n([\\s\\S]*?)^```[ \t]*$")
    private static let fenceLine = rx("^```[^\n]*$")
    private static let quote     = rx(#"^([ \t]*>[ \t]?)(.*)$"#)
    private static let bullet    = rx(#"^([ \t]*(?:[-*+]|\d{1,3}[.)]))[ \t]"#)
    private static let rule      = rx(#"^([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let strong    = rx(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private static let emph      = rx(#"(?<![*\w])(\*|_)(?=[^*\s])([^*\n]+?)(?<=[^*\s])\1(?![*\w])"#)
    private static let strike    = rx(#"(~~)(?=\S)(.+?)(?<=\S)\1"#)
    private static let code      = rx("`([^`\n]+)`")
    private static let link      = rx(#"(!?\[)([^\]\n]*)(\]\()([^)\n]*)(\))"#)

    /// Красит `dirty` — или весь документ, если он не задан.
    ///
    /// Диапазон всегда расширяется до границ абзацев и до целого блока кода:
    /// разметка, растянутая на несколько строк, иначе красилась бы кусками.
    static func apply(to storage: NSTextStorage, size: CGFloat, in dirty: NSRange? = nil) {
        let text = storage.string as NSString
        // Одна мостовая копия на весь проход: раньше storage.string брался
        // в каждом enumerateMatches, то есть документ копировался восемь раз.
        let string = storage.string
        let full = NSRange(location: 0, length: text.length)
        let scope = dirty.map { blockRange(around: $0, in: text) } ?? full
        guard scope.length > 0 else { return }

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
        ], range: scope)

        /// Блоки кода красятся первыми и дальше считаются занятыми: внутри них
        /// разметка — это текст программы, а не разметка. Без этого `**` и `#`
        /// в примере кода подсвечивались бы как жирный и заголовок.
        let fenced = fence.matches(in: string, range: scope).map(\.range)

        func paint(_ attrs: [NSAttributedString.Key: Any], _ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0,
                  NSMaxRange(r) <= text.length else { return }
            storage.addAttributes(attrs, range: r)
        }

        func set(_ attrs: [NSAttributedString.Key: Any], _ r: NSRange) {
            guard !fenced.contains(where: { NSIntersectionRange($0, r).length > 0 }) else { return }
            paint(attrs, r)
        }

        for r in fenced {
            paint([.font: Typo.mono(size), .foregroundColor: dim], r)
        }

        // Заголовки: маркер гасим, текст — жирным и чуть крупнее
        heading.enumerateMatches(in: string, range: scope) { m, _, _ in
            guard let m else { return }
            let level = m.range(at: 1).length
            set([.font: Typo.heading(size, level: level),
                 .paragraphStyle: Typo.headingParagraph(size)], m.range)
            set([.foregroundColor: faded], m.range(at: 1))
        }

        // Цитаты
        quote.enumerateMatches(in: string, range: scope) { m, _, _ in
            guard let m else { return }
            set([.font: Typo.italic(base), .foregroundColor: dim], m.range(at: 2))
            set([.foregroundColor: faded], m.range(at: 1))
        }

        // Маркеры списков и горизонтальные линии
        for r in [bullet, rule] {
            r.enumerateMatches(in: string, range: scope) { m, _, _ in
                guard let m else { return }
                set([.foregroundColor: faded], m.range(at: m.numberOfRanges > 1 ? 1 : 0))
            }
        }

        // Инлайновая разметка
        func inline(_ r: NSRegularExpression, _ font: NSFont?, _ color: NSColor?) {
            r.enumerateMatches(in: string, range: scope) { m, _, _ in
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

        code.enumerateMatches(in: string, range: scope) { m, _, _ in
            guard let m else { return }
            set([.font: Typo.mono(size), .foregroundColor: dim], m.range)
            set([.foregroundColor: faded], NSRange(location: m.range.location, length: 1))
            set([.foregroundColor: faded], NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }

        link.enumerateMatches(in: string, range: scope) { m, _, _ in
            guard let m else { return }
            set([.foregroundColor: faded], m.range(at: 1))
            set([.foregroundColor: accent], m.range(at: 2))
            set([.foregroundColor: faded], m.range(at: 3))
            set([.foregroundColor: faded, .font: Typo.mono(size)], m.range(at: 4))
            set([.foregroundColor: faded], m.range(at: 5))
        }
    }

    /// Расширяет правку до безопасных границ.
    ///
    /// Абзац целиком — потому что регулярки построчные и половина строки им
    /// бесполезна. Плюс соседние абзацы: правка может сделать строку началом
    /// или концом блока. Плюс блок кода целиком, если правка попала внутрь.
    private static func blockRange(around dirty: NSRange, in text: NSString) -> NSRange {
        let start = min(dirty.location, text.length)
        let clamped = NSRange(location: start, length: min(dirty.length, text.length - start))
        var r = text.paragraphRange(for: clamped)
        if r.location > 0 {
            r = NSUnionRange(text.paragraphRange(for: NSRange(location: r.location - 1, length: 0)), r)
        }
        if NSMaxRange(r) < text.length {
            r = NSUnionRange(r, text.paragraphRange(for: NSRange(location: NSMaxRange(r), length: 0)))
        }
        return fenceAware(r, in: text)
    }

    /// Если правка задела блок кода — возвращаем его целиком.
    /// Если задела саму строку с ``` — структура блоков могла поменяться,
    /// и дешевле перекрасить весь документ, чем угадывать последствия.
    private static func fenceAware(_ r: NSRange, in text: NSString) -> NSRange {
        // Быстрый выход: поиск подстроки дешевле регулярки, а в большинстве
        // документов тройных кавычек нет вовсе.
        guard text.range(of: "```").location != NSNotFound else { return r }

        let full = NSRange(location: 0, length: text.length)
        let fences = fenceLine.matches(in: text as String, range: full).map(\.range)
        guard !fences.isEmpty else { return r }

        for f in fences where NSIntersectionRange(f, r).length > 0 || NSLocationInRange(f.location, r) {
            return full
        }

        // Нечётное число кавычек — либо блок ещё не закрыт, либо одну только что
        // снесли. В обоих случаях по удалённой кавычке судить не по чему: её уже нет
        // в тексте, а бывший блок остался покрашенным. Перекрашиваем всё от первой
        // кавычки до конца — дальше этого последствия не расходятся.
        if fences.count % 2 == 1, let first = fences.first {
            return NSUnionRange(r, NSRange(location: first.location, length: text.length - first.location))
        }

        var result = r
        for pair in stride(from: 0, to: fences.count - 1, by: 2) {
            let block = NSRange(location: fences[pair].location,
                                length: NSMaxRange(fences[pair + 1]) - fences[pair].location)
            if NSIntersectionRange(block, r).length > 0 {
                result = NSUnionRange(result, block)
            }
        }
        return result
    }
}
