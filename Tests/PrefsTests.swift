// Настройки. Ценность здесь одна: чистый UserDefaults должен давать осмысленные
// значения, а не ноль. Кегль 0 — это невидимый текст, ширина колонки 0 — схлопнутая
// в нитку страница; обе ошибки выглядят как «приложение сломалось при первом запуске».

import AppKit

func runPrefsTests() {

    let keys = ["appearance", "fontSize", "lineWidth"]
    let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
    defer {
        for (key, value) in zip(keys, saved) {
            UserDefaults.standard.set(value, forKey: key)
        }
    }
    func reset() { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }

    Check.suite("Настройки: значения по умолчанию") {
        reset()
        Check.close(Prefs.fontSize, 17, "кегль по умолчанию")
        Check.close(Prefs.lineWidth, 700, "ширина колонки по умолчанию")
        Check.equal(Prefs.appearance, .system, "оформление по умолчанию — системное")
    }

    Check.suite("Настройки: сохранение и чтение") {
        reset()
        Prefs.fontSize = 24
        Check.close(Prefs.fontSize, 24, "кегль переживает запись")
        Prefs.lineWidth = 900
        Check.close(Prefs.lineWidth, 900, "ширина переживает запись")
        Prefs.appearance = .dark
        Check.equal(Prefs.appearance, .dark, "оформление переживает запись")

        // Ноль в хранилище неотличим от «ключа нет»: double(forKey:) в обоих
        // случаях отдаёт 0. Значит и трактоваться должен одинаково — как дефолт.
        UserDefaults.standard.set(0.0, forKey: "fontSize")
        Check.close(Prefs.fontSize, 17, "нулевой кегль трактуется как дефолт, а не как невидимый текст")
        UserDefaults.standard.set(0.0, forKey: "lineWidth")
        Check.close(Prefs.lineWidth, 700, "нулевая ширина трактуется как дефолт")

        UserDefaults.standard.set("марсианское", forKey: "appearance")
        Check.equal(Prefs.appearance, .system, "неизвестное оформление откатывается к системному")
        reset()
    }

    // Границы кегля и ширины зашиты литералами в приватные методы EditorScreen
    // (11...32 и 420...1100) и снаружи недоступны. Проверяем то, что доступно:
    // дефолты обязаны лежать внутри этих границ, иначе первый же Cmd+«+» дёрнет
    // значение скачком к краю диапазона.
    Check.suite("Настройки: дефолты внутри диапазонов масштаба") {
        reset()
        Check.ok((11...32).contains(Prefs.fontSize), "кегль по умолчанию внутри диапазона")
        Check.ok((420...1100).contains(Prefs.lineWidth), "ширина по умолчанию внутри диапазона")
    }
}
