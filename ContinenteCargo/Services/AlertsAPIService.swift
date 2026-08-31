//
//  AlertsAPIService.swift
//  ContinenteCargo
//
//  Client for the Continente Mobile API v1.
//  Base: https://dev.mobile.api.continente.mx
//  Decodes the standard API envelope (request_id / code / errors / data / meta).
//

import Foundation

// MARK: - Configuration

enum ContinenteAPIConfig {
    static let baseURL = URL(string: "https://dev.mobile.api.continente.mx")!

    /// Returns a short-lived pre-signed S3 URL for a document path.
    static var documentDownloadURL: URL {
        baseURL.appending(path: "api/v1/shipments/documents/download-url")
    }

    static var overviewURL: URL {
        baseURL.appending(path: "api/v1/shipments/overview")
    }

    static var shipmentsListURL: URL {
        baseURL.appending(path: "api/v1/shipments")
    }

    static var shipmentCountsURL: URL {
        baseURL.appending(path: "api/v1/shipments/count")
    }

    static var alertsURL: URL {
        baseURL.appending(path: "api/v1/shipments/alerts")
    }

    static var alertCountsURL: URL {
        baseURL.appending(path: "api/v1/shipments/alerts/counts")
    }

    static var upcomingEventsURL: URL {
        baseURL.appending(path: "api/v1/shipments/upcoming-events")
    }

    static var devicesURL: URL {
        baseURL.appending(path: "api/v1/devices")
    }

    static func shippingDetailURL(id: Int) -> URL {
        baseURL.appending(path: "api/v1/shipments/\(id)")
    }
}

// MARK: - Date parsing

/// The API mixes ISO-8601 timestamps (with or without fractional seconds)
/// and plain `yyyy-MM-dd` strings for dates like ETD/ETA.
enum APIDateParser {
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let plain: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // El API v1 devuelve fechas ETD/ETA como "dd-MM-yyyy" (e.g. "31-07-2026")
    private static let ddMMYYYY: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFractional.date(from: value)
            ?? iso.date(from: value)
            ?? plain.date(from: value)
            ?? ddMMYYYY.date(from: value)
    }
}

// MARK: - Envelope

/// Standard response wrapper used by the Continente Mobile API v1.
struct APIEnvelope<Payload: Decodable>: Decodable {
    let requestId: String?
    let code: Int?
    let errors: [String]?
    let data: Payload?
    let meta: APIMeta?
}

/// Pagination metadata returned in the envelope.
struct APIMeta: Decodable, Hashable {
    let totalCount: Int?
    let pageSize: Int?
    let currentPage: Int?
    let totalPages: Int?
    let hasNextPage: Bool?
    let hasPreviousPage: Bool?
}

// MARK: - Alerts payload

struct AlertCounts: Decodable, Hashable {
    let all: Int
    let critical: Int
    let warning: Int
    let informative: Int
}

struct AlertReason: Decodable, Hashable {
    let code: String?
    let severity: String?
    let description: String?
}

/// One alerted shipping from GET /api/v1/shipments/alerts.
struct ShippingAlert: Decodable, Identifiable, Hashable {
    let shippingId: Int
    let transportation: String?
    let reasons: [AlertReason]?
    let refCode: String?
    let refNumber: String?
    let pol: String?
    let pod: String?
    let containers: [APIContainer]?
    let etdDelayDays: Int?
    let etaDelayDays: Int?
    let updatedAt: Date?

    var id: Int { shippingId }

    /// Primary severity derived from the most critical reason in the list.
    var severity: AlertSeverity {
        let severities = (reasons ?? []).compactMap {
            AlertSeverity(rawValue: ($0.severity ?? "").lowercased())
        }
        return severities.min(by: { $0.priority < $1.priority }) ?? .informative
    }

    /// Route summary, e.g. "CNSHA → MXZLO", when both ports are known.
    var route: String? {
        guard let pol, !pol.isEmpty, let pod, !pod.isEmpty else { return nil }
        return "\(pol) → \(pod)"
    }

