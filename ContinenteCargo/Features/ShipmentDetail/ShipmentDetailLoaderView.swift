//
//  ShipmentDetailLoaderView.swift
//  ContinenteCargo
//
//  Fetches a shipment by ID from the Continente Mobile API v1
//  (GET /api/v1/shipments/{shipmentId}) and presents the detail screen.
//

import SwiftUI
import Observation

struct ShipmentDetailLoaderView: View {
    @Environment(AppSession.self) private var session
    let shippingId: Int

    @State private var viewModel = ShipmentDetailLoaderViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Cargando embarque…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CCColor.surface.ignoresSafeArea())
            case .loaded(let shipment):
                ShipmentDetailView(shipment: shipment)
            case .failed(let message):
                ContentUnavailableView {
                    Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") {
                        Task { await viewModel.load(id: shippingId, idToken: session.authSession?.idToken) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CCColor.surface.ignoresSafeArea())
            }
        }
        .task { await viewModel.load(id: shippingId, idToken: session.authSession?.idToken) }
    }
}

// MARK: - View model

@Observable
@MainActor
final class ShipmentDetailLoaderViewModel {
    enum State {
        case loading
        case loaded(Shipment)
        case failed(String)
    }

    private(set) var state: State = .loading

    private let service: ShippingDetailServicing

    init(service: ShippingDetailServicing? = nil) {
        self.service = service ?? ContinenteAPIService.shared
    }

    func load(id: Int, idToken: String?) async {
        if case .loaded = state { return }
        state = .loading
        do {
            let detail = try await service.fetchShippingDetail(id: id, idToken: idToken)
            #if DEBUG
            Self.logDetail(detail)
            #endif
            state = .loaded(detail.asShipment())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    #if DEBUG
    private static func logDetail(_ d: APIShipmentDetail) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📦 Shipment detail — ID \(d.id) | ref: \(d.refCode ?? "—")")
        print("   Documentos  : \(d.documents?.count ?? 0)")
        for doc in d.documents ?? [] {
            print("     · \(doc.fileName ?? "(sin nombre)").\(doc.fileExtension ?? "?")  path: \(doc.path ?? "nil")")
        }
        let invCount = d.invoiceDocuments?.count ?? 0
        print("   Facturas    : \(invCount == 0 ? "⚠️  Sin facturas timbradas asociadas a este embarque" : "\(invCount)")")
        for inv in d.invoiceDocuments ?? [] {
            print("     · folio: \(inv.folio ?? "—")  pdf: \(inv.pdf ?? "nil")  xml: \(inv.xml ?? "nil")")
        }
        print("   Días libres : \(d.freeDays.map { "\($0)" } ?? "nil")")
        print("   ArrivalConf : \(d.arrivalConfirmation.map { CCFormat.date($0) } ?? "⚠️ nil — revisa nombre del campo")")
        print("   changesDate : \(d.changesDate ?? "nil")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    #endif
}

// MARK: - API → UI model mapping

extension APIShipmentDetail {

    /// Maps the API detail onto the app's `Shipment` model so the existing
    /// detail screen renders it unchanged.
    func asShipment() -> Shipment {
        let timeline = (trackingTimeline ?? [])
            .filter { $0.arrivalDate != nil }
            .sorted { $0.arrivalDate! < $1.arrivalDate! }

        let events = timeline.map { event in
            TrackingEvent(
                title: Self.formatEventTitle(event.event),
                location: event.location ?? "",
                date: event.arrivalDate!,
                isCompleted: event.isCompleted ?? false,
                icon: "circle"
            )
        }

        let lastCompleted = timeline
            .filter { $0.isCompleted == true }
            .compactMap(\.arrivalDate)
            .max()

        let docs = (documents ?? [])
            .map { ShipmentDocument(name: $0.fileName ?? "Documento",
                                    date: nil,
                                    s3Path: $0.path,
                                    fileExtension: $0.fileExtension,
                                    documentType: $0.documentType) }

        let invoices = (invoiceDocuments ?? []).compactMap { inv -> InvoiceDocument? in
            guard let id = inv.id else { return nil }
            return InvoiceDocument(id: id,
                                   folio: inv.folio ?? "Factura \(id)",
                                   xmlPath: inv.xml ?? "",
                                   pdfPath: inv.pdf ?? "")
        }

        let chargeItems = (fees ?? []).map {
            Charge(concept: $0.concept ?? "Cargo",
                   amount: $0.total ?? 0,
                   currency: $0.currency ?? "USD")
        }

        let containerList = (containers ?? [])
            .compactMap { c -> String? in
                if let number = c.containerNumber, !number.isEmpty { return number }
                if let type = c.containerType, !type.isEmpty {
                    let qty = c.quantity ?? 1
                    return "\(qty)x\(type)"
                }
                return nil
            }
            .joined(separator: ", ")

        // Compute free days remaining from arrival confirmation date
        let total = freeDays ?? 0
        var freeDaysStartDate: Date? = nil
        var freeDaysRemaining = total
        if let arrival = arrivalConfirmation {
            freeDaysStartDate = arrival
            let daysUsed = max(0, Calendar.current.dateComponents([.day], from: arrival, to: Date()).day ?? 0)
            freeDaysRemaining = max(0, total - daysUsed)
        }

        return Shipment(
            reference: refCode ?? "Embarque \(id)",
            bl: (mbl ?? "—").replacingOccurrences(of: "|", with: ""),
            booking: bookingNumber?.isEmpty == false ? bookingNumber : nil,
            container: containerList.isEmpty ? "—" : containerList,
            transportMode: Self.transportMode(from: transportation),
            status: Self.shipmentStatus(from: status, warning: warning),
            originName: origin ?? pol ?? "Origen",
            originCode: pol ?? "—",
            destinationName: destination ?? pod ?? "Destino",
            destinationCode: pod ?? "—",
            etd: APIDateParser.parse(etd) ?? Date(),
            eta: APIDateParser.parse(eta) ?? Date(),
            lastUpdate: lastCompleted ?? updatedAt ?? Date(),
            carrier: shippingLine ?? "—",
            vessel: shipName ?? "—",
            isInsured: Self.detectsInsurance(in: docs),
            timeline: events,
            documents: docs,
            invoiceDocuments: invoices,
            incidents: [],
            charges: chargeItems,
            freeDaysTotal: total,
            freeDaysRemaining: freeDaysRemaining,
            freeDaysStartDate: freeDaysStartDate
        )
    }

    /// Returns true if any document is an insurance policy.
    private static func detectsInsurance(in docs: [ShipmentDocument]) -> Bool {
        docs.contains(where: \.isPolicy)
    }

    private static func formatEventTitle(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Evento" }
        return raw
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private static func transportMode(from value: String?) -> TransportMode {
        let lowered = (value ?? "").lowercased()
        if lowered.contains("aér") || lowered.contains("aer") || lowered.contains("air") { return .air }
        if lowered.contains("terre") || lowered.contains("land") || lowered.contains("truck") { return .land }
        return .maritime
    }

    private static func shipmentStatus(from value: String?, warning: String?) -> ShipmentStatus {
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
}

#Preview {
    NavigationStack {
        ShipmentDetailLoaderView(shippingId: 1)
    }
    .environment(AppSession())
}
