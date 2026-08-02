// Режим просмотра: markdown, разобранный в готовое оформление.
//
// Подсветка (Highlighter) — декоратор: она расставляет атрибуты поверх исходной
// строки, символ в символ. Здесь наоборот, трансформация: разметки в результате
// нет вовсе, зато появляются буллеты, номера и линейки, которых нет в файле.
// Поэтому это отдельный проход, а не режим подсветки: спрятать разметку в живом
// редакторе можно только скрыв глифы, и тогда в буфер обмена уходит то,
// чего на экране не видно.
//
// Разбор берём у Foundation: cmark-gfm уже внутри системы, свой парсер писать
// незачем. Оформление — из Typo, чтобы ритм строки в обоих режимах совпадал.
//
// Тип назван Renderer, а не Preview: SwiftUI с macOS 14 экспортирует собственный
// Preview, и одноимённый тип молча затенял бы его внутри модуля.

import AppKit

enum Renderer {

    /// Атрибуты, которыми Foundation размечает результат разбора.
    /// Ключи не экспортированы в Swift, поэтому обращаемся по именам.
    private enum Parsed {
        static let block = NSAttributedString.Key("NSPresentationIntent")
        static let inline = NSAttributedString.Key("NSInlinePresentationIntent")
        static let image = NSAttributedString.Key("NSImageURL")
    }

    enum Layout {
        /// Толщина горизонтальной линейки.
        static let ruleThickness: CGFloat = 1
        /// Воздух вокруг линейки, в долях кегля.
        static let rulePadding: CGFloat = 0.6
        /// Поля ячейки таблицы, в долях кегля.
        static let cellPadding: CGFloat = 0.4
    }

    /// Готовое оформление документа. Чистая функция: вью не нужна, поэтому
    /// проверяется обычными тестами без окна.
    ///
    /// `width` — ширина колонки: по ней растягиваются линейка и таблицы.
    static func attributed(_ markdown: String, size: CGFloat, width: CGFloat) -> NSAttributedString {
        guard let parsed = parse(markdown) else {
            // Разбор не удался — показываем исходник как есть. Пустой экран
            // на месте документа был бы хуже неотформатированного текста.
            return NSAttributedString(string: markdown, attributes: [
                .font: Typo.body(size),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: Typo.paragraph(size)
            ])
        }

        let out = NSMutableAttributedString()
        let all = blocks(of: parsed)
        var i = 0
        var afterTable = false
        while i < all.count {
            if out.length > 0 { out.append(NSAttributedString(string: "\n")) }

            // Таблицы, списки и цитаты приходят россыпью отдельных блоков.
            // Собираем группу целиком: только зная её конец, можно поставить
            // отбивку на выходе, а не между пунктами одного списка.
            let group = group(of: all[i])
            var j = i + 1
            if group != .single {
                while j < all.count, self.group(of: all[j]) == group { j += 1 }
            }
            let piece = NSMutableAttributedString(
                attributedString: render(Array(all[i..<j]), group: group, size: size, width: width))
            // Отбивку после таблицы ставит следующий блок: заданная на самой
            // таблице, она растянула бы нижний ряд изнутри вместо отступа за ней.
            if afterTable { spaceBefore(piece, size * Typo.Metrics.paragraphSpacing) }
            afterTable = group.isTable
            out.append(piece)
            i = j
        }
        return out
    }

    private static func spaceBefore(_ text: NSMutableAttributedString, _ gap: CGFloat) {
        guard text.length > 0 else { return }
        let first = (text.string as NSString).paragraphRange(for: NSRange(location: 0, length: 0))
        let base = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let p = NSMutableParagraphStyle()
        if let base { p.setParagraphStyle(base) }
        p.paragraphSpacingBefore += gap
        text.addAttribute(.paragraphStyle, value: p, range: first)
    }

    private static func parse(_ markdown: String) -> NSAttributedString? {
        try? NSAttributedString(
            markdown: Data(markdown.utf8),
            options: .init(allowsExtendedAttributes: true,
                           interpretedSyntax: .full,
                           failurePolicy: .returnPartiallyParsedIfPossible),
            baseURL: nil)
    }

    // MARK: - Нарезка на блоки

