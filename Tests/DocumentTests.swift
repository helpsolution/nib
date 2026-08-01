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
            ("UTF-8 без перевода строки в конце", Data("одна строка".utf8)),
            ("UTF-16 LE с BOM", Data([0xFF, 0xFE]) + cyrillic.data(using: .utf16LittleEndian)!),
            ("CP1251", cyrillic.data(using: .windowsCP1251)!),
            ("KOI8-R", "# Заголовок\n\nПростой текст.\n".data(using: koi8r)!),
            ("MacRoman", latin.data(using: .macOSRoman)!),
            ("CRLF сохраняется как есть", Data("строка\r\nвторая\r\n".utf8)),
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

    Check.suite("Документ: UTF-16 BE переворачивается в LE") {
        // Системная эвристика распознаёт оба порядка байтов как обобщённый .utf16,
        // а запись в .utf16 на Apple-платформах всегда даёт little-endian с BOM.
        // Текст цел, но файл, открытый и закрытый без единой правки, меняется на
        // диске целиком. Чтобы это чинить, decode должен различать порядок по BOM
        // и дописывать BOM при записи вручную: .utf16BigEndian его не ставит.
        let source = "# Заголовок\n\nТекст с ё.\n"
        let be = Data([0xFE, 0xFF]) + source.data(using: .utf16BigEndian)!

        guard let decoded = MarkdownDocument.decode(be) else {
            Check.ok(false, "UTF-16 BE распознаётся", "decode вернул nil")
            return
        }
        Check.equal(decoded.text, source, "текст UTF-16 BE читается без потерь")

        let written = MarkdownDocument(text: decoded.text, encoding: decoded.encoding).encoded()
        Check.equal(written.count, be.count, "длина в байтах не меняется")
        Check.knownBug(written == be, "UTF-16 BE сохраняется в исходном порядке байтов",
                       "decode отдаёт .utf16, запись всегда даёт LE + BOM")
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

    Check.suite("Документ: пустой файл и значения по умолчанию") {
        let decoded = MarkdownDocument.decode(Data())
        Check.equal(decoded?.text, "", "пустой файл читается как пустой текст")
        Check.equal(decoded?.encoding, .utf8, "пустому файлу назначается UTF-8")

        let fresh = MarkdownDocument()
        Check.equal(fresh.text, "", "новый документ пуст")
        Check.equal(fresh.encoding, .utf8, "новый документ в UTF-8")
        Check.equal(fresh.encoded(), Data(), "новый документ пишется нулём байт")
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

        // Обрезанная UTF-8 последовательность: первый байт двухбайтового символа
        // без второго. Строгий UTF-8 обязан отвергнуть, а не дописать U+FFFD.
        if let decoded = MarkdownDocument.decode(Data([0xD0, 0x9F, 0xD0])) {
            Check.ok(!decoded.text.contains("\u{FFFD}"),
                     "обрезанный UTF-8: без символов замены",
                     "распознан как \(decoded.encoding)")
        } else {
            Check.ok(true, "обрезанный UTF-8: отказ в открытии")
        }
    }

    Check.suite("Документ: текст вне исходной кодировки") {
        // В файл CP1251 дописали эмодзи. Кодировку сменить можно, потерять символ — нет.
        let document = MarkdownDocument(text: "Привет 🖋", encoding: .windowsCP1251)
        let written = document.encoded()
        Check.equal(String(data: written, encoding: .utf8), "Привет 🖋",
                    "повышение до UTF-8 сохраняет весь текст")

        // Обратный случай: текст остался в пределах CP1251 — повышаться незачем.
        let plain = MarkdownDocument(text: "Привет", encoding: .windowsCP1251)
        Check.equal(plain.encoded(), "Привет".data(using: .windowsCP1251)!,
                    "текст в пределах кодировки пишется в ней же")
    }

    Check.suite("Документ: правка не сбрасывает кодировку") {
        guard let decoded = MarkdownDocument.decode("Текст\n".data(using: .windowsCP1251)!) else {
            Check.ok(false, "CP1251 распознаётся", "decode вернул nil")
            return
        }
        var document = MarkdownDocument(text: decoded.text, encoding: decoded.encoding)
        document.text += "Дописали строку\n"
        Check.equal(document.encoding, decoded.encoding, "кодировка пережила правку текста")
        Check.equal(document.encoded(), "Текст\nДописали строку\n".data(using: .windowsCP1251)!,
                    "правленый текст пишется в исходной кодировке")
    }
}
