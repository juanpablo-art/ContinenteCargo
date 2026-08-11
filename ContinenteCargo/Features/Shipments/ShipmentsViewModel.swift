//
//  ShipmentsViewModel.swift
//  ContinenteCargo
//

import SwiftUI
import Observation

/// Filter options for the shipments list.
enum ShipmentFilter: String, CaseIterable, Identifiable {
    case all
    case inTransit
    case active
    case atOrigin
    case arrivingSoon
    case needsAttention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .inTransit: return "En tránsito"
        case .active: return "Activos"
        case .atOrigin: return "En origen"
        case .arrivingSoon: return "Próximos a arribar"
        case .needsAttention: return "Requiere atención"
        }
    }

    /// The shipment status this filter maps to (nil for `.all`).
    var status: ShipmentStatus? {
        switch self {
        case .all: return nil
        case .inTransit: return .inTransit
        case .active: return .active
        case .atOrigin: return .atOrigin
        case .arrivingSoon: return .arrivingSoon
        case .needsAttention: return .needsAttention
        }
    }
}

@Observable
@MainActor
final class ShipmentsViewModel {
    var searchText: String = ""
    var filter: ShipmentFilter = .all
    private(set) var shipments: [Shipment] = []
    private(set) var shipmentCounts: ShipmentCounts?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var hasNextPage = false

    private var currentPage = 1
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    // Credenciales guardadas para usarlas en búsqueda y paginación.
    private var storedIdToken: String?
    private var storedClientID: Int?

    private let listService: ShipmentListServicing
    private let countsService: ShipmentCountsServicing

    init(listService: ShipmentListServicing? = nil,
         countsService: ShipmentCountsServicing? = nil) {
        self.listService = listService ?? ContinenteAPIService.shared
        self.countsService = countsService ?? ContinenteAPIService.shared
    }

    /// Contadores de los tabs — usa totales del API cuando no hay búsqueda activa.
    func count(for filter: ShipmentFilter) -> Int {
        guard searchText.isEmpty, let counts = shipmentCounts else {
            guard let status = filter.status else { return shipments.count }
            return shipments.filter { $0.status == status }.count
        }
        switch filter {
        case .all:            return counts.total
        case .inTransit:      return counts.inTransit
        case .active:         return counts.active
        case .atOrigin:       return counts.inOrigin
        case .arrivingSoon:   return counts.soonToArrive
        case .needsAttention: return counts.needAttention
        }
    }

    /// El servidor ya filtra por texto; aquí solo aplicamos el filtro de status.
    var filteredShipments: [Shipment] {
        guard let status = filter.status else { return shipments }
        return shipments.filter { $0.status == status }
    }

    func load(idToken: String? = nil, clientID: Int? = nil, force: Bool = false) async {
        storedIdToken = idToken
        storedClientID = clientID
        guard !hasLoaded || force else { return }
        isLoading = true
        currentPage = 1
        defer { isLoading = false }
        do {
            async let listTask = listService.fetchShipmentList(
                idToken: idToken, clientID: clientID, search: nil, page: 1, pageSize: pageSize)
            async let countsTask = countsService.fetchShipmentCounts(idToken: idToken)
            let (result, counts) = try await (listTask, countsTask)
            shipments = result.shipments
            shipmentCounts = counts
            hasNextPage = result.hasNextPage
            hasLoaded = true
        } catch {
            print("🌐 [Shipments] API error: \(error.localizedDescription)")
            shipments = []
            shipmentCounts = nil
            hasNextPage = false
        }
    }

    func loadNextPage() async {
        guard hasNextPage, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = currentPage + 1
        let search = searchText.isEmpty ? nil : searchText
        do {
            let result = try await listService.fetchShipmentList(
                idToken: storedIdToken, clientID: storedClientID, search: search, page: nextPage, pageSize: pageSize)
            shipments.append(contentsOf: result.shipments)
            hasNextPage = result.hasNextPage
            currentPage = nextPage
        } catch {
            // falla silenciosamente — los items cargados se mantienen
        }
    }

    /// Dispara una búsqueda server-side con debounce de 400ms.
    func onSearchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            await executeSearch()
        }
    }

    private func executeSearch() async {
        isLoading = true
        currentPage = 1
        defer { isLoading = false }
        let search = searchText.isEmpty ? nil : searchText
        do {
            let result = try await listService.fetchShipmentList(
                idToken: storedIdToken, clientID: storedClientID, search: search, page: 1, pageSize: pageSize)
            shipments = result.shipments
            hasNextPage = result.hasNextPage
        } catch {
            // falla silenciosamente
        }
    }
}
