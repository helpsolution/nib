// Документ: чтение и запись .md с сохранением исходной кодировки.

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownDocument: FileDocument {
    var text: String

    /// Кодировка, в которой файл был прочитан. При сохранении возвращаем его в ней же —
    /// иначе однобайтовые кодировки (CP1251, MacRoman) молча превратились бы в мусор.
    private(set) var encoding: String.Encoding

    init(text: String = "", encoding: String.Encoding = .utf8) {
        self.text = text
        self.encoding = encoding
    }

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let decoded = Self.decode(data) else {
            throw CocoaError(.fileReadUnknownStringEncoding)
        }
        text = decoded.text
        encoding = decoded.encoding
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: encoded())
    }

    /// Байты для записи на диск.
    /// Текст мог уйти за пределы исходной кодировки (эмодзи в файле CP1251) —
    /// тогда повышаемся до UTF-8: это меняет кодировку файла, но ничего не теряет.
    func encoded() -> Data {
        text.data(using: encoding) ?? Data(text.utf8)
    }

    /// Определяет кодировку без потерь. Возвращает nil, если распознать не удалось —
    /// лучше отказать в открытии, чем подставить U+FFFD и затереть оригинал при сохранении.
    static func decode(_ data: Data) -> (text: String, encoding: String.Encoding)? {
        if data.isEmpty { return ("", .utf8) }

        // Строгий UTF-8: nil при первом же невалидном байте, замен на U+FFFD не делает.
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }

        // Дальше — системная эвристика (BOM, статистика байтов). Она сообщает,
        // что именно применила, поэтому обратная запись остаётся байт-в-байт точной.
        // lossy отвергаем: раз потери уже на чтении, сохранение затрёт оригинал мусором.
        var converted: NSString?
        var lossy: ObjCBool = false
        let raw = NSString.stringEncoding(for: data,
                                          encodingOptions: nil,
                                          convertedString: &converted,
                                          usedLossyConversion: &lossy)
        if raw != 0, !lossy.boolValue, let s = converted {
            return (s as String, String.Encoding(rawValue: raw))
        }

        return nil
    }
}
