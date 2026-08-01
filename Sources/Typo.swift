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

    /// Коэффициенты набора. Вынесены сюда, потому что каждый из них видно глазом
    /// и правят их именно здесь, а не по месту использования.
    enum Metrics {
        /// Шаг строки относительно натуральной высоты шрифта — привычный line-height 1.5.
        static let lineHeight: CGFloat = 1.5
        /// Отбивка между абзацами, в долях кегля.
        static let paragraphSpacing: CGFloat = 0.55
        /// Дополнительный воздух перед заголовком, в долях кегля.
        static let headingSpacingBefore: CGFloat = 0.8
        /// Заголовок первого уровня крупнее основного текста на столько,
        /// каждый следующий уровень — на step мельче предыдущего.
        static let headingScale: CGFloat = 0.30
        static let headingScaleStep: CGFloat = 0.04
        /// Код набирается чуть мельче: моноширинный кажется крупнее при равном кегле.
        static let monoScale: CGFloat = 0.94
        /// Ширина табуляции в долях кегля.
        static let tabWidth: CGFloat = 2
    }

    /// Подбор шрифта не бесплатный: NSFont(name:) перебирает список, а NSFontManager
    /// синтезирует начертание. На документе с сотней заголовков это заметно.
    private static let cache = NSCache<NSString, NSFont>()

    private static func cached(_ key: String, _ make: () -> NSFont) -> NSFont {
        if let hit = cache.object(forKey: key as NSString) { return hit }
        let font = make()
        cache.setObject(font, forKey: key as NSString)
        return font
    }

    static func body(_ size: CGFloat) -> NSFont {
        cached("body-\(size)") {
            for name in preferred {
                if let f = NSFont(name: name, size: size) { return f }
            }
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }

    static func bold(_ f: NSFont) -> NSFont {
        cached("bold-\(f.fontName)-\(f.pointSize)") {
            NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
        }
    }

    static func italic(_ f: NSFont) -> NSFont {
        cached("italic-\(f.fontName)-\(f.pointSize)") {
            NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
        }
    }

    static func mono(_ size: CGFloat) -> NSFont {
        cached("mono-\(size)") {
            NSFont.monospacedSystemFont(ofSize: size * Metrics.monoScale, weight: .regular)
        }
    }

    /// Кегль заголовка по уровню: `#` крупнее всех, `######` почти как основной текст.
    static func heading(_ size: CGFloat, level: Int) -> NSFont {
        let scale = 1 + Metrics.headingScale - Metrics.headingScaleStep * CGFloat(level - 1)
        return bold(body(size * scale))
    }

    static func paragraph(_ size: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        // Здесь был lineHeightMultiple. Он раздувает бокс строки, а каретка рисуется
        // во всю его высоту — выходила почти вдвое выше букв. lineSpacing даёт тот же
        // шаг строки, но бокс не трогает. Промежуточных значений в TextKit 2 нет:
        // стоит задать высоту строки явно, хоть множителем, хоть minimumLineHeight,
        // и каретка снова займёт весь шаг.
        // Считаем от метрик шрифта, а не от кегля, — иначе пропорция уедет на другой гарнитуре.
        let natural = body(size).ascender - body(size).descender
        p.lineSpacing = natural * (Metrics.lineHeight - 1)
        p.paragraphSpacing = size * Metrics.paragraphSpacing
        p.defaultTabInterval = size * Metrics.tabWidth
        return p
    }

    /// Абзацный стиль заголовка: тот же ритм плюс воздух сверху.
    static func headingParagraph(_ size: CGFloat) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.setParagraphStyle(paragraph(size))
        p.paragraphSpacingBefore = size * Metrics.headingSpacingBefore
        return p
    }
}
