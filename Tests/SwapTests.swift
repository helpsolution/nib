// Переключение режимов: единственная проверка, которой нужна живая вью.
//
// Всё остальное про просмотр тестируется на чистой функции Renderer.attributed.
// Здесь проверяется связка, которую та не покрывает: SwiftUI меняет isPreview →
// updateNSView прячет одну вью и показывает другую → в вью просмотра приезжает
// отрисованный текст. Именно тут ломается, если поплывёт контейнер или
// координатор перестанет пересобирать превью.

import SwiftUI
import AppKit

private final class Model: ObservableObject {
    @Published var preview = false
    @Published var text = "# Заголовок\n\nАбзац с **жирным**.\n\n- пункт\n"
}

private struct Harness: View {
    @ObservedObject var model: Model
    var body: some View {
        Editor(text: $model.text, fontSize: 17, lineWidth: 700,
               isPreview: model.preview, onStats: { _, _ in })
    }
}

private func scrollViews(in view: NSView) -> [NSScrollView] {
    (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap(scrollViews)
}

/// Прокручивает цикл событий: SwiftUI применяет изменения не мгновенно.
private func settle(_ turns: Int = 60) {
    for _ in 0..<turns {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005))
    }
}

func runSwapTests() {
    Check.suite("Переключение режимов") {
        _ = NSApplication.shared

        let model = Model()
        let host = NSHostingView(rootView: Harness(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        settle()

        let views = scrollViews(in: host)
        Check.equal(views.count, 2, "в окне живут обе вью — исходник и просмотр")
        guard views.count == 2 else { return }
        let source = views[0], preview = views[1]

        Check.ok(!source.isHidden && preview.isHidden,
                 "сначала виден исходник")

        model.preview = true
        settle()
        Check.ok(source.isHidden && !preview.isHidden,
                 "после переключения виден просмотр")

        let shown = (preview.documentView as? NSTextView)?.string ?? ""
        Check.ok(shown.contains("Заголовок") && shown.contains("жирным"),
                 "в просмотр приехало содержимое документа", shown.debugDescription)
        Check.ok(!shown.contains("**") && !shown.contains("#"),
                 "в просмотре нет разметки", shown.debugDescription)
        Check.ok(shown.contains("•"), "список отрисован буллетом", shown.debugDescription)

        model.preview = false
        settle()
        Check.ok(!source.isHidden && preview.isHidden,
                 "обратное переключение возвращает исходник")
        Check.ok((source.documentView as? NSTextView)?.string.contains("**") == true,
                 "в исходнике разметка на месте")

        // Правка в исходнике должна доехать до просмотра, а не показать старое.
        model.text = "## Другой текст"
        model.preview = true
        settle()
        let updated = (preview.documentView as? NSTextView)?.string ?? ""
        Check.ok(updated.contains("Другой текст"), "просмотр пересобрался после правки",
                 updated.debugDescription)
        Check.ok(!updated.contains("Заголовок"), "старое содержимое не осталось")

        window.close()
    }
}