    /// Один блок документа: абзац, заголовок, пункт списка, ячейка таблицы.
    private struct Block {
        var intent: PresentationIntent?
        var text: NSMutableAttributedString

        /// Самый внутренний интент. `components` идут от листа к корню.
        var leaf: PresentationIntent.Kind? { intent?.components.first?.kind }

        /// Ищет охватывающий интент по предикату — цитату, список, таблицу.
        func enclosing(_ match: (PresentationIntent.Kind) -> Bool) -> PresentationIntent.Kind? {
            intent?.components.first(where: { match($0.kind) })?.kind
        }

        var identity: Int? { intent?.components.first?.identity }

        /// Пункт списка, которому принадлежит блок. У пункта из нескольких абзацев
        /// все они дают один и тот же идентификатор.
        var itemIdentity: Int? {
            intent?.components.first(where: {
                if case .listItem = $0.kind { return true }
                return false
            })?.identity
        }
    }

    /// Границей блока считаем смену листового интента: Foundation выбрасывает
    /// переводы строк между блоками, и по самой строке границу уже не найти.
    private static func blocks(of parsed: NSAttributedString) -> [Block] {
        var out: [Block] = []
        parsed.enumerateAttributes(in: NSRange(location: 0, length: parsed.length)) { attrs, range, _ in
            let intent = attrs[Parsed.block] as? PresentationIntent
            let identity = intent?.components.first?.identity
            if out.isEmpty || out[out.count - 1].identity != identity {
                out.append(Block(intent: intent, text: NSMutableAttributedString()))
            }
            out[out.count - 1].text.append(parsed.attributedSubstring(from: range))
        }
        return out
    }

    // MARK: - Группы блоков

    /// Что склеивает соседние блоки в одно целое. Определяется самым внешним
    /// контейнером: пункты списка внутри цитаты — это цитата, а не список.
    private enum Group: Equatable {
        case single
        case table(Int)
        case list(Int)
        case quote(Int)

        var isTable: Bool {
            if case .table = self { return true }
            return false
        }
    }

    private static func group(of block: Block) -> Group {
        // components идут от листа к корню, поэтому внешний контейнер — последний.
        for component in (block.intent?.components ?? []).reversed() {
            switch component.kind {
            case .table: return .table(component.identity)
            case .orderedList, .unorderedList: return .list(component.identity)
            case .blockQuote: return .quote(component.identity)
            default: continue
            }
        }
        return .single
    }

    private static func render(_ blocks: [Block],
                               group kind: Group,
                               size: CGFloat,
                               width: CGFloat) -> NSAttributedString {
        switch kind {
        case .table:
            return table(blocks, size: size)
        case .quote:
            return quote(blocks, size: size, width: width)
        case .list, .single:
            let out = NSMutableAttributedString()
            var previousItem: Int?
            for (offset, block) in blocks.enumerated() {
                if out.length > 0 { out.append(NSAttributedString(string: "\n")) }
                // У пункта из нескольких абзацев маркер ставится только первому:
                // остальные — продолжение того же пункта, а не новые пункты.
                let item = block.itemIdentity
                let continues = item != nil && item == previousItem
                previousItem = item
                out.append(render(block, size: size, width: width,
                                  closing: offset == blocks.count - 1,
                                  continues: continues))
            }
            return out
        }
    }

    // MARK: - Оформление блока

    /// `closing` — блок закрывает свою группу и потому получает отбивку.
    /// `continues` — блок продолжает начатый пункт списка, маркер ему не нужен.
    private static func render(_ block: Block,
                               size: CGFloat,
                               width: CGFloat,
                               closing: Bool,
                               continues: Bool = false) -> NSAttributedString {
        let text = inlineStyled(block.text, size: size)

        switch block.leaf {
        case .header(let level):
            text.setAttributes([.font: Typo.heading(size, level: level),
                                .foregroundColor: NSColor.textColor,
                                .paragraphStyle: Typo.headingParagraph(size)],
                               range: NSRange(location: 0, length: text.length))
            return text

        case .thematicBreak:
            return rule(size: size, width: width)

        case .codeBlock:
            let code = NSMutableAttributedString(attributedString: codeBlock(text, size: size))
            // Блок кода внутри пункта списка должен стоять под текстом пункта,
            // а не уезжать к левому полю.
            if let item = listItem(block) {
                shift(code, by: size * Typo.Metrics.listIndent * CGFloat(item.depth), size: size)
            }
            return code

        default:
            break
        }

        if let item = listItem(block) {
            return listRow(text, item: item, size: size, closing: closing, continues: continues)
        }

        apply(Typo.paragraph(size), to: text)
        return text
    }

