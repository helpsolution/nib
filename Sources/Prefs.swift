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
    enum Key {
        static let fontSize = "fontSize"
        static let lineWidth = "lineWidth"
        static let appearance = "appearance"
    }

    /// Кегль: ниже 11 текст нечитаем, выше 32 в колонку помещается пара слов.
    static let defaultFontSize: CGFloat = 17
    static let fontRange: ClosedRange<CGFloat> = 11...32

    /// Ширина колонки: ниже 420 строка рвётся на середине фразы,
    /// выше 1100 теряется смысл колонки.
    static let defaultLineWidth: CGFloat = 700
    static let widthRange: ClosedRange<CGFloat> = 420...1100
    static let widthStep: CGFloat = 60

    static func clampFont(_ value: CGFloat) -> CGFloat {
        min(max(value, fontRange.lowerBound), fontRange.upperBound)
    }

    static func clampWidth(_ value: CGFloat) -> CGFloat {
        min(max(value, widthRange.lowerBound), widthRange.upperBound)
    }

    static var fontSize: CGFloat {
        get { stored(Key.fontSize, default: defaultFontSize) }
        set { UserDefaults.standard.set(Double(newValue), forKey: Key.fontSize) }
    }

    static var lineWidth: CGFloat {
        get { stored(Key.lineWidth, default: defaultLineWidth) }
        set { UserDefaults.standard.set(Double(newValue), forKey: Key.lineWidth) }
    }

    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: Key.appearance) ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.appearance) }
    }

    /// UserDefaults отдаёт 0 и для «не задано», и для нуля. Ноль тут невозможен —
    /// оба значения ограничены снизу, — так что трактуем его как отсутствие.
    private static func stored(_ key: String, default fallback: CGFloat) -> CGFloat {
        let value = UserDefaults.standard.double(forKey: key)
        return value == 0 ? fallback : CGFloat(value)
    }
}
