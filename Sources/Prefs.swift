// Настройки, живущие в UserDefaults.

import AppKit

enum Prefs {
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
