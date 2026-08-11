//
//  HomeViewModel.swift
//  ContinenteCargo
//
//  Executive summary built from three v1 endpoints:
//  - GET /api/v1/shipments/count            → counts by status
//  - GET /api/v1/shipments/alerts           → alertas críticas (severity == critical)
//  - GET /api/v1/shipments/upcoming-events  → próximos eventos
//

import SwiftUI
import Observation

/// Aggregated counters for the executive summary.
struct OperationSummary {
    var active: Int = 0
    var inTransit: Int = 0
    var atOrigin: Int = 0
    var arrivingSoon: Int = 0
    var needsAttention: Int = 0
}

/// An upcoming logistic event shown in the Home card.
struct UpcomingEvent: Identifiable {
    let id = UUID()
    /// API shipping ID — used to navigate to the shipment detail.
    let shippingId: Int?
    /// Folio / reference code shown as the primary identifier.
    let refCode: String
    /// Human-readable event description (e.g. "Arrival Confirmation").
    let eventDescription: String
    /// Origin port code.
    let pol: String?
    /// Destination port code.
    let pod: String?
    /// Days until the event (from API).
    let daysUntilEvent: Int?
    /// Estimated date of the event.
    let eventDate: Date
    /// ETD if the API returns it.
    let etd: Date?
    /// ETA if the API returns it.
    let eta: Date?
    let icon: String
}

@Observable
@MainActor
final class HomeViewModel {
    private(set) var summary = OperationSummary()
    private(set) var criticalShippingAlerts: [ShippingAlert] = []
    private(set) var criticalCount = 0
    private(set) var upcomingEvents: [UpcomingEvent] = []
    private(set) var lastGlobalUpdate: Date = Date()
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private let countsService: ShipmentCountsServicing
    private let alertsService: AlertsServicing
    private let eventsService: UpcomingEventsServicing

    init(countsService: ShipmentCountsServicing? = nil,
         alertsService: AlertsServicing? = nil,
         eventsService: UpcomingEventsServicing? = nil) {
        self.countsService = countsService ?? ContinenteAPIService.shared
        self.alertsService = alertsService ?? ContinenteAPIService.shared
        self.eventsService = eventsService ?? ContinenteAPIService.shared
    }

    func load(idToken: String?, clientID: Int?, force: Bool = false) async {
        guard !hasLoaded || force else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let cs = countsService
            let als = alertsService
            let es = eventsService
            async let countsTask = cs.fetchShipmentCounts(idToken: idToken)
            async let alertsTask = als.fetchShippingAlerts(idToken: idToken, clientID: clientID,
                                                           search: nil, pageSize: 50, pageNumber: 1)
            async let eventsTask = es.fetchUpcomingEvents(idToken: idToken, pageSize: 10)
            let (counts, alertsPage, apiEvents) = try await (countsTask, alertsTask, eventsTask)
            print("🌐 [Home] Shipment counts: \(counts)")
            print("🌐 [Home] Critical alerts: \(alertsPage.alerts.filter { $0.severity == .critical }.count)")
            print("🌐 [Home] Upcoming events: \(apiEvents.count)")
            apply(counts: counts, alertsPage: alertsPage, events: apiEvents)
            hasLoaded = true
        } catch {
            print("🌐 [Home] API error: \(error.localizedDescription)")
            summary = OperationSummary()
            criticalShippingAlerts = []
            criticalCount = 0
            upcomingEvents = []
        }
    }

    // MARK: - Real data

    private func apply(counts: ShipmentCounts, alertsPage: ShippingAlertsPage, events: [ShipmentUpcomingEventItem]) {
        summary = OperationSummary(
            active: counts.active,
            inTransit: counts.inTransit,
            atOrigin: counts.inOrigin,
            arrivingSoon: counts.soonToArrive,
            needsAttention: counts.needAttention
        )

        let criticals = alertsPage.alerts.filter { $0.severity == .critical }
        criticalShippingAlerts = Array(criticals.prefix(3))
        criticalCount = criticals.count

        upcomingEvents = events.compactMap { e -> UpcomingEvent? in
            guard let date = e.eventDate else { return nil }
            return UpcomingEvent(
                shippingId: e.shippingId,
                refCode: e.refCode ?? e.refNumber ?? "—",
                eventDescription: e.eventDescription ?? e.event ?? "Próximo evento",
                pol: e.pol,
                pod: e.pod,
                daysUntilEvent: e.daysUntilEvent,
                eventDate: date,
                etd: e.etd,
                eta: e.eta,
                icon: Self.icon(for: e.transportation)
            )
        }

        lastGlobalUpdate = Date()
    }

    private static func icon(for mode: TransportMode) -> String {
        switch mode {
        case .air:      return "airplane"
        case .land:     return "truck.box.fill"
        case .maritime: return "ferry.fill"
        }
    }

    private static func icon(for transportation: String?) -> String {
        let t = (transportation ?? "").lowercased()
        if t.contains("aér") || t.contains("aer") || t.contains("air") { return "airplane" }
        if t.contains("terr") || t.contains("land") { return "truck.box.fill" }
        return "ferry.fill"
    }
}
