// Редактор. Живого окна не нужно: счётчик слов — чистая функция, а отступы
// колонки считаются от bounds, которые у NSView есть и без экрана.

import AppKit

func runEditorTests() {

    Check.suite("Счётчик слов") {
        let words = Editor.Coordinator.words

        Check.equal(words(""), 0, "пустой текст — ноль слов")
        Check.equal(words("   \n\t\n  "), 0, "одни пробелы — ноль слов")
        Check.equal(words("слово"), 1, "одно слово")
        Check.equal(words("два слова"), 2, "пробел разделяет")
        Check.equal(words("две\nстроки"), 2, "перевод строки разделяет")
        Check.equal(words("таб\tтоже"), 2, "табуляция разделяет")
        Check.equal(words("  лишние   пробелы  "), 2, "повторные пробелы не плодят пустых слов")
        Check.equal(words("# Заголовок"), 2, "разметка считается словом — как в любом счётчике")
        Check.equal(words("по-русски ёж"), 2, "дефис слово не разрывает")
        Check.equal(words("emoji 🖋 счёт"), 3, "эмодзи — отдельное слово")
    }

    Check.suite("Колонка: отступы по краям") {
        let tv = ColumnTextView()
        tv.maxLineWidth = 700

        // Окно шире колонки: текст стоит по центру, поля симметричны.
        tv.frame = NSRect(x: 0, y: 0, width: 1240, height: 840)
        tv.refreshInsets()
        Check.close(tv.textContainerInset.width, (1240 - 700) / 2, "широкое окно: колонка по центру")
        Check.close(tv.textContainerInset.width * 2 + 700, 1240, "поля и колонка заполняют ширину")

        // Окно уже колонки: поля схлопываются до минимума, но не в ноль —
        // иначе текст лип бы к самому краю.
        tv.frame = NSRect(x: 0, y: 0, width: 500, height: 840)
        tv.refreshInsets()
        Check.close(tv.textContainerInset.width, 30, "узкое окно: минимальные поля")

        // Окно уже двойного минимума. Тут и вылезал баг: поле 30 с каждой стороны
        // при ширине 40 оставляло контейнеру отрицательные 20 pt, и текст уезжал
        // за правый край. Верхняя граница bounds.width/2 это и предотвращает.
        tv.frame = NSRect(x: 0, y: 0, width: 40, height: 840)
        tv.refreshInsets()
        Check.ok(tv.textContainerInset.width * 2 <= 40,
                 "очень узкое окно: поля не съедают всю ширину",
                 "поле \(tv.textContainerInset.width) при ширине 40")

        // Самый первый layout приходит с нулевой шириной.
        tv.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
        tv.refreshInsets()
        Check.ok(tv.textContainerInset.width >= 0, "нулевая ширина не даёт отрицательных полей",
                 "поле \(tv.textContainerInset.width)")

        Check.close(tv.textContainerInset.height, 48, "вертикальный отступ постоянный")
    }

    Check.suite("Колонка: ширина колонки управляет полями") {
        let tv = ColumnTextView()
        tv.frame = NSRect(x: 0, y: 0, width: 1240, height: 840)

        tv.maxLineWidth = 420
        tv.refreshInsets()
        let narrow = tv.textContainerInset.width

        tv.maxLineWidth = 1100
        tv.refreshInsets()
        let wide = tv.textContainerInset.width

        Check.ok(narrow > wide, "чем уже колонка, тем шире поля", "\(narrow) против \(wide)")
        Check.close(narrow - wide, (1100 - 420) / 2, "разница полей — половина разницы колонок")
    }

    Check.suite("Оформление набираемого текста") {
        // Один источник на два места: makeNSView и смену кегля. Раньше словарь
        // был выписан дважды, и добавить атрибут в одном, забыв про второе,
        // значило получить прыжок оформления при первом же Cmd+«+».
        let attrs = Editor.typingAttributes(17)

        Check.equal((attrs[.font] as? NSFont)?.fontName, Typo.body(17).fontName,
                    "шрифт — основной")
        Check.close((attrs[.font] as? NSFont)?.pointSize ?? 0, 17, "кегль как просили")
        Check.equal(attrs[.foregroundColor] as? NSColor, NSColor.textColor, "цвет — основной")
        Check.equal((attrs[.paragraphStyle] as? NSParagraphStyle)?.lineSpacing.bitPattern,
                    Typo.paragraph(17).lineSpacing.bitPattern,
                    "абзацный стиль тот же, что у подсветки")
        Check.equal(attrs.count, 3, "ровно три атрибута — шрифт, цвет, абзац")

        // Подсветка ставит те же три атрибута. Разойдись они — первый символ
        // на пустой строке выглядел бы иначе, чем после перекраски.
        let s = highlighted("Текст", size: 17)
        Check.equal(s.font(at: 0)?.fontName, (attrs[.font] as? NSFont)?.fontName,
                    "набираемый текст и покрашенный — один шрифт")
        Check.equal(s.color(at: 0), attrs[.foregroundColor] as? NSColor,
                    "набираемый текст и покрашенный — один цвет")
    }

    Check.suite("Колонка: именованные размеры") {
        Check.close(ColumnTextView.Layout.verticalInset, 48, "вертикальный отступ 48")
        Check.close(ColumnTextView.Layout.minSideInset, 30, "минимальное боковое поле 30")
        Check.close(ColumnTextView.Layout.initialFrame.width, 800, "стартовая ширина 800")
        Check.close(ColumnTextView.Layout.initialFrame.height, 600, "стартовая высота 600")
        Check.ok(ColumnTextView.Layout.initialFrame.width > 0,
                 "стартовый размер ненулевой — иначе контейнер сочтёт себя пустым")
    }

    // NibApp в тесты не компилируется — там @main, он конфликтует с точкой
    // входа. Поэтому размер окна по умолчанию проверить нечем; минимальный —
    // можно, и он важнее: именно он определяет, во что окно складывается.
    Check.suite("Окно: минимальный размер") {
        Check.close(EditorScreen.Layout.minWindow.width, 480, "минимальная ширина 480")
        Check.close(EditorScreen.Layout.minWindow.height, 360, "минимальная высота 360")

        // Окно минимальной ширины обязано оставлять колонке место: при 480
        // и полях по 30 контейнеру достаётся 420 — ровно нижняя граница ширины.
        let usable = EditorScreen.Layout.minWindow.width - ColumnTextView.Layout.minSideInset * 2
        Check.ok(usable >= Prefs.widthRange.lowerBound,
                 "в минимальном окне помещается самая узкая колонка",
                 "\(usable) против \(Prefs.widthRange.lowerBound)")

        Check.close(EditorScreen.Layout.counterFontSize, 11, "кегль счётчика 11")
        Check.close(EditorScreen.Layout.counterInset, 12, "отступ счётчика от края 12")
        Check.ok((0...1).contains(EditorScreen.Layout.counterBackgroundOpacity),
                 "непрозрачность подложки в пределах 0...1")
    }

    Check.suite("Колонка: значения по умолчанию") {
        // maxLineWidth инициализируется из настроек — окно должно открываться
        // с той же колонкой, с какой закрылось.
        let saved = UserDefaults.standard.object(forKey: "lineWidth")
        defer { UserDefaults.standard.set(saved, forKey: "lineWidth") }

        UserDefaults.standard.set(880.0, forKey: "lineWidth")
        Check.close(ColumnTextView().maxLineWidth, 880, "ширина колонки берётся из настроек")

        UserDefaults.standard.removeObject(forKey: "lineWidth")
        Check.close(ColumnTextView().maxLineWidth, 700, "без настройки — значение по умолчанию")
    }
}