    /// Container numbers joined for display in the alert row.
    var containerNumbers: String? {
        let numbers = (containers ?? []).compactMap { $0.containerNumber }.filter { !$0.isEmpty }
        return numbers.isEmpty ? nil : numbers.joined(separator: ", ")
    }
}

struct ShippingAlertsData: Decodable {
    let counts: AlertCounts?
    let alerts: [ShippingAlert]?
}

/// One fetched page of alerts, ready for the view model.
struct ShippingAlertsPage {
    let counts: AlertCounts?
    let alerts: [ShippingAlert]
    let meta: APIMeta?
}

// MARK: - Shipment counts payload (GET /api/v1/shipments/count)

struct ShipmentCounts: Decodable, Hashable {
    let active: Int
    let inTransit: Int
    let inOrigin: Int
    let soonToArrive: Int
    let needAttention: Int
    let total: Int
}

// MARK: - Overview payload (GET /api/v1/shipments/overview)

struct OverviewCounts: Decodable, Hashable {
    let assigned: Int
    let inTransit: Int
    let provisionalInformation: Int
    let detained: Int
    let delivered: Int
    let finished: Int
    let total: Int
}

struct OverviewShipment: Decodable, Identifiable, Hashable {
    let id: Int
    let refCode: String?
    let orderReference: String?
    let origin: String?
    let destination: String?
    let pol: String?
    let pod: String?
    let status: String?
    let etd: String?
    let eta: String?
    let transportation: String?
    let warning: String?
    let updatedAt: Date?
    let containers: [APIContainer]?

    var etaDate: Date? { APIDateParser.parse(eta) }
}

/// Overview result ready for the view model.
struct ShippingOverview {
    let counts: OverviewCounts?
    let shipments: [OverviewShipment]
}

// MARK: - Home payload (GET /api/Client/shipping/home)

struct HomeCounts: Decodable, Hashable {
    let active: Int
    let inTransit: Int
    let atOrigin: Int
    let arrivingSoon: Int
    let requiresAttention: Int
    let criticalAlerts: Int
}

struct HomeAttentionShipment: Decodable, Identifiable, Hashable {
    let shippingId: Int
    let transportationId: Int?
    let transportation: String?
    let refCode: String?
    let clientReference: String?
    let reasons: [AlertReason]?
    let updatedAt: Date?
    let containerNumbers: String?
    let nextEvent: String?
    let nextEventDate: Date?

    var id: Int { shippingId }
}

struct HomeArrivingSoonShipment: Decodable, Identifiable, Hashable {
    let shippingId: Int
    let transportationId: Int?
    let transportation: String?
    let refCode: String?
    let clientReference: String?
    let arrivalDate: Date?
    let port: String?
    let containerNumbers: String?

    var id: Int { shippingId }
}

struct HomeData: Decodable {
    let counts: HomeCounts?
    let attentionShipments: [HomeAttentionShipment]?
    let arrivingSoonShipments: [HomeArrivingSoonShipment]?
}

struct HomeResult {
    let counts: HomeCounts?
    let attentionShipments: [HomeAttentionShipment]
    let arrivingSoonShipments: [HomeArrivingSoonShipment]
}

// MARK: - Shipping detail payload (GET /api/v1/shipments/{shipmentId})

struct APIShipmentDetail: Decodable {
    // ShipmentListItemDto base fields:
    let id: Int
    let refCode: String?
    let orderReference: String?
    let origin: String?
    let destination: String?
    let pol: String?
    let pod: String?
    let status: String?
    let etd: String?
    let eta: String?
    let transportation: String?
    let warning: String?
    let updatedAt: Date?
    let containers: [APIContainer]?
    // ShipmentDetailDto extra fields:
    let mbl: String?
    let freeDays: Int?
    let changesDate: String?
    let arrivalConfirmation: Date?
    let shippingLine: String?
    let shipName: String?
    let bookingNumber: String?
    let trackingTimeline: [TrackingEventDto]?
    let documents: [APIDocument]?
    let invoiceDocuments: [APIInvoiceDocument]?
    let fees: [ShippingSaleDto]?
}

