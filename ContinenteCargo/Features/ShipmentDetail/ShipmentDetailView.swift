//
//  ShipmentDetailView.swift
//  ContinenteCargo
//
//  Full detail of a shipment: route, logistics data, timeline, documents,
//  incidents, charges, free days, and manual tracking update.
//

import SwiftUI
import QuickLook

struct ShipmentDetailView: View {
    @Environment(AppSession.self) private var session
    @State private var viewModel: ShipmentDetailViewModel

    init(shipment: Shipment) {
        _viewModel = State(initialValue: ShipmentDetailViewModel(
            shipment: shipment,
            service: MockShipmentService.shared
        ))
    }

    private var shipment: Shipment { viewModel.shipment }

var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CCSpacing.xl) {
                header
                infoGrid
                if !shipment.timeline.isEmpty { timelineSection }
                if !shipment.incidents.isEmpty { incidentsSection }
                if !shipment.documents.isEmpty { documentsSection }
                if shipment.charges.contains(where: { $0.amount != 0 }) { chargesSection }
                if shipment.freeDaysTotal > 0 { freeDaysSection }
            }
            .padding(CCSpacing.lg)
        }
        .background(CCColor.surface.ignoresSafeArea())
        .navigationTitle(shipment.reference)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.idToken = session.authSession?.idToken }
        .quickLookPreview($viewModel.previewSelectedURL, in: viewModel.previewDocumentURLs)
        .alert("No se pudo abrir el documento",
               isPresented: Binding(
                   get: { viewModel.documentError != nil },
                   set: { if !$0 { viewModel.clearDocumentError() } }
               )) {
            Button("OK", role: .cancel) { viewModel.clearDocumentError() }
        } message: {
            Text(viewModel.documentError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: CCSpacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shipment.reference)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CCColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Label(shipment.transportMode.title, systemImage: shipment.transportMode.icon)
                        .font(.subheadline)
                        .foregroundStyle(CCColor.textSecondary)
                }
                Spacer(minLength: CCSpacing.sm)
                StatusBadge(status: shipment.status)
            }

            // Route with origin/destination emphasis.
            // City name (originName/destinationName) is shorter and shown prominently;
            // port/airport name is shown below in caption.
            HStack(spacing: CCSpacing.md) {
                routeEndpoint(code: shipment.originName, name: shipment.originCode)
                VStack(spacing: 2) {
                    Image(systemName: shipment.transportMode.icon)
                        .font(.subheadline)
                        .foregroundStyle(CCColor.actionBlue)
                    Rectangle()
                        .fill(CCColor.border)
                        .frame(height: 2)
                }
                routeEndpoint(code: shipment.destinationName, name: shipment.destinationCode, alignment: .trailing)
            }

            // Discreet last-update footer inside the header card.
            Divider().overlay(CCColor.border)
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                Text(viewModel.lastUpdateText)
                    .font(.caption)
            }
            .foregroundStyle(CCColor.textTertiary)

            if viewModel.isTrackingStale {
                Label("No se ha recibido nueva información en las últimas 24 horas.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CCColor.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CCSpacing.md)
                    .background(CCColor.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous))
            }
        }
        .ccCard()
    }

    private func routeEndpoint(code: String, name: String,
                               alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CCColor.textPrimary)
                .lineLimit(1)
            Text(name)
                .font(.caption)
                .foregroundStyle(CCColor.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }

    // MARK: - Info grid

    private var infoGrid: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: "Datos logísticos")
            VStack(alignment: .leading, spacing: CCSpacing.lg) {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                    GridItem(.flexible(), alignment: .leading)],
                          spacing: CCSpacing.lg) {
                    InfoRow(label: "ETD", value: CCFormat.date(shipment.etd), icon: "calendar")
                    InfoRow(label: "ETA", value: CCFormat.date(shipment.eta), icon: "calendar")
                    InfoRow(label: "Naviera", value: shipment.carrier, icon: "building.2")
                    InfoRow(label: "Buque", value: shipment.vessel, icon: "ferry")
                    InfoRow(label: "Contenedor", value: shipment.container, icon: "shippingbox")
                    InfoRow(label: "Booking", value: shipment.booking ?? "Sin booking", icon: "doc.text")
                    InfoRow(label: "BL", value: shipment.bl, icon: "doc.plaintext")
                    InfoRow(label: "Tipo", value: shipment.status.title, icon: shipment.status.icon)
                }
                insuranceBanner
            }
            .ccCard()
        }
    }

    /// Full-width insurance status banner at the foot of the logistics card.
    /// When insured, tapping it opens the policy document in Quick Look.
    @ViewBuilder
    private var insuranceBanner: some View {
        if shipment.isInsured {
            Button {
                Task { await viewModel.showPolicy() }
            } label: {
                insuranceBannerContent
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingPolicy)
        } else {
            insuranceBannerContent
        }
    }

    private var insuranceBannerContent: some View {
        let insured = shipment.isInsured
        let tint = insured ? CCColor.green : CCColor.orange
        return HStack(spacing: CCSpacing.md) {
            Image(systemName: insured ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(insured ? "Mercancía asegurada" : "Mercancía sin seguro")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CCColor.textPrimary)
                Text(insured
                     ? "Toca para ver el archivo de la póliza."
                     : "Este embarque viaja sin cobertura de seguro.")
                    .font(.caption)
                    .foregroundStyle(CCColor.textSecondary)
            }
            Spacer(minLength: 0)
            if insured {
                if viewModel.isLoadingPolicy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CCColor.textTertiary)
                }
            }
        }
        .padding(CCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous))
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: "Línea de tiempo logística")
            VStack(spacing: 0) {
                ForEach(Array(shipment.timeline.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(event: event,
                                isFirst: index == 0,
                                isLast: index == shipment.timeline.count - 1)
                }
            }
            .ccCard()
        }
    }

    // MARK: - Incidents

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: "Incidencias")
            VStack(spacing: CCSpacing.md) {
                ForEach(shipment.incidents) { incident in
                    HStack(alignment: .top, spacing: CCSpacing.md) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(incident.severity.color)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(incident.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CCColor.textPrimary)
                                Spacer()
                                SeverityBadge(severity: incident.severity)
                            }
                            Text(incident.detail)
                                .font(.caption)
                                .foregroundStyle(CCColor.textSecondary)
                            Text(CCFormat.relativeSince(incident.date))
                                .font(.caption2)
                                .foregroundStyle(CCColor.textTertiary)
                        }
                    }
                    if incident.id != shipment.incidents.last?.id {
                        Divider().overlay(CCColor.border)
                    }
                }
            }
            .ccCard()
        }
    }

    // MARK: - Documents

    private var documentsSection: some View {
        let policies = shipment.documents.filter { $0.isPolicy }
        let attachments = shipment.documents.filter { !$0.isPolicy }
        return VStack(alignment: .leading, spacing: CCSpacing.xl) {
            if !policies.isEmpty {
                documentGroup(title: "Pólizas de Seguro",
                              icon: "shield.fill",
                              docs: policies)
            }
            if !attachments.isEmpty {
                documentGroup(title: "Archivos Adjuntos",
                              icon: "doc.fill",
                              docs: attachments)
            }
        }
    }

    private func documentGroup(title: String, icon: String, docs: [ShipmentDocument]) -> some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: title)
            VStack(spacing: 0) {
                ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                    Button {
                        Task { await viewModel.showDocument(doc, in: docs) }
                    } label: {
                        HStack(spacing: CCSpacing.md) {
                            Image(systemName: icon)
                                .foregroundStyle(CCColor.actionBlue)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(doc.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(CCColor.textPrimary)
                                if let date = doc.date {
                                    Text(CCFormat.date(date))
                                        .font(.caption2)
                                        .foregroundStyle(CCColor.textTertiary)
                                }
                            }
                            Spacer()
                            if viewModel.loadingDocumentID == doc.id {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CCColor.textTertiary)
                            }
                        }
                        .padding(.vertical, CCSpacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.loadingDocumentID != nil)
                    if index < docs.count - 1 {
                        Divider().overlay(CCColor.border)
                    }
                }
            }
            .padding(.horizontal, CCSpacing.lg)
            .background(CCColor.background)
            .clipShape(RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous)
                .strokeBorder(CCColor.border, lineWidth: 1))
        }
    }

    // MARK: - Charges

    private var chargesSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: "Cargos")
            VStack(spacing: 0) {
                ForEach(Array(shipment.charges.enumerated()), id: \.element.id) { index, charge in
                    HStack {
                        Text(charge.concept)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CCColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(charge.formattedAmount)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CCColor.textPrimary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.vertical, CCSpacing.md)
                    if index < shipment.charges.count - 1 {
                        Divider().overlay(CCColor.border)
                    }
                }
            }
            .padding(.horizontal, CCSpacing.lg)
            .background(CCColor.background)
            .clipShape(RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous)
                .strokeBorder(CCColor.border, lineWidth: 1))
        }
    }

    // MARK: - Free days

    private var freeDaysSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            SectionHeader(title: "Días libres")
            let remaining = shipment.freeDaysRemaining
            let total = max(shipment.freeDaysTotal, 1)
            let tint: Color = remaining <= 2 ? CCColor.red : (remaining <= 4 ? CCColor.orange : CCColor.green)
            VStack(alignment: .leading, spacing: CCSpacing.sm) {
                HStack {
                    Text("\(remaining) de \(shipment.freeDaysTotal) días restantes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CCColor.textPrimary)
                    Spacer()
                    if remaining <= 2 {
                        Text("Por vencer")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(CCColor.red)
                    }
                }
                ProgressView(value: Double(remaining), total: Double(total))
                    .tint(tint)
            }
            .ccCard()
        }
    }
}

// MARK: - Timeline row

/// A single milestone row with a connecting rail and node.
private struct TimelineRow: View {
    let event: TrackingEvent
    let isFirst: Bool
    let isLast: Bool

    private var accent: Color { event.isCompleted ? CCColor.green : CCColor.textTertiary }

    var body: some View {
        HStack(alignment: .top, spacing: CCSpacing.md) {
            // Rail + node
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? .clear : CCColor.border)
                    .frame(width: 2, height: 14)
                ZStack {
                    Circle()
                        .fill(event.isCompleted ? CCColor.green : CCColor.background)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                    if event.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Rectangle()
                    .fill(isLast ? .clear : CCColor.border)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 22)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(event.isCompleted ? CCColor.textPrimary : CCColor.textSecondary)
                HStack(spacing: CCSpacing.sm) {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                    Text("·")
                    Text(CCFormat.date(event.date))
                }
                .font(.caption)
                .foregroundStyle(CCColor.textTertiary)
            }
            .padding(.top, 12)
            .padding(.bottom, isLast ? 0 : CCSpacing.md)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ShipmentDetailView(shipment: MockData.shipments.first { $0.status == .needsAttention } ?? MockData.shipments[0])
    }
}
