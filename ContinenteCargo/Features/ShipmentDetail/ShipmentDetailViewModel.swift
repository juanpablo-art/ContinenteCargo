//
//  ShipmentDetailViewModel.swift
//  ContinenteCargo
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ShipmentDetailViewModel {
    private(set) var shipment: Shipment
    private(set) var lastUpdate: Date

    /// All local URLs available in the current Quick Look session.
    var previewDocumentURLs: [URL] = []
    /// Selected URL within previewDocumentURLs; non-nil presents the Quick Look preview.
    var previewSelectedURL: URL?
    private(set) var isLoadingPolicy = false
    /// ID of the document currently being fetched, to show its row spinner.
    private(set) var loadingDocumentID: UUID?
    /// ID of the invoice currently being fetched.
    private(set) var loadingInvoiceID: Int?
    /// Which file (pdf/xml) is loading within the invoice row.
    private(set) var loadingInvoiceFileType: InvoiceFileType?
    /// Non-nil when the last document download failed.
    private(set) var documentError: String?

    enum InvoiceFileType { case pdf, xml }
    /// Auth token, injected from the view so document downloads are authenticated.
    var idToken: String?

    private let service: ShipmentServing
    private let downloadService: DocumentDownloadServicing

    init(shipment: Shipment,
         service: ShipmentServing,
         downloadService: DocumentDownloadServicing? = nil) {
        self.shipment = shipment
        self.lastUpdate = shipment.lastUpdate
        self.service = service
        self.downloadService = downloadService ?? ContinenteAPIService.shared
    }

    /// True when tracking hasn't been refreshed in the last 24 hours.
    var isTrackingStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 24 * 60 * 60
    }

    var lastUpdateText: String {
        "Última actualización: \(CCFormat.relativeSince(lastUpdate).lowercased())"
    }

    /// Opens all policy documents in Quick Look so the user can swipe between them.
    func showPolicy() async {
        guard !isLoadingPolicy else { return }
        isLoadingPolicy = true
        defer { isLoadingPolicy = false }
        let policies = shipment.documents.filter(\.isPolicy)
        if let first = policies.first {
            await showDocument(first, in: policies)
        } else {
            // Demo data has no real document; fall back to the mock policy PDF.
            if let url = try? await service.fetchPolicyDocument(for: shipment) {
                previewDocumentURLs = [url]
                previewSelectedURL = url
            }
        }
    }

    /// Downloads all documents in `docs` concurrently and opens Quick Look starting
    /// at `document`, allowing the user to swipe to the others.
    func showDocument(_ document: ShipmentDocument, in docs: [ShipmentDocument]) async {
        guard loadingDocumentID == nil else { return }
        loadingDocumentID = document.id
        defer { loadingDocumentID = nil }
        documentError = nil

        // Download all docs in the group concurrently; collect (originalIndex, localURL).
        var resolved: [Int: URL] = [:]
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, doc) in docs.enumerated() {
                group.addTask { [self] in
                    return (index, try? await self.resolve(doc))
                }
            }
            for await (index, url) in group {
                if let url { resolved[index] = url }
            }
        }

        let orderedURLs = docs.indices.compactMap { resolved[$0] }
        guard !orderedURLs.isEmpty else {
            documentError = "No se pudo abrir el documento. Verifica tu conexión e intenta de nuevo."
            return
        }

        previewDocumentURLs = orderedURLs
        // Open at the tapped document; fall back to the first if not found.
        if let tappedIndex = docs.firstIndex(where: { $0.id == document.id }),
           tappedIndex < orderedURLs.count {
            previewSelectedURL = orderedURLs[tappedIndex]
        } else {
            previewSelectedURL = orderedURLs.first
        }
    }

    func clearDocumentError() { documentError = nil }

    /// Downloads both PDF and XML for an invoice concurrently and opens Quick Look
    /// starting at the tapped file — the user can swipe to the other.
    func showInvoice(_ invoice: InvoiceDocument, fileType: InvoiceFileType) async {
        guard loadingInvoiceID == nil else { return }
        loadingInvoiceID = invoice.id
        loadingInvoiceFileType = fileType
        defer {
            loadingInvoiceID = nil
            loadingInvoiceFileType = nil
        }
        documentError = nil

        // Download both files concurrently; order: [PDF, XML]
        let files: [(path: String, ext: String)] = [
            (invoice.pdfPath, "pdf"),
            (invoice.xmlPath, "xml")
        ]

        var resolved: [Int: URL] = [:]
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask { [self] in
                    let fileName = "\(invoice.folio).\(file.ext)"
                    let url = try? await self.resolveInvoicePath(file.path, fileName: fileName)
                    return (index, url)
                }
            }
            for await (index, url) in group {
                if let url { resolved[index] = url }
            }
        }

        let orderedURLs = files.indices.compactMap { resolved[$0] }
        guard !orderedURLs.isEmpty else {
            documentError = "No se pudo abrir el archivo. Verifica tu conexión e intenta de nuevo."
            return
        }

        previewDocumentURLs = orderedURLs
        // Open at the tapped file type
        let tappedIndex = fileType == .pdf ? 0 : 1
        previewSelectedURL = resolved[tappedIndex] ?? orderedURLs.first
    }

    private func resolveInvoicePath(_ path: String, fileName: String) async throws -> URL {
        guard !path.isEmpty else { throw URLError(.badURL) }
        if let directURL = URL(string: path), directURL.scheme?.hasPrefix("http") == true {
            return try await Self.download(from: directURL, fileName: fileName)
        }
        let signedURL = try await downloadService.fetchDocumentDownloadURL(path: path, idToken: idToken)
        return try await Self.download(from: signedURL, fileName: fileName)
    }

    // MARK: - Download

    /// Resolves a single document to a local file URL.
    private func resolve(_ document: ShipmentDocument) async throws -> URL {
        guard let path = document.s3Path, !path.isEmpty else {
            return try await service.fetchDocumentFile(for: document, of: shipment)
        }
        // If the path is already a full URL (pre-signed by the server), use it directly.
        if let directURL = URL(string: path), directURL.scheme?.hasPrefix("http") == true {
            return try await Self.download(from: directURL, fileName: document.displayFileName)
        }
        // Otherwise request a short-lived signed URL from the API.
        let signedURL = try await downloadService.fetchDocumentDownloadURL(
            path: path, idToken: idToken)
        return try await Self.download(from: signedURL, fileName: document.displayFileName)
    }

    private nonisolated static func download(from url: URL, fileName: String) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        // Always refresh: pre-signed URLs expire, and the file may have changed.
        try? FileManager.default.removeItem(at: destination)

        let (tempURL, response) = try await URLSession.shared.download(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("📄 [Download] \(status) \(url.path)")
        guard (200..<300).contains(status) else { throw URLError(.badServerResponse) }

        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
}
