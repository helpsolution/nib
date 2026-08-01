// Типографика. Числа тут не косметика: от межстрочного интервала зависит
// высота каретки, а от неё — ощущение от редактора.

import AppKit

func runTypoTests() {

    Check.suite("Типографика: шрифт") {
        let f = Typo.body(17)
        Check.close(f.pointSize, 17, "кегль как просили")
        Check.ok(f.isFixedPitch || f.fontName.contains("Mono") || f.fontName.contains("Menlo"),
                 "основной шрифт моноширинный", f.fontName)
        Check.ok(Typo.bold(f).fontDescriptor.symbolicTraits.contains(.bold), "жирное начертание")
        Check.ok(Typo.italic(f).fontDescriptor.symbolicTraits.contains(.italic), "курсивное начертание")
        Check.ok(Typo.mono(17).pointSize < 17, "код набирается чуть мельче основного текста")

        Check.ok(Typo.body(17) === Typo.body(17), "повторный запрос отдаёт тот же объект из кеша")
    }

    Check.suite("Типографика: ритм строки") {
        let f = Typo.body(17)
        let natural = f.ascender - f.descender
        let p = Typo.paragraph(17)

        Check.equal(p.lineHeightMultiple, 0,
                    "высота строки не задаётся явно, иначе каретка растянется на весь шаг")
        Check.close(p.lineSpacing, natural * 0.5, "межстрочный интервал — половина высоты шрифта")
        Check.close(natural + p.lineSpacing, natural * 1.5, "шаг строки соответствует line-height 1.5")
        Check.ok(p.paragraphSpacing > 0, "между абзацами есть воздух")
    }

    Check.suite("Настройки: границы значений") {
        Check.ok(Prefs.fontRange.contains(Prefs.defaultFontSize), "кегль по умолчанию внутри диапазона")
        Check.ok(Prefs.widthRange.contains(Prefs.defaultLineWidth), "ширина по умолчанию внутри диапазона")
        Check.equal(Prefs.clampFont(999), Prefs.fontRange.upperBound, "кегль сверху ограничен")
        Check.equal(Prefs.clampFont(0), Prefs.fontRange.lowerBound, "кегль снизу ограничен")
        Check.equal(Prefs.clampWidth(9999), Prefs.widthRange.upperBound, "ширина сверху ограничена")
        Check.equal(Prefs.clampWidth(1), Prefs.widthRange.lowerBound, "ширина снизу ограничена")
    }

    Check.suite("Оформление: сопоставление с системным appearance") {
        Check.equal(Appearance.system.nsAppearance, nil, "системное — не навязываем appearance")
        Check.equal(Appearance.light.nsAppearance?.name, .aqua, "светлое")
        Check.equal(Appearance.dark.nsAppearance?.name, .darkAqua, "тёмное")
        Check.equal(Appearance(rawValue: "нет такого"), nil, "неизвестное значение отбрасывается")
    }
}