    private static func apply(_ style: NSParagraphStyle, to text: NSMutableAttributedString) {
        text.addAttribute(.paragraphStyle, value: style,
                          range: NSRange(location: 0, length: text.length))
    }

    // MARK: - Инлайновое оформление

    /// Раскрашивает раны внутри блока: жирный, курсив, код, зачёркнутое, ссылки.
    /// Базовый шрифт ставится здесь же — дальше блок может его переопределить.
    private static func inlineStyled(_ source: NSAttributedString, size: CGFloat) -> NSMutableAttributedString {
        let base = Typo.body(size)
        let out = NSMutableAttributedString()

        source.enumerateAttributes(in: NSRange(location: 0, length: source.length)) { attrs, range, _ in
            let piece = NSMutableAttributedString(string: (source.string as NSString).substring(with: range))
            let whole = NSRange(location: 0, length: piece.length)

            // Картинку отрисовать нечем: сетевые URL редактор не грузит, а alt-текст
            // без пометки не отличить от обычного слова.
            if attrs[Parsed.image] != nil {
                piece.setAttributes([.font: Typo.italic(base),
                                     .foregroundColor: NSColor.tertiaryLabelColor], range: whole)
                out.append(piece)
                return
            }

            var font = base
            var color = NSColor.textColor
            let intent = (attrs[Parsed.inline] as? NSNumber)
                .map { InlinePresentationIntent(rawValue: $0.uintValue) } ?? []

            if intent.contains(.code) {
                font = Typo.mono(size)
                color = .secondaryLabelColor
            } else {
                if intent.contains(.stronglyEmphasized) { font = Typo.bold(font) }
                if intent.contains(.emphasized) { font = Typo.italic(font) }
            }
            piece.setAttributes([.font: font, .foregroundColor: color], range: whole)

            if intent.contains(.strikethrough) {
                piece.addAttribute(.strikethroughStyle,
                                   value: NSUnderlineStyle.single.rawValue, range: whole)
            }
            if let link = attrs[.link] {
                piece.addAttributes([.link: link,
                                     .foregroundColor: NSColor.controlAccentColor,
                                     .underlineStyle: NSUnderlineStyle.single.rawValue], range: whole)
            }
            out.append(piece)
        }
        return out
    }

    // MARK: - Списки

    private struct ListItem {
        var depth: Int
        var marker: String
        /// Сколько символов срезать с начала текста: у чекбокса это «[ ] ».
        var strip: Int
    }

    /// Глубина, номер и маркер пункта — или nil, если блок не в списке.
    private static func listItem(_ block: Block) -> ListItem? {
        guard let components = block.intent?.components else { return nil }

        var depth = 0
        var ordinal: Int?
        var ordered = false
        // Идём от листа наружу: первый встреченный список — свой, он и задаёт вид маркера.
        for component in components {
            switch component.kind {
            case .listItem(let n):
                if ordinal == nil { ordinal = n }
            case .orderedList:
                if ordinal != nil && depth == 0 { ordered = true }
                depth += 1
            case .unorderedList:
                depth += 1
            default:
                break
            }
        }
        guard depth > 0, let ordinal else { return nil }

        if let box = checkbox(block.text.string) {
            return ListItem(depth: depth, marker: box, strip: 4)
        }
        return ListItem(depth: depth,
                        marker: ordered ? "\(ordinal)." : "•",
                        strip: 0)
    }

    /// GFM-чекбоксы Foundation не разбирает — они приходят буквальным текстом.
    private static func checkbox(_ text: String) -> String? {
        if text.hasPrefix("[ ] ") { return "☐" }
        if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") { return "☑" }
        return nil
    }