struct APIInvoiceDocument: Decodable, Hashable {
    let id: Int?
    let folio: String?
    let xml: String?
    let pdf: String?
}

struct APIContainer: Decodable, Hashable {
    let containerNumber: String?
    let containerType: String?
    let quantity: Int?
}

struct TrackingEventDto: Decodable, Hashable {
    let position: Int?
    let event: String?
    let isCompleted: Bool?
    let location: String?
    let arrivalDate: Date?
}

struct APIDocument: Decodable, Hashable {
    let id: Int?
    let fileName: String?
    let fileExtension: String?
    let path: String?
    let documentType: String?
}

/// Response of GET /api/v1/shipments/documents/download-url — a short-lived S3 link.
/// The API may return the URL under different field names; all common variants are covered.
struct DocumentDownloadURL: Decodable {
    let url: String?
    let downloadUrl: String?
    let signedUrl: String?
    let presignedUrl: String?
    let fileUrl: String?
    let expiresAt: Date?

    /// First non-nil URL string regardless of which field the API used.
    var resolvedURLString: String? {
        url ?? downloadUrl ?? signedUrl ?? presignedUrl ?? fileUrl
    }
}

struct ShippingSaleDto: Decodable, Hashable {
    let concept: String?
    let total: Double?
    let currency: String?
}

// MARK: - Upcoming events payload (GET /api/v1/shipments/upcoming-events)

struct ShipmentUpcomingEventItem: Decodable, Identifiable {
    let shippingId: Int
    let refCode: String?
    let refNumber: String?
    let transportation: String?
    let event: String?
    let eventDescription: String?
    let eventDate: Date?
    let daysUntilEvent: Int?
    let pol: String?
    let pod: String?
    let etd: Date?
    let eta: Date?
    let updatedAt: Date?
    let containers: [APIContainer]?

    var id: Int { shippingId }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case unauthorized
    case network
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Tu sesión no tiene acceso al servidor. Inicia sesión de nuevo."
        case .network:
            return "Sin conexión. Revisa tu internet e inténtalo de nuevo."
        case .server(let message):
            return "No se pudieron cargar los datos. (\(message))"
        }
    }
}

// MARK: - Contract

protocol AlertsServicing {
    func fetchShippingAlerts(idToken: String?, clientID: Int?, search: String?, pageSize: Int, pageNumber: Int) async throws -> ShippingAlertsPage
}

protocol ShippingDetailServicing {
    func fetchShippingDetail(id: Int, idToken: String?) async throws -> APIShipmentDetail
}

protocol DocumentDownloadServicing {
    /// Resolves a document path to a temporary pre-signed URL for direct download.
    func fetchDocumentDownloadURL(path: String, idToken: String?) async throws -> URL
}

protocol OverviewServicing {
    func fetchOverview(idToken: String?, clientID: Int?) async throws -> ShippingOverview
}

protocol HomeServicing {
    func fetchHome(idToken: String?, clientID: Int?) async throws -> HomeResult
}

protocol ShipmentListServicing {
    func fetchShipmentList(idToken: String?, clientID: Int?, search: String?, page: Int, pageSize: Int) async throws -> (shipments: [Shipment], counts: OverviewCounts?, hasNextPage: Bool)
}

protocol ShipmentCountsServicing {
    func fetchShipmentCounts(idToken: String?) async throws -> ShipmentCounts
}

protocol AlertCountsServicing {
    func fetchAlertCounts(idToken: String?, search: String?) async throws -> AlertCounts
}

protocol UpcomingEventsServicing {
    func fetchUpcomingEvents(idToken: String?, pageSize: Int) async throws -> [ShipmentUpcomingEventItem]
}

// MARK: - Device registration DTOs + protocol

struct RegisterDeviceDto: Encodable {
    let token: String
    let platform: String
}

struct UnregisterDeviceDto: Encodable {
    let token: String
}

