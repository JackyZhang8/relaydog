import Foundation
import RelayDogCore

public enum RelayDogResolvedLanguage: Equatable, Sendable {
    case zh
    case en
}

public struct RelayDogLanguageOption: Equatable, Sendable, Identifiable {
    public var id: RelayDogLanguage {
        preference
    }

    public var preference: RelayDogLanguage
    public var title: String
    public var isSelected: Bool

    public init(preference: RelayDogLanguage, title: String, isSelected: Bool) {
        self.preference = preference
        self.title = title
        self.isSelected = isSelected
    }
}

public func t(_ zh: String, _ en: String, language: RelayDogResolvedLanguage) -> String {
    switch language {
    case .zh:
        return zh
    case .en:
        return en
    }
}

public extension RelayDogLanguage {
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> RelayDogResolvedLanguage {
        switch self {
        case .zh:
            return .zh
        case .en:
            return .en
        case .system:
            let preferred = preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("zh") ? .zh : .en
        }
    }

    var optionTitle: String {
        switch self {
        case .system:
            return "跟随系统 / Follow System"
        case .zh:
            return "中文"
        case .en:
            return "English"
        }
    }
}
