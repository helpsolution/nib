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
