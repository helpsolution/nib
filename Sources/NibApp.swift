// Точка входа.

import SwiftUI

@main
struct NibApp: App {
    @FocusedValue(\.editor) var editor
    @AppStorage(Prefs.Key.appearance) private var appearance: Appearance = .system

    /// Дефолт SwiftUI — 900×450, в него влезает полтора десятка строк.
    static let defaultWindow = CGSize(width: 1240, height: 840)

    init() { Prefs.appearance.apply() }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            EditorScreen(document: file.$document)
        }
        // Применяется только к окну без сохранённой геометрии: свой размер система запомнит.
        .defaultSize(Self.defaultWindow)
        .commands {
            CommandGroup(after: .toolbar) {
                // Пункт с галочкой: режим окна виден в меню, а не только по экрану.
                Toggle("Просмотр", isOn: Binding(
                    get: { editor?.isPreview ?? false },
                    set: { _ in editor?.togglePreview() }
                ))
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Крупнее") { editor?.inc() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Мельче") { editor?.dec() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Размер по умолчанию") { editor?.reset() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Колонка шире") { editor?.wider() }
                    .keyboardShortcut("]", modifiers: [.command, .option])
                Button("Колонка уже") { editor?.tighter() }
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
