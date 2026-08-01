// Крошечный каркас для тестов. XCTest не берём: он тянет за собой либо Xcode-проект,
// либо SwiftPM, а весь смысл проекта в том, что нужен только swiftc.

import AppKit

enum Check {
    static var passed = 0
    static var failed = 0
    static var known = 0

    static func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    static func ok(_ condition: Bool, _ what: String, _ detail: @autoclosure () -> String = "") {
        if condition {
            passed += 1
            print("  ✓ \(what)")
        } else {
            failed += 1
            let d = detail()
            print("  ✗ \(what)" + (d.isEmpty ? "" : "\n      \(d)"))
        }
    }

    static func equal<T: Equatable>(_ got: T, _ want: T, _ what: String) {
        ok(got == want, what, "получено: \(got)\n      ожидалось: \(want)")
    }

    static func close(_ got: CGFloat, _ want: CGFloat, _ what: String, tolerance: CGFloat = 0.01) {
        ok(abs(got - want) <= tolerance, what, "получено: \(got)\n      ожидалось: \(want) ± \(tolerance)")
    }

    /// Проверка на известный, ещё не исправленный дефект.
    ///
    /// `correct` — условие правильного поведения. Пока оно ложно, прогон остаётся
    /// зелёным, а дефект видно в отчёте: молча забыть про него нельзя. Как только
    /// условие станет истинным — проверка ПАДАЕТ с требованием снять маркер и
    /// перевести её в обычную `ok`. Иначе исправленный баг тихо остался бы
    /// «известным» навсегда.
    static func knownBug(_ correct: Bool, _ what: String, _ note: String) {
        if correct {
            failed += 1
            print("  ✗ \(what)\n      дефект исправлен — заменить knownBug на ok (\(note))")
        } else {
            known += 1
            print("  ○ \(what) — известный дефект: \(note)")
        }
    }

    static func report() -> Int32 {
        print("\n" + String(repeating: "─", count: 44))
        if known > 0 { print("Известных дефектов: \(known)") }
        if failed == 0 {
            print("Все проверки пройдены: \(passed)")
            return 0
        }
        print("Провалено: \(failed) из \(passed + failed)")
        return 1
    }
}

// MARK: - Помощники для подсветки

extension NSTextStorage {
    func font(at index: Int) -> NSFont? {
        attribute(.font, at: index, effectiveRange: nil) as? NSFont
    }

    func color(at index: Int) -> NSColor? {
        attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor
    }

    func isBold(at index: Int) -> Bool {
        font(at: index)?.fontDescriptor.symbolicTraits.contains(.bold) ?? false
    }

    func isItalic(at index: Int) -> Bool {
        font(at: index)?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
    }

    func isMonospaced(at index: Int) -> Bool {
        font(at: index)?.fontName.contains("Monospaced") ?? false
    }

    /// Посимвольный слепок оформления — для сравнения проходов между собой.
    /// Абзацный стиль тоже входит: отступ перед заголовком выставляется отдельной
    /// веткой, и без него расхождение проходов на заголовках осталось бы незамеченным.
    func styleSnapshot() -> [String] {
        var out: [String] = []
        var i = 0
        while i < length {
            var effective = NSRange()
            let attrs = attributes(at: i, effectiveRange: &effective)
            let f = attrs[.font] as? NSFont
            let c = attrs[.foregroundColor] as? NSColor
            let p = attrs[.paragraphStyle] as? NSParagraphStyle
            let desc = "\(f?.fontName ?? "-")@\(Int((f?.pointSize ?? 0) * 100))"
                + "/\(c?.description ?? "-")"
                + "/before:\(Int((p?.paragraphSpacingBefore ?? 0) * 100))"
            for _ in 0..<max(effective.length, 1) { out.append(desc) }
            if effective.length == 0 { break }
            i = NSMaxRange(effective)
        }
        return out
    }
}

/// Индекс первого вхождения подстроки. Тесты адресуются к тексту по содержимому,
/// а не по числам: иначе правка примера ломает половину проверок.
func index(of needle: String, in haystack: String) -> Int {
    let r = (haystack as NSString).range(of: needle)
    precondition(r.location != NSNotFound, "в примере нет «\(needle)»")
    return r.location
}

func highlighted(_ markdown: String, size: CGFloat = 17) -> NSTextStorage {
    let storage = NSTextStorage(string: markdown)
    Highlighter.apply(to: storage, size: size)
    return storage
}
