import Foundation
import Combine

/// Runtime language preference + String Catalog lookups (in-app switching).
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let defaultsKey = "settings.appLanguage"

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
            // Drop cached bundles when the active language changes.
            bundleCache.removeAll()
        }
    }

    var locale: Locale { language.locale }

    /// Cached `.lproj` bundles so lookups stay cheap and reliable at runtime.
    private var bundleCache: [String: Bundle] = [:]

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .deviceDefault
        }
    }

    /// Lookup a String Catalog key from the matching `.lproj` bundle.
    /// Prefer explicit bundle paths over `String(localized:locale:)` — the latter
    /// often ignores in-app locale overrides and keeps the system language.
    func t(_ key: String) -> String {
        let value = stringsBundle.localizedString(forKey: key, value: nil, table: "Localizable")
        // If the key is missing, Foundation returns the key itself.
        return value
    }

    /// `String(format:)` with the active locale.
    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }

    private var stringsBundle: Bundle {
        let code = language.localeIdentifier
        if let cached = bundleCache[code] {
            return cached
        }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[code] = bundle
            return bundle
        }
        // Fallback: English catalog, then main bundle.
        if code != AppLanguage.english.rawValue,
           let path = Bundle.main.path(forResource: AppLanguage.english.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[code] = bundle
            return bundle
        }
        return .main
    }
}

/// Shorthand for non-view / engine call sites.
enum L10n {
    @MainActor
    static func t(_ key: String) -> String {
        LocalizationManager.shared.t(key)
    }

    @MainActor
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(
            format: LocalizationManager.shared.t(key),
            locale: LocalizationManager.shared.locale,
            arguments: args
        )
    }
}
