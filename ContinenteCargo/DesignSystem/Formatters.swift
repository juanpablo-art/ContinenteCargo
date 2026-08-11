//
//  Formatters.swift
//  ContinenteCargo
//
//  Shared, reused formatters. Instantiating formatters is expensive,
//  so we keep single static instances.
//

import Foundation

enum CCFormat {

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.unitsStyle = .full
        return f
    }()

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "d MMM"
        return f
    }()

    private static let namedRelative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.unitsStyle = .full
        f.dateTimeStyle = .named
        return f
    }()

    private static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "Hace 40 minutos", "Hace 2 días", etc.
    static func relativeSince(_ date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date()).capitalizedFirst
    }

    /// "8 jul 2026"
    static func date(_ date: Date) -> String { shortDate.string(from: date) }

    /// "8 jul"
    static func shortDay(_ date: Date) -> String { dayMonth.string(from: date) }

    /// "Mañana", "Hoy", "En 3 días" — named relative day.
    static func relativeDay(_ date: Date) -> String {
        namedRelative.localizedString(for: date, relativeTo: Date()).capitalizedFirst
    }

    /// "09:00"
    static func time(_ date: Date) -> String { timeOnly.string(from: date) }
}

extension String {
    /// Capitalizes only the first character, leaving the rest untouched.
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
