// Точка входа.

import SwiftUI

@main
struct NibApp: App {
    @FocusedValue(\.zoom) var zoom
    @AppStorage(Prefs.Key.appearance) private var appearance: Appearance = .system

    init() { Prefs.appearance.apply() }

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
                Divider()
                // Picker в CommandGroup рисуется как пункты меню с галочкой.
                Picker("Оформление", selection: Binding(
                    get: { appearance },
                    set: { appearance = $0; $0.apply() }
                )) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            }
            CommandGroup(replacing: .help) { }
        }
    }
}
