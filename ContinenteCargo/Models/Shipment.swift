//
//  Shipment.swift
//  ContinenteCargo
//
//  Core domain models. All are value types and Identifiable so they
//  slot cleanly into SwiftUI lists and are easy to decode from an API later.
//

import Foundation

/// A single logistics shipment / embarque.
struct Shipment: Identifiable, Hashable {
    let id: UUID
    /// The numeric ID used by the Continente API (nil for local mock data).
    let shippingId: Int?
    /// Client-facing reference, e.g. "CC-2026-0451".
    let reference: String
    let bl: String
    let booking: String?
    let container: String
    let transportMode: TransportMode
    var status: ShipmentStatus

    // Route
    let originName: String
    let originCode: String
    let destinationName: String
    let destinationCode: String

    // Dates
    let etd: Date
    let eta: Date
    var lastUpdate: Date

    // Carrier
    let carrier: String
    let vessel: String

    /// Whether the cargo is covered by insurance.
    let isInsured: Bool

    // Detail sections
    var timeline: [TrackingEvent]
    var documents: [ShipmentDocument]
    var incidents: [Incident]
    var charges: [Charge]
    var freeDaysTotal: Int
    var freeDaysRemaining: Int

    /// Route summary, e.g. "MXZLO → USLAX".
    var routeCodes: String { "\(originCode) → \(destinationCode)" }

    /// Route with city names, e.g. "Manzanillo → Los Ángeles".
    var routeNames: String { "\(originName) → \(destinationName)" }

    /// Whether the shipment needs the client's attention.
    var requiresAttention: Bool { status == .needsAttention }

    /// Convenience initializer with sensible defaults for optional detail data.
    init(
        id: UUID = UUID(),
        shippingId: Int? = nil,
        reference: String,
        bl: String,
        booking: String?,
        container: String,
        transportMode: TransportMode = .maritime,
        status: ShipmentStatus,
        originName: String,
        originCode: String,
        destinationName: String,
        destinationCode: String,
        etd: Date,
        eta: Date,
        lastUpdate: Date,
        carrier: String,
        vessel: String,
        isInsured: Bool = true,
        timeline: [TrackingEvent] = [],
        documents: [ShipmentDocument] = [],
        incidents: [Incident] = [],
        charges: [Charge] = [],
        freeDaysTotal: Int = 0,
        freeDaysRemaining: Int = 0
    ) {
        self.id = id
        self.shippingId = shippingId
        self.reference = reference
        self.bl = bl
        self.booking = booking
        self.container = container
        self.transportMode = transportMode
        self.status = status
        self.originName = originName
        self.originCode = originCode
        self.destinationName = destinationName
        self.destinationCode = destinationCode
        self.etd = etd
        self.eta = eta
        self.lastUpdate = lastUpdate
        self.carrier = carrier
        self.vessel = vessel
        self.isInsured = isInsured
        self.timeline = timeline
        self.documents = documents
        self.incidents = incidents
        self.charges = charges
        self.freeDaysTotal = freeDaysTotal
        self.freeDaysRemaining = freeDaysRemaining
    }
}

/// A milestone in the shipment's logistic timeline.
struct TrackingEvent: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let location: String
    let date: Date
    /// Completed milestones are drawn filled; future ones are hollow.
    let isCompleted: Bool
    let icon: String
}

/// A document attached to a shipment (BL, factura, packing list, etc.).
struct ShipmentDocument: Identifiable, Hashable {
    let id: UUID = UUID()
    let name: String
    let date: Date?
    /// S3 object path from the API (e.g. "Shipping/21119/Master/file.pdf").
    let s3Path: String?
    let fileExtension: String?
    /// API document category (e.g. "policy", "general"), when provided.
    let documentType: String?

    init(name: String, date: Date?, s3Path: String? = nil,
         fileExtension: String? = nil, documentType: String? = nil) {
        self.name = name
        self.date = date
        self.s3Path = s3Path
        self.fileExtension = fileExtension
        self.documentType = documentType
    }

    /// True when this document is an insurance policy.
    var isPolicy: Bool {
        let type = (documentType ?? "").lowercased()
        if type.contains("poliz") || type.contains("policy") || type.contains("segur") {
            return true
        }
        let keywords = ["poliz", "segur", "policy", "insurance"]
        let haystack = (name + (s3Path ?? "")).lowercased()
        return keywords.contains { haystack.contains($0) }
    }

    /// Filename with extension for the temp file cache.
    var displayFileName: String {
        guard let ext = fileExtension, !ext.isEmpty else { return name }
        let dotExt = ".\(ext)"
        return name.hasSuffix(dotExt) ? name : name + dotExt
    }
}

/// A logged incident on the shipment.
struct Incident: Identifiable, Hashable {
    let id: UUID = UUID()
    let title: String
    let detail: String
    let severity: AlertSeverity
    let date: Date
}

/// A charge / cost line item.
struct Charge: Identifiable, Hashable {
    let id: UUID = UUID()
    let concept: String
    let amount: Double
    let currency: String

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }
}

/// A detected logistic alert tied to a shipment.
struct LogisticAlert: Identifiable, Hashable {
    let id: UUID = UUID()
    let type: AlertType
    let severity: AlertSeverity
    /// Reference of the related shipment (matches `Shipment.reference`).
    let shipmentReference: String
    /// Related shipment id, so we can navigate to its detail.
    let shipmentID: UUID
    let message: String
    let detectedAt: Date
}
