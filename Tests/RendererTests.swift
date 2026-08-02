// Режим просмотра: что разметки в результате нет, а оформление на месте.

import AppKit

/// Готовое оформление как хранилище — рендерер чистая функция, вью не нужна.
func rendered(_ markdown: String, size: CGFloat = 17, width: CGFloat = 700) -> NSTextStorage {
    NSTextStorage(attributedString: Renderer.attributed(markdown, size: size, width: width))
}

private func paragraphStyle(_ s: NSTextStorage, at index: Int) -> NSParagraphStyle? {
    s.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
}

func runRendererTests() {

    Check.suite("Просмотр: разметка не течёт в результат") {
        let md = """
        # Заголовок

        Текст с **жирным**, *курсивом*, `кодом`, ~~зачёркнутым~~
        и [ссылкой](https://x.dev).

        - пункт
        1. первый

        > цитата

        ```swift
        let a = 1
        ```
        """
        let out = rendered(md).string

        // Одна проверка на класс регрессий: любая разметка, дожившая до экрана,
        // означает, что соответствующий интент не разобран.
        for marker in ["**", "~~", "](", "```", "#"] {
            Check.ok(!out.contains(marker), "в результате нет «\(marker)»", out.debugDescription)
        }
        Check.ok(!out.contains("https://x.dev"), "адрес ссылки не показывается как текст")
        Check.ok(out.contains("Заголовок"), "содержимое заголовка на месте")
        Check.ok(out.contains("жирным"), "содержимое ** на месте")
        Check.ok(out.contains("ссылкой"), "текст ссылки на месте")
        Check.ok(out.contains("let a = 1"), "содержимое блока кода на месте")
    }

    Check.suite("Просмотр: границы блоков") {
        // Foundation выбрасывает переводы строк между блоками — разделители
        // расставляет рендерер, и это самая вероятная поломка.
        let s = rendered("Первый абзац.\n\nВторой абзац.")
        Check.ok(!s.string.contains("абзац.Второй"), "абзацы не слиплись", s.string.debugDescription)
        Check.ok(s.string.contains("\n"), "между абзацами есть перевод строки")

        let list = rendered("- один\n- два")
        Check.ok(!list.string.contains("один•"), "пункты списка не слиплись",
                 list.string.debugDescription)
    }

    Check.suite("Просмотр: заголовки") {
        let md = "# Первый\n\n## Второй\n\n###### Шестой\n\nОбычный текст."
        let s = rendered(md)
        let h1 = s.font(at: index(of: "Первый", in: s.string))!.pointSize
        let h2 = s.font(at: index(of: "Второй", in: s.string))!.pointSize
        let h6 = s.font(at: index(of: "Шестой", in: s.string))!.pointSize
        let body = s.font(at: index(of: "Обычный", in: s.string))!.pointSize

        Check.ok(h1 > h2 && h2 > h6, "чем глубже уровень, тем мельче заголовок", "\(h1) \(h2) \(h6)")
        Check.ok(h6 > body, "даже шестой уровень крупнее основного текста", "\(h6) против \(body)")
        Check.ok(s.isBold(at: index(of: "Первый", in: s.string)), "заголовок жирный")

        // Кегли берутся у Typo, а не пересчитываются заново: иначе переключение
        // режимов меняло бы размер заголовка.
        Check.equal(h1, Typo.heading(17, level: 1).pointSize, "кегль h1 совпадает с Typo")
        Check.equal(h6, Typo.heading(17, level: 6).pointSize, "кегль h6 совпадает с Typo")
    }

    Check.suite("Просмотр: инлайновое оформление") {
        let md = "Текст с **жирным**, *курсивом*, `кодом`, ~~зачёркнутым~~ и [ссылкой](https://x.dev)."
        let s = rendered(md)
        let text = s.string

        Check.ok(s.isBold(at: index(of: "жирным", in: text)), "содержимое ** жирное")
        Check.ok(s.isItalic(at: index(of: "курсивом", in: text)), "содержимое * курсивное")
        Check.ok(s.isMonospaced(at: index(of: "кодом", in: text)), "инлайн-код моноширинный")

        let strike = s.attribute(.strikethroughStyle, at: index(of: "зачёркнутым", in: text),
                                 effectiveRange: nil) as? Int
        Check.equal(strike, NSUnderlineStyle.single.rawValue, "зачёркнутое зачёркнуто")

        let at = index(of: "ссылкой", in: text)
        Check.ok(s.attribute(.link, at: at, effectiveRange: nil) != nil, "у ссылки есть адрес")
        Check.equal(s.color(at: at), NSColor.controlAccentColor, "текст ссылки акцентный")
    }

    Check.suite("Просмотр: списки") {
        let s = rendered("- пункт\n  - вложенный\n\n1. первый\n2. второй")
        let text = s.string

        Check.ok(text.contains("•\tпункт"), "маркер подставлен вместо дефиса", text.debugDescription)
        Check.ok(text.contains("1.\tпервый"), "номер подставлен", text.debugDescription)
        Check.ok(text.contains("2.\tвторой"), "нумерация продолжается")

        let outer = paragraphStyle(s, at: index(of: "пункт", in: text))!
        let inner = paragraphStyle(s, at: index(of: "вложенный", in: text))!
        Check.ok(outer.headIndent > 0, "у пункта висячий отступ", "\(outer.headIndent)")
        Check.ok(inner.headIndent > outer.headIndent,
                 "вложенный пункт отступает дальше родителя",
                 "\(inner.headIndent) против \(outer.headIndent)")
        Check.ok(!outer.tabStops.isEmpty, "табуляция под маркер задана")

        // Внутри списка отбивки нет, иначе пункты разъезжаются как абзацы.
        Check.equal(outer.paragraphSpacing, 0, "между пунктами списка нет отбивки")
        let last = paragraphStyle(s, at: index(of: "второй", in: text))!
        Check.ok(last.paragraphSpacing > 0, "последний пункт отбивает список от следующего блока")
    }

    Check.suite("Просмотр: пункт из нескольких блоков") {
        // Пункт с вложенным блоком кода и вторым абзацем: маркер полагается
        // только первому абзацу, остальное — продолжение того же пункта.
        let md = """
        1. Первый.
        2. Второй:

           ```bash
           echo привет
           ```

           Продолжение второго пункта.
        """
        let s = rendered(md)
        let text = s.string

        Check.ok(text.components(separatedBy: "2.\t").count - 1 == 1,
                 "маркер пункта поставлен один раз", text.debugDescription)
        Check.ok(!text.contains("2.\tПродолжение"), "продолжение не стало новым пунктом")
        Check.ok(text.contains("echo привет"), "вложенный блок кода на месте")

        let item = paragraphStyle(s, at: index(of: "Второй", in: text))!
        let code = paragraphStyle(s, at: index(of: "echo", in: text))!
        let tail = paragraphStyle(s, at: index(of: "Продолжение", in: text))!

        Check.ok(code.headIndent >= item.headIndent,
                 "блок кода внутри пункта не уезжает к левому полю",
                 "\(code.headIndent) против \(item.headIndent)")
        Check.equal(tail.firstLineHeadIndent, item.headIndent,
                    "продолжение начинается под текстом пункта, а не под маркером")
    }

    Check.suite("Просмотр: чекбоксы") {
        // GFM-чекбоксы Foundation не разбирает — рендерер подставляет их сам.
        let s = rendered("- [ ] не сделано\n- [x] сделано")
        let text = s.string
        Check.ok(text.contains("☐\tне сделано"), "пустой чекбокс", text.debugDescription)
        Check.ok(text.contains("☑\tсделано"), "отмеченный чекбокс", text.debugDescription)
        Check.ok(!text.contains("[ ]") && !text.contains("[x]"), "скобки чекбокса убраны")
    }

    Check.suite("Просмотр: блоки кода") {
        let s = rendered("```swift\nlet a = 1\nlet b = 2\n```\n\nПосле блока.")
        let text = s.string

        Check.ok(s.isMonospaced(at: index(of: "let a", in: text)), "код моноширинный")
        Check.ok(!text.contains("swift\n"), "подсказка языка не попала в текст",
                 text.debugDescription)
        Check.ok(!text.hasSuffix("\n\nПосле блока."), "лишний пустой абзац в конце блока не остался")

        let first = paragraphStyle(s, at: index(of: "let a", in: text))!
        let last = paragraphStyle(s, at: index(of: "let b", in: text))!
        Check.equal(first.paragraphSpacing, 0, "строки кода не разнесены отбивкой абзаца")
        Check.ok(last.paragraphSpacing > 0, "после блока кода есть воздух")
    }

    Check.suite("Просмотр: цитаты") {
        let s = rendered("Абзац.\n\n> цитата\n\nПосле.")
        let text = s.string
        let at = index(of: "цитата", in: text)

        Check.ok(s.isItalic(at: at), "цитата курсивом — как и в режиме исходника")
        Check.equal(s.color(at: at), NSColor.secondaryLabelColor, "цитата приглушена")

        let quote = paragraphStyle(s, at: at)!
        let plain = paragraphStyle(s, at: index(of: "Абзац", in: text))!
        Check.ok(quote.headIndent > plain.headIndent,
                 "цитата сдвинута вправо относительно обычного абзаца",
                 "\(quote.headIndent) против \(plain.headIndent)")
    }

    Check.suite("Просмотр: горизонтальная линейка") {
        let s = rendered("Выше.\n\n---\n\nНиже.")
        var attachments = 0
        s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { value, _, _ in
            if value != nil { attachments += 1 }
        }
        Check.equal(attachments, 1, "линейка нарисована ровно одним вложением")
        Check.ok(!s.string.contains("---"), "дефисы линейки не показываются как текст")
        Check.ok(s.string.contains("Выше.") && s.string.contains("Ниже."),
                 "текст вокруг линейки на месте")
    }

    Check.suite("Просмотр: таблицы") {
        let s = rendered("| Ключ | Значение |\n|---|---|\n| a | 1 |")
        let text = s.string

        Check.ok(!text.contains("|"), "разделители таблицы не показываются", text.debugDescription)
        Check.ok(text.contains("Ключ") && text.contains("Значение") && text.contains("a"),
                 "содержимое ячеек на месте")
        Check.ok(s.isBold(at: index(of: "Ключ", in: text)), "шапка таблицы жирная")

        let cell = paragraphStyle(s, at: index(of: "a", in: text))!
        Check.ok(!cell.textBlocks.isEmpty, "ячейка лежит в текстовом блоке — значит, это сетка")
        Check.ok(cell.textBlocks.first is NSTextTableBlock, "блок ячейки — блок таблицы")
    }

    Check.suite("Просмотр: связь с типографикой") {
        // Ритм строки в обоих режимах обязан совпадать, иначе переключение прыгает.
        let s = rendered("Обычный абзац.")
        let style = paragraphStyle(s, at: 0)!
        Check.equal(style.lineSpacing, Typo.paragraph(17).lineSpacing,
                    "межстрочный интервал взят у Typo")
        Check.equal(s.font(at: 0)?.pointSize, Typo.body(17).pointSize,
                    "кегль основного текста взят у Typo")
        Check.equal(s.color(at: 0), NSColor.textColor, "основной текст контрастный")
    }

    Check.suite("Просмотр: пустой и вырожденный ввод") {
        // Тот же корпус, что у подсветки: рендерер не должен падать ни на чём.
        let cases = ["", "#", "```swift\nlet a = 1\n", "```\n```", "\n\n\n",
                     "[](  )", "****", "| a |\n|", "> ", "- ", "1.", "~~~",
                     "![](", "\u{0}", String(repeating: "*", count: 500)]
        for md in cases {
            let s = rendered(md)
            Check.ok(s.length >= 0, "не падает на \(md.debugDescription)")
        }
        Check.equal(rendered("").length, 0, "пустой документ даёт пустой результат")
    }

    Check.suite("Просмотр: повторный проход") {
        let md = "# Заголовок\n\n- пункт\n\n> цитата\n\n| a | b |\n|---|---|\n| 1 | 2 |"
        let first = rendered(md)
        let second = rendered(md)
        Check.equal(first.string, second.string, "текст повторного прохода совпадает")
        Check.equal(first.styleSnapshot(), second.styleSnapshot(),
                    "оформление повторного прохода совпадает")
    }
}