protocol DeviceServicing {
    func registerDevice(token: String, idToken: String?) async throws
    func unregisterDevice(token: String, idToken: String?) async throws
}

// MARK: - Real API client

final class ContinenteAPIService: AlertsServicing, ShippingDetailServicing, OverviewServicing, HomeServicing, ShipmentListServicing, ShipmentCountsServicing, AlertCountsServicing, UpcomingEventsServicing, DocumentDownloadServicing, DeviceServicing {

    static let shared = ContinenteAPIService()

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func fetchDocumentDownloadURL(path: String, idToken: String?) async throws -> URL {
        var components = URLComponents(url: ContinenteAPIConfig.documentDownloadURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        let envelope: APIEnvelope<DocumentDownloadURL> = try await get(components.url!, idToken: idToken)
        guard let urlString = envelope.data?.resolvedURLString, let url = URL(string: urlString) else {
            throw APIError.server("URL de documento no disponible")
        }
        return url
    }

    func fetchShippingAlerts(idToken: String?, clientID: Int?, search: String?, pageSize: Int, pageNumber: Int) async throws -> ShippingAlertsPage {
        var components = URLComponents(url: ContinenteAPIConfig.alertsURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "PageSize", value: "\(pageSize)"),
            URLQueryItem(name: "PageNumber", value: "\(pageNumber)")
        ]
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "Search", value: search)) }
        components.queryItems = queryItems
        let envelope: APIEnvelope<[ShippingAlert]> = try await get(components.url!, idToken: idToken)
        return ShippingAlertsPage(counts: nil, alerts: envelope.data ?? [], meta: envelope.meta)
    }

    func fetchHome(idToken: String?, clientID: Int?) async throws -> HomeResult {
        throw APIError.server("Sin endpoint en v1")
    }

    func fetchOverview(idToken: String?, clientID: Int?) async throws -> ShippingOverview {
        let envelope: APIEnvelope<OverviewCounts> = try await get(ContinenteAPIConfig.overviewURL, idToken: idToken)
        return ShippingOverview(counts: envelope.data, shipments: [])
    }

    func fetchShipmentCounts(idToken: String?) async throws -> ShipmentCounts {
        let envelope: APIEnvelope<ShipmentCounts> = try await get(ContinenteAPIConfig.shipmentCountsURL, idToken: idToken)
        guard let counts = envelope.data else { throw APIError.server("counts vacíos") }
        return counts
    }

    func fetchUpcomingEvents(idToken: String?, pageSize: Int) async throws -> [ShipmentUpcomingEventItem] {
        var components = URLComponents(url: ContinenteAPIConfig.upcomingEventsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "PageSize", value: "\(pageSize)"),
                                 URLQueryItem(name: "PageNumber", value: "1")]
        let envelope: APIEnvelope<[ShipmentUpcomingEventItem]> = try await get(components.url!, idToken: idToken)
        return envelope.data ?? []
    }

    func fetchAlertCounts(idToken: String?, search: String?) async throws -> AlertCounts {
        var components = URLComponents(url: ContinenteAPIConfig.alertCountsURL, resolvingAgainstBaseURL: false)!
        if let search, !search.isEmpty {
            components.queryItems = [URLQueryItem(name: "Search", value: search)]
        }
        let envelope: APIEnvelope<AlertCounts> = try await get(components.url!, idToken: idToken)
        guard let counts = envelope.data else { throw APIError.server("counts vacíos") }
        return counts
    }

    func fetchShipmentList(idToken: String?, clientID: Int?, search: String?, page: Int, pageSize: Int) async throws -> (shipments: [Shipment], counts: OverviewCounts?, hasNextPage: Bool) {
        var components = URLComponents(url: ContinenteAPIConfig.shipmentsListURL, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "PageSize", value: "\(pageSize)"),
                          URLQueryItem(name: "PageNumber", value: "\(page)")]
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "Search", value: search)) }
        components.queryItems = queryItems
        let listURL = components.url!

        let listEnvelope: APIEnvelope<[OverviewShipment]> = try await get(listURL, idToken: idToken)
        let shipments = (listEnvelope.data ?? []).map(Shipment.init(overviewShipment:))
        return (shipments, nil, listEnvelope.meta?.hasNextPage ?? false)
    }

    func fetchShippingDetail(id: Int, idToken: String?) async throws -> APIShipmentDetail {
        let envelope: APIEnvelope<APIShipmentDetail> = try await get(
            ContinenteAPIConfig.shippingDetailURL(id: id), idToken: idToken)
        guard let detail = envelope.data else {
            throw APIError.server("embarque no encontrado")
        }
        return detail
    }

    // MARK: - Device registration

    func registerDevice(token: String, idToken: String?) async throws {
        try await send("POST", ContinenteAPIConfig.devicesURL,
                       body: RegisterDeviceDto(token: token, platform: "ios"),
                       idToken: idToken)
    }

    func unregisterDevice(token: String, idToken: String?) async throws {
        try await send("DELETE", ContinenteAPIConfig.devicesURL,
                       body: UnregisterDeviceDto(token: token),
                       idToken: idToken)
    }

    // MARK: Plumbing

    /// Authenticated GET returning the standard API envelope.
    private func get<Payload: Decodable>(_ url: URL, idToken: String?) async throws -> APIEnvelope<Payload> {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idToken {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await urlSession.data(for: request)
        } catch {
            throw APIError.network
        }

        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        #if DEBUG
        let prettyJSON = (try? JSONSerialization.jsonObject(with: data))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .prettyPrinted) }
            .flatMap { String(data: $0, encoding: .utf8) } ?? String(data: data, encoding: .utf8) ?? "(vacío)"
        print("🌐 [\(statusCode)] \(url.path)\n\(prettyJSON)\n")
        #endif
        if statusCode == 401 || statusCode == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(statusCode) else {
            throw APIError.server("HTTP \(statusCode)")
        }

        let envelope: APIEnvelope<Payload>
        do {
            envelope = try Self.decoder.decode(APIEnvelope<Payload>.self, from: data)
        } catch {
            throw APIError.server("respuesta inválida")
        }

        if let errors = envelope.errors, !errors.isEmpty {
            throw APIError.server(errors.joined(separator: "; "))
        }
        return envelope
    }

    /// Authenticated POST / DELETE with a JSON body; only checks the HTTP status.
    private func send<Body: Encodable>(_ method: String, _ url: URL, body: Body, idToken: String?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idToken { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        let bodyStr = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(vacío)"
        let authPrefix = idToken.map { "Bearer \($0.prefix(20))..." } ?? "nil"
        print("📱 [\(method)] \(url.path)\n  Auth: \(authPrefix)\n  Body: \(bodyStr)")
        #endif

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await urlSession.data(for: request)
        } catch {
            throw APIError.network
        }

        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        #if DEBUG
        let responseStr = String(data: data, encoding: .utf8) ?? "(vacío)"
        print("📱 [\(statusCode)] \(method) \(url.path) → \(responseStr)")
        #endif
        if statusCode == 401 || statusCode == 403 { throw APIError.unauthorized }
        guard (200..<300).contains(statusCode) else { throw APIError.server("HTTP \(statusCode)") }
    }

    // MARK: Decoding

    /// The API sends ISO-8601 dates, sometimes with fractional seconds.
    private static let decoder: JSONDecoder = {
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = isoFractional.date(from: value) ?? iso.date(from: value) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Fecha no reconocida: \(value)"
            ))
        }
        return decoder
    }()
}

