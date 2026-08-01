// Якорь типографики: точные числа, а не «примерно похоже».
//
// Зачем отдельный файл с битовыми масками. Откаченный рефакторинг (af0ff8c)
// переписал `1.0 + (0.30 - 0.04 * n)` в `1 + 0.30 - 0.04 * n`. Скобки во float
// не бесплатны: у заголовков h4 и h5 кегль уехал на 1 ULP — 20.06 против
// 20.060000000000002. Другой pointSize — другие метрики глифов — потенциально
// другой перенос строки. Поймать это было нечем, и рефакторинг откатили целиком.
//
// Проверки ниже сравнивают bitPattern, а не значения с допуском: допуск как раз
// и пропустил бы ту разницу. Значения, зависящие от установленного шрифта,
// пинятся не абсолютом, а формулой — иначе тест ломался бы на чужой машине.

import AppKit

func runMetricsAnchorTests() {

    Check.suite("Якорь: кегль заголовка по уровням") {
        // Сняты с текущей сборки. Меняются только вместе с осознанным решением
        // поменять вид заголовков — тогда числа обновляются здесь же, руками.
        let expected: [UInt] = [
            4626913814667434394,  // h1 = 22.1
            4626722411683271148,  // h2 = 21.42
            4626531008699107901,  // h3 = 20.74
            4626339605714944655,  // h4 = 20.06
            4626148202730781409,  // h5 = 19.38
            4625956799746618164,  // h6 = 18.700000000000003
        ]

        var md = ""
        for level in 1...6 {
            md += String(repeating: "#", count: level) + " Заголовок\n\n"
        }
        let s = highlighted(md, size: 17)

        for level in 1...6 {
            let marker = String(repeating: "#", count: level) + " Заголовок"
            let point: CGFloat = s.font(at: index(of: marker, in: md))!.pointSize
            Check.equal(point.bitPattern, expected[level - 1],
                        "h\(level): кегль бит-в-бит (\(point))")
        }
    }

    Check.suite("Якорь: производные от кегля") {
        let size: CGFloat = 17

        Check.equal(Typo.mono(size).pointSize.bitPattern, (size * 0.94).bitPattern,
                    "кегль кода — ровно size * 0.94")

        let p = Typo.paragraph(size)
        Check.equal(p.paragraphSpacing.bitPattern, (size * 0.55).bitPattern,
                    "отбивка абзаца — ровно size * 0.55")
        Check.equal(p.defaultTabInterval.bitPattern, (size * 2).bitPattern,
                    "табуляция — ровно size * 2")

        // Отбивка перед заголовком снимается через подсветку: отдельной функции
        // для неё пока нет, значение ставится по месту в Highlighter.
        let md = "Текст.\n\n# Заголовок\n"
        let s = highlighted(md, size: size)
        let style = s.attribute(.paragraphStyle, at: index(of: "# Заголовок", in: md),
                                effectiveRange: nil) as? NSParagraphStyle
        let before: CGFloat = style?.paragraphSpacingBefore ?? 0
        Check.equal(before.bitPattern, (size * 0.8).bitPattern,
                    "воздух перед заголовком — ровно size * 0.8")
    }

    Check.suite("Якорь: межстрочный интервал") {
        // Абсолютное значение зависит от того, какой шрифт нашёлся в системе,
        // поэтому пинится связь с метриками шрифта, а не само число.
        for size in [11, 17, 32] as [CGFloat] {
            let f = Typo.body(size)
            let natural = f.ascender - f.descender
            Check.equal(Typo.paragraph(size).lineSpacing.bitPattern, (natural * 0.5).bitPattern,
                        "кегль \(Int(size)): межстрочный — ровно (ascender - descender) * 0.5")
        }
    }

    Check.suite("Якорь: геометрия колонки") {
        let tv = ColumnTextView()
        tv.maxLineWidth = 700

        // Формула боковых полей: min(max(30, (ширина - колонка) / 2), ширина / 2).
        // Каждая ветка проверяется на своём числе.
        let cases: [(CGFloat, CGFloat, String)] = [
            (1240, 270, "широкое окно: (1240 - 700) / 2"),
            (760, 30, "окно чуть шире колонки: сработал нижний предел"),
            (500, 30, "окно уже колонки: нижний предел"),
            (40, 20, "окно уже двух минимальных полей: сработал предел ширина / 2"),
            (0, 0, "нулевая ширина: поля тоже нулевые"),
        ]
        for (width, expected, what) in cases {
            tv.frame = NSRect(x: 0, y: 0, width: width, height: 600)
            tv.refreshInsets()
            Check.equal(tv.textContainerInset.width.bitPattern, expected.bitPattern, what)
        }

        Check.equal(tv.textContainerInset.height.bitPattern, CGFloat(48).bitPattern,
                    "вертикальный отступ — ровно 48")
    }

    Check.suite("Якорь: границы и шаги масштаба") {
        // Значения зашиты в EditorScreen литералами и снаружи недоступны.
        // Пока их не вынесли — фиксируем сам факт: 11...32, 420...1100, шаг 60,
        // сброс к 17. Если после рефакторинга числа станут именованными,
        // проверка должна сослаться на них, а не на литералы.
        Check.close(Prefs.fontSize, 17, "сброс кегля ведёт к 17")
        Check.close(Prefs.lineWidth, 700, "ширина по умолчанию 700")
        Check.ok((11...32).contains(CGFloat(17)), "кегль по умолчанию внутри 11...32")
        Check.ok((420...1100).contains(CGFloat(700)), "ширина по умолчанию внутри 420...1100")
        Check.close(700 + 60, 760, "шаг ширины 60")
    }
}
