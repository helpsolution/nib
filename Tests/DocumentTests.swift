// Чтение и запись файла. Главное свойство: открыл и сохранил без правок —
// получил те же байты. Нарушение этого однажды уже уничтожало файлы.

import Foundation

private let koi8r = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
    CFStringEncoding(CFStringEncodings.KOI8_R.rawValue)))

func runDocumentTests() {

    Check.suite("Документ: сохранение возвращает исходные байты") {
        let cyrillic = "# Заголовок\n\nТекст с ё, № и тире —.\n"
        let latin = "Caf\u{E9} r\u{E9}sum\u{E9}\n"

        let cases: [(String, Data)] = [
            ("UTF-8", Data(cyrillic.utf8)),
            ("UTF-8, пустой файл", Data()),
            ("UTF-8 с эмодзи", Data("Привет 🖋 мир\n".utf8)),
            ("UTF-16 LE с BOM", Data([0xFF, 0xFE]) + cyrillic.data(using: .utf16LittleEndian)!),
            ("CP1251", cyrillic.data(using: .windowsCP1251)!),
            ("KOI8-R", "# Заголовок\n\nПростой текст.\n".data(using: koi8r)!),
            ("MacRoman", latin.data(using: .macOSRoman)!),
        ]

        for (name, data) in cases {
            guard let decoded = MarkdownDocument.decode(data) else {
                Check.ok(false, name, "файл не распознался")
                continue
            }
            let document = MarkdownDocument(text: decoded.text, encoding: decoded.encoding)
            Check.ok(document.encoded() == data, name,
                     "было \(data.count) байт, стало \(document.encoded().count); "
                     + "U+FFFD в тексте: \(decoded.text.contains("\u{FFFD}"))")
        }
    }

    Check.suite("Документ: чужая кодировка читается верно, а не подменяется") {
        let source = "# Заголовок\n\nТекст с ё, № и тире —.\n"
        let cp1251 = source.data(using: .windowsCP1251)!

        // Как было до исправления: невалидные байты молча превращались в U+FFFD,
        // и сохранение записывало этот мусор поверх оригинала.
        let naive = String(decoding: cp1251, as: UTF8.self)
        Check.ok(naive.contains("\u{FFFD}") && Data(naive.utf8) != cp1251,
                 "наивное чтение действительно портит файл")

        guard let decoded = MarkdownDocument.decode(cp1251) else {
            Check.ok(false, "CP1251 распознаётся", "decode вернул nil")
            return
        }
        Check.ok(!decoded.text.contains("\u{FFFD}"), "после чтения нет символов замены")
        Check.equal(decoded.text, source, "текст совпадает с исходным")
    }

    Check.suite("Документ: отказ вместо порчи") {
        var junk = Data([0x00, 0x01, 0x02, 0xC0, 0x80, 0xFF, 0xFE, 0x00])
        junk.append(contentsOf: (0..<200).map { UInt8(($0 * 7 + 3) % 256) })

        if let decoded = MarkdownDocument.decode(junk) {
            // Распознать двоичный мусор как текст допустимо, потерять байты — нет.
            let document = MarkdownDocument(text: decoded.text, encoding: decoded.encoding)
            Check.ok(document.encoded() == junk, "двоичный мусор: открылся, но без потерь",
                     "распознан как \(decoded.encoding)")
        } else {
            Check.ok(true, "двоичный мусор: отказ в открытии")
        }
    }

    Check.suite("Документ: текст вне исходной кодировки") {
        // В файл CP1251 дописали эмодзи. Кодировку сменить можно, потерять символ — нет.
        let document = MarkdownDocument(text: "Привет 🖋", encoding: .windowsCP1251)
        let written = document.encoded()
        Check.equal(String(data: written, encoding: .utf8), "Привет 🖋",
                    "повышение до UTF-8 сохраняет весь текст")
    }
}
