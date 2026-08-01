// Типографика. Числа тут не косметика: от межстрочного интервала зависит
// высота каретки, а от неё — ощущение от редактора.

import AppKit

func runTypoTests() {

    Check.suite("Типографика: шрифт") {
        let f = Typo.body(17)
        Check.close(f.pointSize, 17, "кегль как просили")
        Check.ok(f.isFixedPitch || f.fontName.contains("Mono") || f.fontName.contains("Menlo"),
                 "основной шрифт моноширинный", f.fontName)
        Check.ok(Typo.preferred.contains(f.familyName ?? "") || f.isFixedPitch,
                 "шрифт выбран из списка предпочтений либо это системный моноширинный",
                 "\(f.familyName ?? "-")")
        Check.ok(Typo.bold(f).fontDescriptor.symbolicTraits.contains(.bold), "жирное начертание")
        Check.ok(Typo.italic(f).fontDescriptor.symbolicTraits.contains(.italic), "курсивное начертание")
        Check.close(Typo.body(11).pointSize, 11, "мелкий кегль")
        Check.close(Typo.body(32).pointSize, 32, "крупный кегль")
        Check.ok(Typo.mono(17).pointSize < 17, "код набирается чуть мельче основного текста")
        Check.ok(Typo.mono(17).isFixedPitch, "код всегда моноширинный, чем бы ни был основной шрифт")
    }

    Check.suite("Типографика: ритм строки") {
        let f = Typo.body(17)
        let natural = f.ascender - f.descender
        let p = Typo.paragraph(17)

        Check.equal(p.lineHeightMultiple, 0,
                    "высота строки не задаётся явно, иначе каретка растянется на весь шаг")
        Check.equal(p.minimumLineHeight, 0,
                    "минимальная высота строки не задаётся — по той же причине")
        Check.close(p.lineSpacing, natural * 0.5, "межстрочный интервал — половина высоты шрифта")
        Check.close(natural + p.lineSpacing, natural * 1.5, "шаг строки соответствует line-height 1.5")
        Check.ok(p.paragraphSpacing > 0, "между абзацами есть воздух")
        Check.close(p.defaultTabInterval, 34, "шаг табуляции — два кегля")

        // Ритм должен масштабироваться вместе с кеглем, а не быть прибитым константой.
        let small = Typo.paragraph(11), large = Typo.paragraph(32)
        Check.ok(small.lineSpacing < p.lineSpacing && p.lineSpacing < large.lineSpacing,
                 "межстрочный интервал растёт вместе с кеглем")
        Check.ok(small.paragraphSpacing < large.paragraphSpacing,
                 "отбивка абзаца растёт вместе с кеглем")
    }

    Check.suite("Оформление: сопоставление с системным appearance") {
        Check.equal(Appearance.system.nsAppearance, nil, "системное — не навязываем appearance")
        Check.equal(Appearance.light.nsAppearance?.name, .aqua, "светлое")
        Check.equal(Appearance.dark.nsAppearance?.name, .darkAqua, "тёмное")
        Check.equal(Appearance(rawValue: "нет такого"), nil, "неизвестное значение отбрасывается")
        Check.equal(Appearance.allCases.count, 3, "в меню ровно три варианта")
        Check.ok(Appearance.allCases.allSatisfy { !$0.title.isEmpty }, "у каждого варианта есть название")
        Check.ok(Appearance.allCases.allSatisfy { $0.id == $0.rawValue },
                 "идентификатор совпадает с сохраняемым значением")
    }
}
