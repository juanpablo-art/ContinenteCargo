//
//  Enums.swift
//  ContinenteCargo
//
//  Shared domain enums used across shipments, alerts and the UI.
//

import SwiftUI

/// High-level operational status of a shipment. Doubles as the list filter set.
enum ShipmentStatus: String, CaseIterable, Identifiable, Codable {
    case atOrigin
    case active
    case inTransit
    case arrivingSoon
    case needsAttention
    case delivered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atOrigin: return "En origen"
        case .active: return "Activo"
        case .inTransit: return "En tránsito"
        case .arrivingSoon: return "Próximo a arribar"
        case .needsAttention: return "Requiere atención"
        case .delivered: return "Entregado"
        }
    }

    /// Compact label for the status badge pill.
    var badgeTitle: String {
        switch self {
        case .atOrigin: return "En origen"
        case .active: return "Activo"
        case .inTransit: return "En tránsito"
        case .arrivingSoon: return "Próx. arribo"
        case .needsAttention: return "Atención"
        case .delivered: return "Entregado"
        }
    }

    var color: Color {
        switch self {
        case .atOrigin: return CCColor.orange
        case .active: return CCColor.green
        case .inTransit: return CCColor.green
        case .arrivingSoon: return CCColor.actionBlue
        case .needsAttention: return CCColor.red
        case .delivered: return CCColor.green
        }
    }

    var icon: String {
        switch self {
        case .atOrigin: return "shippingbox.fill"
        case .active: return "arrow.right.circle.fill"
        case .inTransit: return "arrow.right.circle.fill"
        case .arrivingSoon: return "clock.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .delivered: return "checkmark.seal.fill"
        }
    }
}

/// Transport service used for the shipment.
enum TransportMode: String, Codable {
    case maritime
    case air
    case land

    var title: String {
        switch self {
        case .maritime: return "Marítimo"
        case .air: return "Aéreo"
        case .land: return "Terrestre"
        }
    }

    var icon: String {
        switch self {
        case .maritime: return "ferry.fill"
        case .air: return "airplane"
        case .land: return "truck.box.fill"
        }
    }
}

/// Severity level for logistic alerts.
enum AlertSeverity: String, Codable {
    case critical
    case warning
    case informative

    var title: String {
        switch self {
        case .critical: return "Crítica"
        case .warning: return "Advertencia"
        case .informative: return "Informativa"
        }
    }

    var color: Color {
        switch self {
        case .critical: return CCColor.red
        case .warning: return CCColor.orange
        case .informative: return CCColor.actionBlue
        }
    }

    /// Sort weight — critical first.
    var priority: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .informative: return 2
        }
    }
}

/// The category of problem detected on a shipment.
enum AlertType: String, Codable {
    case containerHeld
    case extraCharges
    case noBooking
    case bookingCancelled
    case etdDelay
    case etaDelay
    case freeDaysExpiring

    var title: String {
        switch self {
        case .containerHeld: return "Contenedor detenido"
        case .extraCharges: return "Cargos extras detectados"
        case .noBooking: return "Embarque sin booking"
        case .bookingCancelled: return "Booking cancelado"
        case .etdDelay: return "Retraso de ETD"
        case .etaDelay: return "Retraso de ETA"
        case .freeDaysExpiring: return "Días libres por vencer"
        }
    }

    var icon: String {
        switch self {
        case .containerHeld: return "hand.raised.fill"
        case .extraCharges: return "dollarsign.circle.fill"
        case .noBooking: return "doc.badge.ellipsis"
        case .bookingCancelled: return "xmark.octagon.fill"
        case .etdDelay: return "clock.badge.exclamationmark.fill"
        case .etaDelay: return "clock.badge.exclamationmark.fill"
        case .freeDaysExpiring: return "calendar.badge.exclamationmark"
        }
    }
}

