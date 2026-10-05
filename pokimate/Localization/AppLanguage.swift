import Foundation

/// Supported UI languages. Add a new case + String Catalog entries to extend.
enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case hungarian = "hu"

    var id: String { rawValue }

    /// BCP-47 / `.lproj` code used by Foundation localization.
    var localeIdentifier: String { rawValue }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// Name shown in the language picker (always in that language).
    var displayName: String {
        switch self {
        case .english: return "English"
        case .hungarian: return "Magyar"
        }
    }

    /// Default when the user has never chosen a language.
    static var deviceDefault: AppLanguage {
        let identifiers = Locale.preferredLanguages
        if identifiers.contains(where: {
            Locale(identifier: $0).language.languageCode?.identifier == "hu"
        }) {
            return .hungarian
        }
        if Locale.current.language.languageCode?.identifier == "hu" {
            return .hungarian
        }
        return .english
    }
}