// MARK: - Mock fallback

/// Serves the alerts schema from local sample data, so the Alerts tab
/// keeps working while the API is unreachable or unauthorized.
final class MockAlertsService: AlertsServicing {

    static let shared = MockAlertsService()

    func fetchShippingAlerts(idToken: String?, clientID: Int?, search: String?, pageSize: Int, pageNumber: Int) async throws -> ShippingAlertsPage {
        try await Task.sleep(for: .milliseconds(300))

        let shipments = MockData.shipments
        let alerts = MockData.alerts.enumerated().map { index, alert -> ShippingAlert in
            let shipment = shipments.first { $0.id == alert.shipmentID }
            let container: [APIContainer]? = {
                guard let c = shipment?.container, !c.isEmpty else { return nil }
                return [APIContainer(containerNumber: c, containerType: nil, quantity: nil)]
            }()
            return ShippingAlert(
                shippingId: index + 1,
                transportation: shipment?.transportMode.title,
                reasons: [AlertReason(code: alert.type.rawValue,
                                      severity: alert.severity.rawValue,
                                      description: alert.message)],
                refCode: alert.shipmentReference,
                refNumber: nil,
                pol: shipment?.originCode,
                pod: shipment?.destinationCode,
                containers: container,
                etdDelayDays: alert.type == .etdDelay ? 2 : nil,
                etaDelayDays: alert.type == .etaDelay ? 3 : nil,
                updatedAt: alert.detectedAt
            )
        }
        .sorted { $0.severity.priority < $1.severity.priority }

        let counts = AlertCounts(
            all: alerts.count,
            critical: alerts.filter { $0.severity == .critical }.count,
            warning: alerts.filter { $0.severity == .warning }.count,
            informative: alerts.filter { $0.severity == .informative }.count
        )
        return ShippingAlertsPage(counts: counts, alerts: alerts, meta: nil)
    }
}

