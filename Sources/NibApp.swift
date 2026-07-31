// Точка входа.

import SwiftUI

@main
struct NibApp: App {
    @FocusedValue(\.zoom) var zoom

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorScreen(document: file.$document)
        }
        // Дефолт SwiftUI — 900×450, в него влезает полтора десятка строк.
        // Применяется только к окну без сохранённой геометрии: свой размер система запомнит.
        .defaultSize(width: 1240, height: 840)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Крупнее") { zoom?.inc() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Мельче") { zoom?.dec() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Размер по умолчанию") { zoom?.reset() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Колонка шире") { zoom?.wider() }
                    .keyboardShortcut("]", modifiers: [.command, .option])
                Button("Колонка уже") { zoom?.tighter() }
                    .keyboardShortcut("[", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) { }
        }
    }
}
