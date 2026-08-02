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

    /// Коэффициенты набора. Каждый из них видно глазом, и правят их именно здесь.
    ///
    /// Порядок операций в формулах ниже менять нельзя. Откаченный рефакторинг
    /// (af0ff8c) переписал скобку в масштабе заголовка, и кегли h4 и h5 уехали
    /// на 1 ULP — вместе с метриками глифов и, возможно, переносом строки.
    /// Тест-якорь в Tests/MetricsAnchorTests.swift держит числа бит-в-бит.
    enum Metrics {
        /// Межстрочный интервал в долях натуральной высоты шрифта.
        /// Половина даёт привычный line-height 1.5.
        static let lineSpacing: CGFloat = 0.5
        /// Отбивка между абзацами, в долях кегля.
        static let paragraphSpacing: CGFloat = 0.55
        /// Дополнительный воздух перед заголовком, в долях кегля.
        static let headingSpacingBefore: CGFloat = 0.8
        /// Заголовок первого уровня крупнее основного текста на headingScale,
        /// каждый следующий уровень — на headingScaleStep мельче предыдущего.
        static let headingScale: CGFloat = 0.30
        static let headingScaleStep: CGFloat = 0.04
        /// Код набирается чуть мельче: моноширинный кажется крупнее при равном кегле.
        static let monoScale: CGFloat = 0.94
        /// Ширина табуляции в долях кегля.
        static let tabWidth: CGFloat = 2
        /// Ступень отступа вложенного списка, в долях кегля.
        static let listIndent: CGFloat = 1.6
        /// Отступ цитаты, в долях кегля.
        static let quoteIndent: CGFloat = 1.2
    }

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
        NSFont.monospacedSystemFont(ofSize: size * Metrics.monoScale, weight: .regular)
    }

    /// Шрифт заголовка по уровню: `#` крупнее всех, `######` почти как основной текст.
    ///
    /// Скобка вокруг вычитания обязательна — см. предупреждение в Metrics.
    static func heading(_ size: CGFloat, level: Int) -> NSFont {
        let scale = 1.0 + (Metrics.headingScale - Metrics.headingScaleStep * CGFloat(level - 1))
        return bold(body(size * scale))
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
        p.lineSpacing = (body(size).ascender - body(size).descender) * Metrics.lineSpacing
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

    // MARK: - Стили режима просмотра
    //
    // Ниже — только для Preview: в исходнике этих блоков нет, там разметка видна
    // как текст. Формулы выше не трогаются, их держит MetricsAnchorTests.

    /// Пункт списка с висячим отступом: маркер стоит в поле, текст выравнивается
    /// по табуляции и переносится под себя, а не под маркер.
    ///
    /// `closing` — последний пункт списка. Внутри списка отбивки нет, иначе пункты
    /// разъезжаются как отдельные абзацы; воздух возвращается на выходе из списка.
    static func listParagraph(_ size: CGFloat, depth: Int, closing: Bool) -> NSParagraphStyle {
        let step = size * Metrics.listIndent
        let p = NSMutableParagraphStyle()
        p.setParagraphStyle(paragraph(size))
        p.firstLineHeadIndent = step * CGFloat(depth - 1)
        p.headIndent = step * CGFloat(depth)
        p.tabStops = [NSTextTab(textAlignment: .left, location: step * CGFloat(depth))]
        p.paragraphSpacing = closing ? size * Metrics.paragraphSpacing : 0
        return p
    }

    /// Строка блока кода. Каждая строка блока — отдельный абзац, поэтому обычная
    /// отбивка разнесла бы код на несвязанные строки; воздух возвращается только
    /// на последней строке блока (`closing`).
    static func codeParagraph(_ size: CGFloat, closing: Bool) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.setParagraphStyle(paragraph(size))
        p.paragraphSpacing = closing ? size * Metrics.paragraphSpacing : 0
        return p
    }
}
