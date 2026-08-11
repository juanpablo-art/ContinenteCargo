//
//  ShipmentService.swift
//  ContinenteCargo
//
//  Abstraction over the data source. Views/ViewModels depend only on the
//  `ShipmentServing` protocol, so replacing `MockShipmentService` with a real
//  networking implementation later requires no changes above this layer.
//

import Foundation
import UIKit

/// Data access contract for shipments and alerts.
/// Authentication lives in `AuthServicing` (FirebaseAuthService).
/// Methods are async so a real implementation can perform network calls.
protocol ShipmentServing {
    func fetchShipments() async throws -> [Shipment]
    func fetchAlerts() async throws -> [LogisticAlert]
    /// Simulates requesting fresh tracking data from the carrier for one shipment.
    func refreshTracking(for shipmentID: UUID) async throws -> Date
    /// Returns a local file URL for the shipment's insurance policy document.
    /// A real implementation downloads the PDF and returns its temporary location.
    func fetchPolicyDocument(for shipment: Shipment) async throws -> URL
    /// Returns a local file URL for one of the shipment's attached documents.
    func fetchDocumentFile(for document: ShipmentDocument, of shipment: Shipment) async throws -> URL
}

/// Mock implementation backed by in-memory sample data.
/// Network latency is simulated with small delays so loading states are visible.
final class MockShipmentService: ShipmentServing {

    static let shared = MockShipmentService()

    private var shipments: [Shipment] = MockData.shipments
    private var alerts: [LogisticAlert] = MockData.alerts

    func fetchShipments() async throws -> [Shipment] {
        try await Task.sleep(for: .milliseconds(400))
        return shipments
    }

    func fetchAlerts() async throws -> [LogisticAlert] {
        try await Task.sleep(for: .milliseconds(300))
        return alerts.sorted {
            if $0.severity.priority != $1.severity.priority {
                return $0.severity.priority < $1.severity.priority
            }
            return $0.detectedAt > $1.detectedAt
        }
    }

    func refreshTracking(for shipmentID: UUID) async throws -> Date {
        try await Task.sleep(for: .milliseconds(1500))
        let now = Date()
        if let index = shipments.firstIndex(where: { $0.id == shipmentID }) {
            shipments[index].lastUpdate = now
        }
        return now
    }

    func fetchPolicyDocument(for shipment: Shipment) async throws -> URL {
        try await Task.sleep(for: .milliseconds(500))
        return Self.mockPDF(
            filename: "Póliza \(shipment.reference).pdf",
            title: "Póliza de seguro de mercancía",
            rows: [
                ("Número de póliza", "POL-\(shipment.reference)"),
                ("Aseguradora", "Seguros Marítimos del Pacífico, S.A. de C.V."),
                ("Asegurado", "Cliente Continente Cargo"),
                ("Embarque", shipment.reference),
                ("Bill of Lading", shipment.bl),
                ("Contenedor", shipment.container),
                ("Ruta", "\(shipment.originName) (\(shipment.originCode)) → \(shipment.destinationName) (\(shipment.destinationCode))"),
                ("Vigencia", "\(CCFormat.date(shipment.etd)) – \(CCFormat.date(shipment.eta))"),
                ("Cobertura", "Todo riesgo — Institute Cargo Clauses (A)"),
                ("Suma asegurada", "USD 250,000.00")
            ]
        )
    }

    func fetchDocumentFile(for document: ShipmentDocument, of shipment: Shipment) async throws -> URL {
        try await Task.sleep(for: .milliseconds(500))
        var rows: [(String, String)] = [
            ("Documento", document.name),
            ("Embarque", shipment.reference),
            ("Bill of Lading", shipment.bl),
            ("Contenedor", shipment.container),
            ("Naviera", shipment.carrier),
            ("Ruta", "\(shipment.originName) (\(shipment.originCode)) → \(shipment.destinationName) (\(shipment.destinationCode))")
        ]
        if let date = document.date {
            rows.append(("Fecha de emisión", CCFormat.date(date)))
        }
        return Self.mockPDF(
            filename: "\(document.name) \(shipment.reference).pdf",
            title: document.name,
            rows: rows
        )
    }

    // MARK: - Mock PDF rendering

    /// Renders a branded one-page PDF with key/value rows and caches it in the
    /// temporary directory. Replaced by real document downloads later.
    private static func mockPDF(filename: String, title: String, rows: [(String, String)]) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        // US Letter, single page.
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let navy = UIColor(red: 0.07, green: 0.13, blue: 0.28, alpha: 1)
        let gray = UIColor(white: 0.45, alpha: 1)

        let data = renderer.pdfData { context in
            context.beginPage()

            // Navy header band with the brand and document title.
            navy.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 612, height: 110))
            "CONTINENTE CARGO".draw(
                at: CGPoint(x: 48, y: 34),
                withAttributes: [.font: UIFont.systemFont(ofSize: 22, weight: .heavy),
                                 .foregroundColor: UIColor.white])
            title.draw(
                at: CGPoint(x: 48, y: 66),
                withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium),
                                 .foregroundColor: UIColor(white: 1, alpha: 0.8)])

            var y: CGFloat = 150
            for (label, value) in rows {
                label.uppercased().draw(
                    at: CGPoint(x: 48, y: y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                                     .foregroundColor: gray])
                value.draw(
                    at: CGPoint(x: 48, y: y + 13),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 13, weight: .medium),
                                     .foregroundColor: UIColor.black])
                y += 46
            }

            "Documento de ejemplo generado con fines de demostración.".draw(
                at: CGPoint(x: 48, y: 740),
                withAttributes: [.font: UIFont.systemFont(ofSize: 9, weight: .regular),
                                 .foregroundColor: gray])
        }

        try? data.write(to: url)
        return url
    }
}
