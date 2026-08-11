//
//  AlertsViewModel.swift
//  ContinenteCargo
//

import SwiftUI
import Observation

/// Filter options for the alerts list — mirrors the Embarques filter pattern.
enum AlertFilter: String, CaseIterable, Identifiable {
    case all
    case critical
    case warning
    case informative

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .critical: return "Críticas"
        case .warning: return "Advertencias"
        case .informative: return "Informativas"
        }
    }

    /// The severity this filter maps to (nil for `.all`).
    var severity: AlertSeverity? {
        switch self {
        case .all: return nil
        case .critical: return .critical
        case .warning: return .warning
        case .informative: return .informative
        }
    }
}

@Observable
@MainActor
final class AlertsViewModel {
    private(set) var alerts: [ShippingAlert] = []
    private(set) var counts: AlertCounts?
    private(set) var meta: APIMeta?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    var filter: AlertFilter = .all
    var searchText: String = ""

    private let apiService: AlertsServicing
    private let alertCountsService: AlertCountsServicing
    private let pageSize = 20
    private var idToken: String?
    private var clientID: Int?
    private var searchTask: Task<Void, Never>?

    init(apiService: AlertsServicing? = nil,
         alertCountsService: AlertCountsServicing? = nil) {
        self.apiService = apiService ?? ContinenteAPIService.shared
        self.alertCountsService = alertCountsService ?? ContinenteAPIService.shared
    }

    /// Severity filter applied client-side; text search is server-side.
    var filteredAlerts: [ShippingAlert] {
        guard let severity = filter.severity else { return alerts }
        return alerts.filter { $0.severity == severity }
    }

    /// Tab counters: "Todas" uses the API total; severity tabs count from loaded items.
    func count(for filter: AlertFilter) -> Int {
        switch filter {
        case .all:
            return counts?.all ?? alerts.count
        case .critical:
            return alerts.filter { $0.severity == .critical }.count
        case .warning:
            return alerts.filter { $0.severity == .warning }.count
        case .informative:
            return alerts.filter { $0.severity == .informative }.count
        }
    }

    func load(idToken: String?, clientID: Int?, force: Bool = false) async {
        guard !hasLoaded || force else { return }
        self.idToken = idToken
        self.clientID = clientID
        isLoading = true
        defer { isLoading = false }

        do {
            async let countsTask = alertCountsService.fetchAlertCounts(idToken: idToken, search: nil)
            async let alertsTask: ShippingAlertsPage = try apiService.fetchShippingAlerts(
                idToken: idToken, clientID: clientID, search: nil, pageSize: pageSize, pageNumber: 1)
            let (realCounts, page) = try await (countsTask, alertsTask)
            alerts = page.alerts
            counts = realCounts
            meta = page.meta
            hasLoaded = true
        } catch {
            print("🌐 [Alerts] API error: \(error.localizedDescription)")
            alerts = []
            counts = nil
            meta = nil
        }
    }

    /// Dispara una búsqueda server-side con debounce de 400 ms.
    func onSearchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            await executeSearch()
        }
    }

    private func executeSearch() async {
        isLoading = true
        defer { isLoading = false }
        let search = searchText.isEmpty ? nil : searchText

        async let countsTask = alertCountsService.fetchAlertCounts(idToken: idToken, search: search)
        async let alertsTask: ShippingAlertsPage = try apiService.fetchShippingAlerts(
            idToken: idToken, clientID: clientID, search: search, pageSize: pageSize, pageNumber: 1)

        if let (newCounts, page) = try? await (countsTask, alertsTask) {
            alerts = page.alerts
            counts = newCounts
            meta = page.meta
        }
    }

    func loadMoreIfNeeded(after alert: ShippingAlert) async {
        guard !isLoadingMore,
              alert.id == alerts.last?.id,
              let meta, meta.hasNextPage == true else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = (meta.currentPage ?? 1) + 1
        let search = searchText.isEmpty ? nil : searchText
        if let page = try? await apiService.fetchShippingAlerts(
            idToken: idToken, clientID: clientID, search: search, pageSize: pageSize, pageNumber: nextPage) {
            alerts += page.alerts
            self.meta = page.meta
            if let newCounts = page.counts { counts = newCounts }
        }
    }
}
