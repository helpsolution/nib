// Настройки, живущие в UserDefaults.

import AppKit

/// Тема оформления. Цвета берутся из семантических NSColor, поэтому достаточно
/// задать appearance приложению — всё остальное, включая уже проставленные
/// подсветкой атрибуты, пересчитается само.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Системное"
        case .light:  return "Светлое"
        case .dark:   return "Тёмное"
        }
    }

    /// nil — следовать за системой.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    func apply() { NSApplication.shared.appearance = nsAppearance }
}

enum Prefs {
    /// Ключи в одном месте: раньше строка «fontSize» была написана четырежды —
    /// в геттере, в сеттере и в @AppStorage, — и опечатка в любой из них
    /// молча дала бы отдельную настройку вместо общей.
    enum Key {
        static let fontSize = "fontSize"
        static let lineWidth = "lineWidth"
        static let appearance = "appearance"
        static let preview = "preview"
    }

    /// Кегль: ниже 11 текст нечитаем, выше 32 в колонку помещается пара слов.
    static let defaultFontSize: CGFloat = 17
    static let fontRange: ClosedRange<CGFloat> = 11...32
    static let fontStep: CGFloat = 1

    /// Ширина колонки: ниже 420 строка рвётся на середине фразы,
    /// выше 1100 теряется смысл колонки.
    static let defaultLineWidth: CGFloat = 700
    static let widthRange: ClosedRange<CGFloat> = 420...1100
    static let widthStep: CGFloat = 60

    static func clampFont(_ value: CGFloat) -> CGFloat {
        min(fontRange.upperBound, max(fontRange.lowerBound, value))
    }

    static func clampWidth(_ value: CGFloat) -> CGFloat {
        min(widthRange.upperBound, max(widthRange.lowerBound, value))
    }

    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: Key.appearance) ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.appearance) }
    }

    /// Режим, в котором открываются следующие окна. Каждое окно дальше живёт
    /// своим: одну заметку читают, соседнюю правят.
    static var preview: Bool {
        get { UserDefaults.standard.bool(forKey: Key.preview) }
        set { UserDefaults.standard.set(newValue, forKey: Key.preview) }
    }

    static var fontSize: CGFloat {
        get { stored(Key.fontSize, default: defaultFontSize) }
        set { UserDefaults.standard.set(Double(newValue), forKey: Key.fontSize) }
    }

    static var lineWidth: CGFloat {
        get { stored(Key.lineWidth, default: defaultLineWidth) }
        set { UserDefaults.standard.set(Double(newValue), forKey: Key.lineWidth) }
    }

    /// UserDefaults отдаёт 0 и для «ключа нет», и для записанного нуля.
    /// Ноль тут невозможен — оба значения ограничены снизу, — так что
    /// трактуем его как отсутствие.
    private static func stored(_ key: String, default fallback: CGFloat) -> CGFloat {
        let value = UserDefaults.standard.double(forKey: key)
        return value == 0 ? fallback : CGFloat(value)
    }
}
