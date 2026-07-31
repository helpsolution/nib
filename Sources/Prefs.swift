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
    static var appearance: Appearance {
        get { Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appearance") }
    }

    static var fontSize: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "fontSize")
            return v == 0 ? 17 : CGFloat(v)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "fontSize") }
    }
    static var lineWidth: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "lineWidth")
            return v == 0 ? 700 : CGFloat(v)
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "lineWidth") }
    }
}
