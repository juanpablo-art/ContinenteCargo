//
//  User.swift
//  ContinenteCargo
//

import Foundation

/// Authenticated client user.
struct User: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let email: String
    let company: String

    /// Initials for the avatar, e.g. "Juan Pablo" -> "JP".
    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
