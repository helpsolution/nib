// Подсветка: что должно гаснуть, что выделяться, и совпадает ли
// инкрементальный проход с полным.

import AppKit

func runHighlighterTests() {

    Check.suite("Подсветка: базовые правила") {
        let md = """
        # Заголовок

        Текст с **жирным** и *курсивом*, ссылка [сюда](https://x.dev) и `код`.

        - пункт списка
        > цитата
        """
        let s = highlighted(md)
        let body = Typo.body(17)

        Check.ok(s.isBold(at: index(of: "Заголовок", in: md)), "текст заголовка жирный")
        Check.ok(s.font(at: index(of: "Заголовок", in: md))!.pointSize > body.pointSize,
                 "текст заголовка крупнее основного")
        Check.equal(s.color(at: 0), NSColor.tertiaryLabelColor, "решётка заголовка погашена")

        Check.ok(s.isBold(at: index(of: "жирным", in: md)), "содержимое ** жирное")
        Check.equal(s.color(at: index(of: "**жирным", in: md)), NSColor.tertiaryLabelColor,
                    "звёздочки ** погашены")

        Check.ok(s.isItalic(at: index(of: "курсивом", in: md)), "содержимое * курсивное")

        Check.equal(s.color(at: index(of: "сюда", in: md)), NSColor.controlAccentColor,
                    "текст ссылки акцентный")
        Check.equal(s.color(at: index(of: "https://x.dev", in: md)), NSColor.tertiaryLabelColor,
                    "адрес ссылки погашен")

        Check.ok(s.isMonospaced(at: index(of: "код", in: md)), "инлайн-код моноширинный")
        Check.equal(s.color(at: index(of: "- пункт", in: md)), NSColor.tertiaryLabelColor,
                    "маркер списка погашен")
        Check.ok(s.isItalic(at: index(of: "цитата", in: md)), "цитата курсивом")
    }

    Check.suite("Подсветка: уровни заголовков") {
        let md = """
        # Первый

        ## Второй

        ###### Шестой

        Обычный текст.
        """
        let s = highlighted(md)
        let h1 = s.font(at: index(of: "Первый", in: md))!.pointSize
        let h2 = s.font(at: index(of: "Второй", in: md))!.pointSize
        let h6 = s.font(at: index(of: "Шестой", in: md))!.pointSize
        let body = s.font(at: index(of: "Обычный", in: md))!.pointSize

        Check.ok(h1 > h2 && h2 > h6, "чем глубже уровень, тем мельче заголовок", "\(h1) \(h2) \(h6)")
        Check.ok(h6 > body, "даже шестой уровень крупнее основного текста", "\(h6) против \(body)")
        Check.ok([h1, h2, h6].allSatisfy { $0 > 0 }, "кегль заголовка положителен")

        // Семь решёток заголовком уже не считаются — это текст.
        let overflow = "####### Не заголовок"
        let o = highlighted(overflow)
        Check.ok(!o.isBold(at: index(of: "Не заголовок", in: overflow)),
                 "семь решёток заголовком не считаются")

        // Решётка без пробела — тоже не заголовок.
        let noSpace = "#НеЗаголовок"
        let n = highlighted(noSpace)
        Check.ok(!n.isBold(at: index(of: "НеЗаголовок", in: noSpace)),
                 "решётка без пробела заголовком не считается")
    }

    Check.suite("Подсветка: списки, линии, зачёркивание") {
        let md = """
        - минус
        * звёздочка
        + плюс
        1. нумерованный
        2) со скобкой

        ---

        Текст с ~~зачёркиванием~~ внутри.

        > первая цитата
        >> вложенная
        """
        let s = highlighted(md)

        for marker in ["- минус", "* звёздочка", "+ плюс", "1. нумерованный", "2) со скобкой"] {
            Check.equal(s.color(at: index(of: marker, in: md)), NSColor.tertiaryLabelColor,
                        "маркер «\(marker.prefix(2).trimmingCharacters(in: .whitespaces))» погашен")
        }

        Check.equal(s.color(at: index(of: "---", in: md)), NSColor.tertiaryLabelColor,
                    "горизонтальная линия погашена")
        Check.equal(s.color(at: index(of: "зачёркиванием", in: md)), NSColor.secondaryLabelColor,
                    "зачёркнутый текст приглушён")
        Check.ok(s.isItalic(at: index(of: "вложенная", in: md)), "вложенная цитата тоже курсивом")
    }

    Check.suite("Подсветка: что разметкой быть не должно") {
        let md = """
        Умножение 2 * 3 * 4 без курсива.

        snake_case_имя не курсив.

        Незакрытая **звёздочка остаётся текстом.
        """
        let s = highlighted(md)

        Check.ok(!s.isItalic(at: index(of: "3", in: md)),
                 "звёздочки вокруг пробелов курсив не делают")
        Check.ok(!s.isItalic(at: index(of: "case", in: md)),
                 "подчёркивания внутри слова курсив не делают")
        Check.ok(!s.isBold(at: index(of: "звёздочка остаётся", in: md)),
                 "незакрытый жирный остаётся текстом")
    }

    Check.suite("Подсветка: блоки кода") {
        let md = """
        Обычный **жирный** текст.

        ```markdown
        # это не заголовок
        - это не список
        let x = "**это не жирный**"
        let y = [ссылка](https://x.dev)
        ```

        Снова **жирный**.
        """
        let s = highlighted(md)

        Check.ok(s.isMonospaced(at: index(of: "let x", in: md)), "содержимое блока моноширинное")
        Check.ok(s.isBold(at: index(of: "Снова **жирный", in: md) + 8),
                 "разметка после блока кода работает")

        // Ниже — поведение, откаченное вместе с рефакторингом (см. af0ff8c).
        // В 1.1.1 разметка внутри ``` красится наравне с обычным текстом:
        // подсветка проходит по всему диапазону, не считая блоки занятыми.
        //
        // Заголовок — единственное исключение, и то случайное: правило заголовков
        // отрабатывает раньше блоков, и шрифт блока затирает жирный сверху.
        // Абзацный стиль блок не трогает, поэтому отбивка заголовка остаётся.
        let hashInFence = index(of: "# это не заголовок", in: md)
        Check.ok(!s.isBold(at: hashInFence), "решётка в блоке кода не делает жирный заголовок")

        let spacingInFence = (s.attribute(.paragraphStyle, at: hashInFence, effectiveRange: nil)
            as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0
        Check.knownBug(spacingInFence == 0,
                       "решётка в блоке кода не рвёт код отбивкой заголовка",
                       "отбивка \(spacingInFence) pt, вернуть фикс из 4b2b71b")

        let bulletInFence = index(of: "- это не список", in: md)
        Check.knownBug(s.color(at: bulletInFence) != NSColor.tertiaryLabelColor,
                       "дефис в блоке кода не гасится как маркер списка", "вернуть фикс из 4b2b71b")

        let boldInFence = index(of: "это не жирный", in: md)
        Check.knownBug(!s.isBold(at: boldInFence),
                       "звёздочки в блоке кода не делают жирный", "вернуть фикс из 4b2b71b")

        let linkInFence = index(of: "ссылка", in: md)
        Check.knownBug(s.color(at: linkInFence) != NSColor.controlAccentColor,
                       "ссылка в блоке кода не подсвечена как ссылка", "вернуть фикс из 4b2b71b")
    }

    Check.suite("Подсветка: инкрементальный проход равен полному") {
        let md = """
        # Заметка

        Абзац с **жирным**, *курсивом* и `кодом`.

        - список
        - второй пункт

        > цитата

        ```swift
        let a = 1
        let b = 2
        ```

        Хвост документа.
        """

        // Каждая правка описана содержимым, а не координатами: так тест переживает
        // изменение примера выше.
        let edits: [(String, String, Int)] = [
            ("символ в конце", "x", md.utf16.count),
            ("новый заголовок в начале", "## Свежий\n\n", 0),
            ("жирный в середине абзаца", " **добавка** ", index(of: "Абзац с", in: md) + 6),
            ("перевод строки", "\n", index(of: "- список", in: md)),
            ("правка внутри блока кода", "// ", index(of: "let a = 1", in: md)),
            ("пункт списка", "- третий\n", index(of: "- второй", in: md)),
            ("абзац с разметкой", "Ещё `код` и [ссылка](u).\n\n", index(of: "> цитата", in: md)),
        ]

        let storage = NSTextStorage(string: md)
        Highlighter.apply(to: storage, size: 17)

        for (what, insertion, at) in edits {
            comparePasses(storage, what: what) {
                let location = min(at, storage.length)
                storage.replaceCharacters(in: NSRange(location: location, length: 0), with: insertion)
                return NSRange(location: location, length: (insertion as NSString).length)
            }
        }
    }

    Check.suite("Подсветка: нечётное число тройных кавычек") {
        // Вставка одиночной ``` и снос закрывающей — две стороны одной задачи:
        // после правки кавычек в тексте нечётное число, и структура блоков ниже
        // меняется целиком.
        //
        // Со вставкой всё в порядке: правка задевает строку с кавычками, и
        // fenceAware честно перекрашивает весь документ. Со сносом — нет: кавычки
        // в тексте уже нет, задевать нечего, и бывший блок остаётся покрашенным.
        let md = """
        # Заголовок

        Абзац с **жирным** текстом.

        ```swift
        let a = 1
        ```

        Хвост документа.
        """

        let inserting = NSTextStorage(string: md)
        Highlighter.apply(to: inserting, size: 17)
        let insertOK = passesMatch(inserting) {
            let at = index(of: "Хвост", in: md)
            inserting.replaceCharacters(in: NSRange(location: at, length: 0), with: "```\n")
            return NSRange(location: at, length: 4)
        }
        Check.ok(insertOK, "вставка одиночной тройной кавычки")

        let deleting = NSTextStorage(string: md)
        Highlighter.apply(to: deleting, size: 17)
        let deleteOK = passesMatch(deleting) {
            let closing = (md as NSString).range(of: "```", options: .backwards)
            deleting.replaceCharacters(in: closing, with: "")
            return NSRange(location: closing.location, length: 0)
        }
        Check.knownBug(deleteOK, "снос закрывающей тройной кавычки", "вернуть фикс из 4b2b71b")
    }

    Check.suite("Подсветка: пустой и вырожденный ввод") {
        let empty = NSTextStorage(string: "")
        Highlighter.apply(to: empty, size: 17)
        Check.equal(empty.length, 0, "пустой документ не падает")

        Check.equal(highlighted("#").length, 1, "одинокая решётка не падает")
        Check.ok(highlighted("```swift\nlet a = 1\n").length > 0, "незакрытый блок кода не падает")
        Check.ok(highlighted("```\n```").length > 0, "пустой блок кода не падает")
        Check.ok(highlighted("\n\n\n").length > 0, "одни переводы строки не падают")
        Check.ok(highlighted("[](  )").length > 0, "пустая ссылка не падает")
        Check.ok(highlighted("****").length > 0, "четыре звёздочки не падают")

        // Правка за пределами текста: диапазон приходится обрезать, иначе
        // paragraphRange(for:) уронит процесс на выходе за границы.
        let s = NSTextStorage(string: "Короткий текст")
        Highlighter.apply(to: s, size: 17, in: NSRange(location: 9999, length: 50))
        Check.ok(true, "правка за пределами документа не падает")

        Highlighter.apply(to: s, size: 17, in: NSRange(location: 0, length: 0))
        Check.ok(true, "правка нулевой длины не падает")
    }
}

// MARK: - Сравнение проходов

/// Применяет правку, красит инкрементально, затем красит целиком —
/// и говорит, совпали ли результаты.
private func passesMatch(_ storage: NSTextStorage, _ edit: () -> NSRange) -> Bool {
    let dirty = edit()
    Highlighter.apply(to: storage, size: 17, in: dirty)
    let incremental = storage.styleSnapshot()
    Highlighter.apply(to: storage, size: 17)
    return incremental == storage.styleSnapshot()
}

/// То же, но с отчётом о первом расхождении: без него «не совпало» бесполезно.
private func comparePasses(_ storage: NSTextStorage, what: String, _ edit: () -> NSRange) {
    let dirty = edit()
    Highlighter.apply(to: storage, size: 17, in: dirty)
    let incremental = storage.styleSnapshot()

    Highlighter.apply(to: storage, size: 17)
    let full = storage.styleSnapshot()

    if incremental == full {
        Check.ok(true, what)
        return
    }
    let at = (0..<min(incremental.count, full.count)).first { incremental[$0] != full[$0] } ?? -1
    let ch = at >= 0 ? (storage.string as NSString).substring(with: NSRange(location: at, length: 1)) : "?"
    Check.ok(false, what,
             "позиция \(at) «\(ch)»\n      инкрементально: \(at >= 0 ? incremental[at] : "-")"
             + "\n      полностью:      \(at >= 0 ? full[at] : "-")")
}