// MARK: - OverviewShipment → Shipment mapping

private extension Shipment {

    /// Maps API status strings (e.g. "NEED_ATTENTION", "IN_TRANSIT") and the
    /// warning field to the app's ShipmentStatus enum.
    static func mapStatus(from value: String?, warning: String?) -> ShipmentStatus {
        if let warning, !warning.isEmpty { return .needsAttention }
        switch value?.uppercased() {
        case "NEED_ATTENTION", "NEEDATTENTION": return .needsAttention
        case "DETAINED", "DETENIDO":            return .needsAttention
        case "DELIVERED", "ENTREGADO":          return .delivered
        case "FINISHED", "FINALIZADO":          return .delivered
        case "ASSIGNED", "ASIGNADO",
             "IN_ORIGIN", "INORIGIN":          return .atOrigin
        case "PROVISIONAL_INFORMATION",
             "PROVISIONALINFORMATION":          return .atOrigin
        case "SOON_TO_ARRIVE", "SOONTOARRIVE": return .arrivingSoon
        case "ACTIVES", "ACTIVE":              return .active
        case "IN_TRANSIT", "INTRANSIT":        return .inTransit
        default:                                return .inTransit
        }
    }

    /// Builds a Shipment from the lighter list payload (ShipmentListItemDto).
    /// Fields not in the list (bl, carrier, vessel) are left empty; populated on detail load.
    init(overviewShipment s: OverviewShipment) {
        let status: ShipmentStatus = Self.mapStatus(from: s.status, warning: s.warning)

        let mode: TransportMode = {
            let t = (s.transportation ?? "").lowercased()
            if t.contains("aér") || t.contains("aer") || t.contains("air") { return .air }
            if t.contains("terr") || t.contains("land") { return .land }
            return .maritime
        }()
        self.init(
            shippingId: s.id,
            reference: s.refCode ?? "—",
            bl: "",
            booking: s.orderReference,
            container: s.containers?.first?.containerNumber ?? s.containers?.first?.containerType ?? "",
            transportMode: mode,
            status: status,
            originName: s.origin ?? s.pol ?? "",
            originCode: s.pol ?? "",
            destinationName: s.destination ?? s.pod ?? "",
            destinationCode: s.pod ?? "",
            etd: APIDateParser.parse(s.etd) ?? Date.distantPast,
            eta: APIDateParser.parse(s.eta) ?? Date.distantFuture,
            lastUpdate: s.updatedAt ?? Date(),
            carrier: "",
            vessel: ""
        )
    }
}
