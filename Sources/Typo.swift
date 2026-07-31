// Типографика: подбор шрифта и абзацный стиль.

import AppKit

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
        // Здесь был lineHeightMultiple = 1.5. Он раздувает бокс строки, а каретка рисуется
        // во всю его высоту — выходила 30 pt при видимой высоте букв ~16 pt.
        // lineSpacing даёт тот же шаг строки (29.89 против 30.0, замерено), но бокс не трогает:
        // каретка садится по шрифту, 20 pt. Промежуточных значений в TextKit 2 нет — стоит
        // задать высоту строки явно, хоть множителем, хоть minimumLineHeight, и каретка
        // снова займёт весь шаг. Считаем от метрик шрифта, а не от кегля: на другой гарнитуре
        // константа вроде size * 0.58 дала бы другой ритм.
        p.lineSpacing = (body(size).ascender - body(size).descender) * 0.5
        p.paragraphSpacing = size * 0.55
        p.defaultTabInterval = size * 2
        return p
    }
}
