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

    Check.suite("Подсветка: блоки кода защищены от разметки") {
        let md = """
        Обычный **жирный** текст.

        ```swift
        // # это не заголовок
        let x = "**это не жирный**"
        let y = [ссылка](https://x.dev)
        ```

        Снова **жирный**.
        """
        let s = highlighted(md)

        Check.ok(s.isMonospaced(at: index(of: "let x", in: md)), "содержимое блока моноширинное")

        let hashInFence = index(of: "# это не заголовок", in: md)
        Check.ok(!s.isBold(at: hashInFence), "решётка в блоке кода не делает заголовок")
        Check.ok(s.isMonospaced(at: hashInFence), "строка с решёткой осталась кодом")

        let boldInFence = index(of: "это не жирный", in: md)
        Check.ok(!s.isBold(at: boldInFence), "звёздочки в блоке кода не делают жирный")
        Check.ok(s.isMonospaced(at: boldInFence), "строка со звёздочками осталась кодом")

        let linkInFence = index(of: "ссылка", in: md)
        Check.ok(s.color(at: linkInFence) != NSColor.controlAccentColor,
                 "ссылка в блоке кода не подсвечена как ссылка")

        Check.ok(s.isBold(at: index(of: "Снова **жирный", in: md) + 8),
                 "разметка после блока кода работает")
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
            ("новая строка с тройной кавычкой", "```\n", index(of: "Хвост", in: md)),
            ("пункт списка", "- третий\n", index(of: "- второй", in: md)),
            ("абзац с разметкой", "Ещё `код` и [ссылка](u).\n\n", index(of: "> цитата", in: md)),
        ]

        let storage = NSTextStorage(string: md)
        Highlighter.apply(to: storage, size: 17)

        for (what, insertion, at) in edits {
            let location = min(at, storage.length)
            let edited = NSRange(location: location, length: (insertion as NSString).length)
            storage.replaceCharacters(in: NSRange(location: location, length: 0), with: insertion)
            Highlighter.apply(to: storage, size: 17, in: edited)
            let incremental = storage.styleSnapshot()

            Highlighter.apply(to: storage, size: 17)
            let full = storage.styleSnapshot()

            if incremental == full {
                Check.ok(true, what)
            } else {
                let at = (0..<min(incremental.count, full.count)).first { incremental[$0] != full[$0] } ?? -1
                let ch = at >= 0 ? (storage.string as NSString).substring(with: NSRange(location: at, length: 1)) : "?"
                Check.ok(false, what,
                         "позиция \(at) «\(ch)»\n      инкрементально: \(at >= 0 ? incremental[at] : "-")\n      полностью:      \(at >= 0 ? full[at] : "-")")
            }
        }
    }

    Check.suite("Подсветка: удаление тоже перекрашивает корректно") {
        let md = """
        # Заголовок

        Абзац с **жирным** текстом.

        ```swift
        let a = 1
        ```
        """
        let storage = NSTextStorage(string: md)
        Highlighter.apply(to: storage, size: 17)

        // Сносим закрывающую тройную кавычку: блок кода перестаёт быть блоком.
        let closing = (md as NSString).range(of: "```", options: .backwards)
        storage.replaceCharacters(in: closing, with: "")
        Highlighter.apply(to: storage, size: 17, in: NSRange(location: closing.location, length: 0))
        let incremental = storage.styleSnapshot()

        Highlighter.apply(to: storage, size: 17)
        Check.equal(incremental, storage.styleSnapshot(), "снос закрывающей кавычки")
    }

    Check.suite("Подсветка: пустой и вырожденный ввод") {
        let empty = NSTextStorage(string: "")
        Highlighter.apply(to: empty, size: 17)
        Check.equal(empty.length, 0, "пустой документ не падает")

        let onlyMarkers = highlighted("#")
        Check.equal(onlyMarkers.length, 1, "одинокая решётка не падает")

        let unclosed = highlighted("```swift\nlet a = 1\n")
        Check.ok(unclosed.length > 0, "незакрытый блок кода не падает")
    }
}
