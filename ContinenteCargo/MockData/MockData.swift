//
//  MockData.swift
//  ContinenteCargo
//
//  Sample data used until the real API is connected.
//  18 active shipments distributed to match the executive summary:
//  7 en tránsito · 4 en origen · 5 próximos a arribar · 2 requieren atención.
//

import Foundation

enum MockData {

    // MARK: - Date helpers

    private static func days(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: value, to: Date()) ?? Date()
    }

    private static func hours(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: value, to: Date()) ?? Date()
    }

    private static func minutes(_ value: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: value, to: Date()) ?? Date()
    }

    // MARK: - Timeline factory

    /// Builds a plausible maritime timeline given the current status.
    /// `seed` staggers dates/times so demo events don't all share the same timestamp.
    private static func timeline(for status: ShipmentStatus,
                                 origin: String,
                                 destination: String,
                                 seed: Int = 0) -> [TrackingEvent] {
        // Shadow the file-level helper: shift each shipment's schedule by a
        // seed-dependent number of hours for realistic-looking variety.
        func days(_ value: Int) -> Date {
            let hourShift = (seed * 7) % 24 - 10
            return Calendar.current.date(byAdding: .hour,
                                         value: value * 24 + hourShift,
                                         to: Date()) ?? Date()
        }
        switch status {
        case .atOrigin:
            return [
                TrackingEvent(title: "Booking confirmado", location: origin, date: days(-4), isCompleted: true, icon: "checkmark.circle.fill"),
                TrackingEvent(title: "Contenedor en patio", location: origin, date: days(-2), isCompleted: true, icon: "shippingbox.fill"),
                TrackingEvent(title: "Carga en puerto de origen", location: origin, date: days(-1), isCompleted: true, icon: "building.columns.fill"),
                TrackingEvent(title: "Zarpe (ETD)", location: origin, date: days(3), isCompleted: false, icon: "ferry.fill"),
                TrackingEvent(title: "Arribo (ETA)", location: destination, date: days(21), isCompleted: false, icon: "flag.checkered")
            ]
        case .active, .inTransit:
            return [
                TrackingEvent(title: "Contenedor cargado", location: origin, date: days(-12), isCompleted: true, icon: "shippingbox.fill"),
                TrackingEvent(title: "Zarpe confirmado", location: origin, date: days(-10), isCompleted: true, icon: "ferry.fill"),
                TrackingEvent(title: "En tránsito marítimo", location: "Océano Pacífico", date: days(-3), isCompleted: true, icon: "arrow.right.circle.fill"),
                TrackingEvent(title: "Arribo (ETA)", location: destination, date: days(6), isCompleted: false, icon: "flag.checkered"),
                TrackingEvent(title: "Liberación aduanal", location: destination, date: days(8), isCompleted: false, icon: "checkmark.seal.fill")
            ]
        case .arrivingSoon:
            return [
                TrackingEvent(title: "Zarpe confirmado", location: origin, date: days(-24), isCompleted: true, icon: "ferry.fill"),
                TrackingEvent(title: "Tránsito marítimo", location: "En ruta", date: days(-10), isCompleted: true, icon: "arrow.right.circle.fill"),
                TrackingEvent(title: "Aproximación a puerto", location: destination, date: days(-1), isCompleted: true, icon: "location.fill"),
                TrackingEvent(title: "Arribo (ETA)", location: destination, date: days(2), isCompleted: false, icon: "flag.checkered"),
                TrackingEvent(title: "Descarga programada", location: destination, date: days(3), isCompleted: false, icon: "arrow.down.circle.fill")
            ]
        case .needsAttention:
            return [
                TrackingEvent(title: "Zarpe confirmado", location: origin, date: days(-20), isCompleted: true, icon: "ferry.fill"),
                TrackingEvent(title: "Arribo a puerto", location: destination, date: days(-4), isCompleted: true, icon: "flag.checkered"),
                TrackingEvent(title: "Contenedor detenido", location: destination, date: days(-2), isCompleted: true, icon: "hand.raised.fill"),
                TrackingEvent(title: "Liberación aduanal", location: destination, date: days(4), isCompleted: false, icon: "checkmark.seal.fill")
            ]
        case .delivered:
            return [
                TrackingEvent(title: "Arribo a destino", location: destination, date: days(-6), isCompleted: true, icon: "flag.checkered"),
                TrackingEvent(title: "Entregado", location: destination, date: days(-2), isCompleted: true, icon: "checkmark.seal.fill")
            ]
        }
    }

    // MARK: - Shipments

    static let shipments: [Shipment] = {
        var result: [Shipment] = []

        // Route pool for variety.
        let routes: [(String, String, String, String, String, String)] = [
            ("Shanghái", "CNSHA", "Manzanillo", "MXZLO", "COSCO Shipping", "COSCO FORTUNE"),
            ("Ningbo", "CNNGB", "Lázaro Cárdenas", "MXLZC", "Maersk", "MAERSK SELETAR"),
            ("Busan", "KRPUS", "Long Beach", "USLGB", "HMM", "HMM ALGECIRAS"),
            ("Yantián", "CNYTN", "Los Ángeles", "USLAX", "ONE", "ONE APUS"),
            ("Rotterdam", "NLRTM", "Veracruz", "MXVER", "MSC", "MSC GÜLSÜN"),
            ("Hamburgo", "DEHAM", "Altamira", "MXATM", "Hapag-Lloyd", "BERLIN EXPRESS"),
            ("Singapur", "SGSIN", "Manzanillo", "MXZLO", "CMA CGM", "CMA CGM JACQUES"),
            ("Qingdao", "CNTAO", "Ensenada", "MXESE", "Evergreen", "EVER GIVEN"),
            ("Callao", "PECLL", "Manzanillo", "MXZLO", "Hapag-Lloyd", "GUAYAQUIL EXPRESS"),
            ("Kaohsiung", "TWKHH", "Long Beach", "USLGB", "Yang Ming", "YM WITNESS")
        ]

        func route(_ i: Int) -> (String, String, String, String, String, String) { routes[i % routes.count] }

        // Detail sections reused for richer shipments.
        let sampleDocs = [
            ShipmentDocument(name: "Bill of Lading", date: days(-9)),
            ShipmentDocument(name: "Factura comercial", date: days(-9)),
            ShipmentDocument(name: "Packing list", date: days(-8)),
            ShipmentDocument(name: "Certificado de origen", date: days(-7))
        ]
        let sampleCharges = [
            Charge(concept: "Flete marítimo", amount: 2450, currency: "USD"),
            Charge(concept: "THC destino", amount: 320, currency: "USD"),
            Charge(concept: "Despacho aduanal", amount: 480, currency: "USD")
        ]

        // Distribution: 7 inTransit, 4 atOrigin, 5 arrivingSoon, 2 needsAttention.
        let plan: [ShipmentStatus] = Array(repeating: .inTransit, count: 7)
            + Array(repeating: .atOrigin, count: 4)
            + Array(repeating: .arrivingSoon, count: 5)
            + Array(repeating: .needsAttention, count: 2)

        for (index, status) in plan.enumerated() {
            let r = route(index)
            let ref = String(format: "CC-2026-%04d", 401 + index)
            let hasBooking = !(status == .needsAttention && index == plan.count - 1) // one needsAttention has no booking
            let booking = hasBooking ? "BK\(72030 + index)" : nil
            let container = "TCLU\(String(format: "%07d", 4820011 + index * 137))"

            var incidents: [Incident] = []
            var freeRemaining = 7
            let freeTotal = 7

            if status == .needsAttention {
                if hasBooking {
                    incidents = [
                        Incident(title: "Contenedor detenido en aduana",
                                 detail: "Inspección física ordenada por la autoridad aduanera. En espera de liberación.",
                                 severity: .critical, date: days(-2)),
                        Incident(title: "Días libres por vencer",
                                 detail: "Quedan 2 días libres de almacenaje antes de generar cargos por demora.",
                                 severity: .warning, date: days(-1))
                    ]
                    freeRemaining = 2
                } else {
                    incidents = [
                        Incident(title: "Embarque sin booking asignado",
                                 detail: "La naviera aún no confirma el booking. Se requiere seguimiento inmediato.",
                                 severity: .critical, date: hours(-6))
                    ]
                    freeRemaining = 7
                }
            }

            let shipment = Shipment(
                reference: ref,
                bl: "BL\(String(format: "%08d", 30045000 + index * 311))",
                booking: booking,
                container: container,
                transportMode: index % 7 == 0 ? .air : .maritime,
                status: status,
                originName: r.0,
                originCode: r.1,
                destinationName: r.2,
                destinationCode: r.3,
                etd: status == .atOrigin ? days(3) : days(-10 - index),
                eta: {
                    switch status {
                    case .atOrigin: return days(24)
                    case .active: return days(6 + index % 5)
                    case .inTransit: return days(6 + index % 5)
                    case .arrivingSoon: return days(1 + index % 3)
                    case .needsAttention: return days(4)
                    case .delivered: return days(-2)
                    }
                }(),
                lastUpdate: status == .needsAttention && !hasBooking ? days(-2) : minutes(-(20 + index * 7)),
                carrier: r.4,
                vessel: r.5,
                isInsured: index % 4 != 2,
                timeline: timeline(for: status, origin: r.0, destination: r.2, seed: index),
                documents: sampleDocs,
                incidents: incidents,
                charges: sampleCharges,
                freeDaysTotal: freeTotal,
                freeDaysRemaining: freeRemaining
            )
            result.append(shipment)
        }
        return result
    }()

    // MARK: - Alerts

    static let alerts: [LogisticAlert] = {
        // Anchor alerts to the two "needs attention" shipments plus a few others.
        let attention = shipments.filter { $0.status == .needsAttention }
        let heldShipment = attention.first { $0.booking != nil }
        let noBookingShipment = attention.first { $0.booking == nil }
        let transit = shipments.filter { $0.status == .inTransit }
        let arriving = shipments.filter { $0.status == .arrivingSoon }

        var result: [LogisticAlert] = []

        if let s = heldShipment {
            result.append(LogisticAlert(type: .containerHeld, severity: .critical,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "Contenedor \(s.container) detenido en aduana de \(s.destinationName).",
                                        detectedAt: hours(-3)))
            result.append(LogisticAlert(type: .freeDaysExpiring, severity: .warning,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "Quedan \(s.freeDaysRemaining) días libres antes de generar cargos por demora.",
                                        detectedAt: hours(-20)))
        }
        if let s = noBookingShipment {
            result.append(LogisticAlert(type: .noBooking, severity: .critical,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "El embarque no tiene booking confirmado por la naviera.",
                                        detectedAt: hours(-6)))
        }
        if let s = transit.first {
            result.append(LogisticAlert(type: .etaDelay, severity: .warning,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "La ETA se recorrió 2 días por congestión portuaria en \(s.destinationName).",
                                        detectedAt: hours(-30)))
        }
        if transit.count > 2 {
            let s = transit[2]
            result.append(LogisticAlert(type: .extraCharges, severity: .warning,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "Se detectaron cargos extras por reestiba: USD 340.",
                                        detectedAt: days(-2)))
        }
        if let s = arriving.first {
            result.append(LogisticAlert(type: .etdDelay, severity: .informative,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "Ajuste menor en el itinerario de la naviera. Sin impacto en ETA.",
                                        detectedAt: days(-1)))
        }
        if arriving.count > 1 {
            let s = arriving[1]
            result.append(LogisticAlert(type: .bookingCancelled, severity: .critical,
                                        shipmentReference: s.reference, shipmentID: s.id,
                                        message: "La naviera canceló el booking original. Rebooking en proceso.",
                                        detectedAt: hours(-12)))
        }
        return result
    }()
}