    private static func listRow(_ text: NSMutableAttributedString,
                                item: ListItem,
                                size: CGFloat,
                                closing: Bool,
                                continues: Bool) -> NSAttributedString {
        if !continues {
            if item.strip > 0, text.length >= item.strip {
                text.deleteCharacters(in: NSRange(location: 0, length: item.strip))
            }
            text.insert(NSAttributedString(string: item.marker + "\t", attributes: [
                .font: Typo.body(size),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]), at: 0)
        }
        let style = Typo.listParagraph(size, depth: item.depth, closing: closing)
        if continues {
            // Продолжение пункта начинается там же, где его текст, а не где маркер.
            let p = NSMutableParagraphStyle()
            p.setParagraphStyle(style)
            p.firstLineHeadIndent = style.headIndent
            // Абзацы внутри пункта разделяются как абзацы, иначе они слипаются.
            p.paragraphSpacing = size * Typo.Metrics.paragraphSpacing
            apply(p, to: text)
        } else {
            apply(style, to: text)
        }
        return text
    }

    // MARK: - Цитаты

    /// Цитата — не собственное оформление, а сдвиг поверх обычного: внутри неё
    /// бывают и списки, и заголовки, и код, и выглядеть они должны как всегда,
    /// только смещёнными и приглушёнными. Курсив — тот же, что в режиме исходника,
    /// чтобы цитата опознавалась одинаково в обоих.
    private static func quote(_ blocks: [Block], size: CGFloat, width: CGFloat) -> NSAttributedString {
        let indent = size * Typo.Metrics.quoteIndent * CGFloat(max(1, quoteDepth(blocks[0])))

        let out = NSMutableAttributedString()
        for (offset, block) in blocks.enumerated() {
            if out.length > 0 { out.append(NSAttributedString(string: "\n")) }
            let closing = offset == blocks.count - 1
            let text = NSMutableAttributedString(
                attributedString: render(block, size: size, width: width, closing: closing))
            shift(text, by: indent, size: size)
            text.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor,
                              range: NSRange(location: 0, length: text.length))
            if case .paragraph = block.leaf { italicize(text) }
            out.append(text)
        }
        return out
    }

    private static func quoteDepth(_ block: Block) -> Int {
        (block.intent?.components ?? []).reduce(into: 0) { count, component in
            if case .blockQuote = component.kind { count += 1 }
        }
    }

    /// Сдвигает готовые абзацы вправо, сохраняя их собственные отступы:
    /// вложенный в цитату список остаётся списком со своей ступенью.
    private static func shift(_ text: NSMutableAttributedString, by indent: CGFloat, size: CGFloat) {
        let whole = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.paragraphStyle, in: whole) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? Typo.paragraph(size)
            let p = NSMutableParagraphStyle()
            p.setParagraphStyle(base)
            p.firstLineHeadIndent += indent
            p.headIndent += indent
            p.tabStops = base.tabStops.map {
                NSTextTab(textAlignment: $0.alignment, location: $0.location + indent)
            }
            text.addAttribute(.paragraphStyle, value: p, range: range)
        }
    }

    private static func italicize(_ text: NSMutableAttributedString) {
        let whole = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.font, in: whole) { value, range, _ in
            guard let font = value as? NSFont else { return }
            text.addAttribute(.font, value: Typo.italic(font), range: range)
        }
    }

    // MARK: - Блоки кода

    /// Внутри блока каждая строка — отдельный абзац, и отбивка абзаца разорвала бы
    /// код на несвязанные строки. Поэтому отбивка нулевая, а воздух после блока
    /// возвращается на последней строке.
    private static func codeBlock(_ text: NSMutableAttributedString, size: CGFloat) -> NSAttributedString {
        // Закрывающий перевод строки парсер оставляет — иначе блок закончился бы пустым абзацем.
        if text.string.hasSuffix("\n") {
            text.deleteCharacters(in: NSRange(location: text.length - 1, length: 1))
        }
        let whole = NSRange(location: 0, length: text.length)
        text.setAttributes([.font: Typo.mono(size),
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .paragraphStyle: Typo.codeParagraph(size, closing: false)],
                           range: whole)

        let lastLine = (text.string as NSString).paragraphRange(for: NSRange(location: max(0, text.length - 1), length: 0))
        text.addAttribute(.paragraphStyle, value: Typo.codeParagraph(size, closing: true), range: lastLine)
        return text
    }

    // MARK: - Таблицы

    /// Идентификатор таблицы, которой принадлежит блок, — или nil, если блок не ячейка.
    /// По нему подряд идущие ячейки собираются в одну сетку.
    private static func tableIdentity(_ block: Block) -> Int? {
        block.intent?.components.first(where: {
            if case .table = $0.kind { return true }
            return false
        })?.identity
    }

    /// Строка, колонка и признак шапки. `components` идут от листа к корню:
    /// ячейка, затем строка, затем таблица.
    private static func cellPosition(_ block: Block) -> (row: Int, column: Int, header: Bool)? {
        guard let components = block.intent?.components else { return nil }
        var column: Int?
        var row: Int?
        var header = false
        for component in components {
            switch component.kind {
            case .tableCell(let c): if column == nil { column = c }
            case .tableHeaderRow: if row == nil { row = 0; header = true }
            case .tableRow(let r): if row == nil { row = r }
            default: break
            }
        }
        guard let column, let row else { return nil }
        return (row, column, header)
    }

    private static func columns(_ block: Block) -> [PresentationIntent.TableColumn] {
        for component in block.intent?.components ?? [] {
            if case .table(let columns) = component.kind { return columns }
        }
        return []
    }

    /// Сетка из `NSTextTable`. Работает только в TextKit 1 — поэтому вью просмотра
    /// сознательно откатывается на него (см. Editor.makePreview).
    private static func table(_ cells: [Block], size: CGFloat) -> NSAttributedString {
        let columns = columns(cells[0])
        let grid = NSTextTable()
        grid.numberOfColumns = max(1, columns.count)
        grid.layoutAlgorithm = .automaticLayoutAlgorithm
        grid.collapsesBorders = true
        grid.setContentWidth(100, type: .percentageValueType)

        let out = NSMutableAttributedString()
        for cell in cells {
            guard let at = cellPosition(cell) else { continue }
            if out.length > 0 { out.append(NSAttributedString(string: "\n")) }

            let box = NSTextTableBlock(table: grid,
                                       startingRow: at.row, rowSpan: 1,
                                       startingColumn: at.column, columnSpan: 1)
            box.setBorderColor(.separatorColor)
            box.setWidth(Layout.ruleThickness, type: .absoluteValueType, for: .border)
            box.setWidth(size * Layout.cellPadding, type: .absoluteValueType, for: .padding)

            let style = NSMutableParagraphStyle()
            style.setParagraphStyle(Typo.paragraph(size))
            // Внутри ячейки отбивка абзаца не нужна: строка таблицы не абзац.
            // Воздух после таблицы ставит следующий блок — заданный здесь,
            // он растянул бы нижний ряд изнутри вместо отступа за таблицей.
            style.paragraphSpacing = 0
            style.textBlocks = [box]
            if at.column < columns.count {
                style.alignment = alignment(columns[at.column].alignment)
            }

            let text = inlineStyled(cell.text, size: size)
            if at.header {
                text.addAttribute(.font, value: Typo.bold(Typo.body(size)),
                                  range: NSRange(location: 0, length: text.length))
            }
            apply(style, to: text)
            out.append(text)
        }
        return out
    }

    private static func alignment(_ column: PresentationIntent.TableColumn.Alignment) -> NSTextAlignment {
        switch column {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        @unknown default: return .left
        }
    }

    // MARK: - Горизонтальная линейка

    /// Линейка рисуется вложением: подчёркиванием пустой строки получается
    /// чёрточка в ширину пробела, а не линия в колонку.
    private static func rule(size: CGFloat, width: CGFloat) -> NSAttributedString {
        let padding = size * Layout.rulePadding
        let image = NSImage(size: NSSize(width: width, height: Layout.ruleThickness), flipped: false) { rect in
            NSColor.separatorColor.setFill()
            rect.fill()
            return true
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: 0, width: width, height: Layout.ruleThickness)

        let style = NSMutableParagraphStyle()
        style.setParagraphStyle(Typo.paragraph(size))
        style.paragraphSpacingBefore = padding
        style.paragraphSpacing = padding

        let out = NSMutableAttributedString(attachment: attachment)
        out.addAttribute(.paragraphStyle, value: style,
                         range: NSRange(location: 0, length: out.length))
        return out
    }
}
