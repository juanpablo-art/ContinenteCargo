//
//  HomeView.swift
//  ContinenteCargo
//
//  Executive summary of the client's whole logistics operation.
//  Layout follows the brand mockup: logo + bell toolbar, greeting,
//  white hero card, 4-across metrics, critical alerts and upcoming events.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(HomeViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CCSpacing.xl) {
                    greeting

                    Group {
                        statButton(.all) {
                            HeroStatCard(value: viewModel.summary.active,
                                         title: "Embarques activos")
                        }

                        summaryRow

                        criticalAlertsSection

                        upcomingEventsSection
                    }
                    .redacted(reason: viewModel.isLoading ? .placeholder : [])
                    .allowsHitTesting(!viewModel.isLoading)
                }
                .padding(CCSpacing.lg)
            }
            .background(CCColor.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(for: Shipment.self) { shipment in
                ShipmentDetailView(shipment: shipment)
            }
            .navigationDestination(for: Int.self) { shippingId in
                ShipmentDetailLoaderView(shippingId: shippingId)
            }
            .task(id: session.authSession?.idToken) {
                await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID)
            }
            .refreshable { await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID, force: true) }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hola, \(firstName) 👋")
                .font(.title.weight(.bold))
                .foregroundStyle(CCColor.textPrimary)
            Text("Resumen de tu operación")
                .font(.subheadline)
                .foregroundStyle(CCColor.textSecondary)
        }
    }

    private var firstName: String {
        session.currentUser?.name.split(separator: " ").first.map(String.init) ?? "cliente"
    }

    // MARK: - Summary row (4 across)

    private var summaryRow: some View {
        HStack(spacing: CCSpacing.sm) {
            statButton(.inTransit) {
                CompactStatCard(value: viewModel.summary.inTransit, title: "En tránsito",
                                icon: "arrow.right.circle.fill", tint: ShipmentStatus.inTransit.color)
            }
            statButton(.atOrigin) {
                CompactStatCard(value: viewModel.summary.atOrigin, title: "En origen",
                                icon: "shippingbox.fill", tint: ShipmentStatus.atOrigin.color)
            }
            statButton(.arrivingSoon) {
                CompactStatCard(value: viewModel.summary.arrivingSoon, title: "Próximos a arribar",
                                icon: "clock.fill", tint: ShipmentStatus.arrivingSoon.color)
            }
            statButton(.needsAttention) {
                CompactStatCard(value: viewModel.summary.needsAttention, title: "Requieren atención",
                                icon: "exclamationmark.triangle.fill", tint: ShipmentStatus.needsAttention.color)
            }
        }
    }

    private func statButton<Content: View>(_ filter: ShipmentFilter,
                                           @ViewBuilder content: () -> Content) -> some View {
        Button {
            session.shipmentFilter = filter
            session.selectedTab = .shipments
        } label: {
            content()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Critical alerts

    private var criticalAlertsSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            HStack(spacing: CCSpacing.sm) {
                Text("Alertas críticas")
                    .font(.headline)
                    .foregroundStyle(CCColor.textPrimary)
                if viewModel.criticalCount > 0 {
                    Text("\(viewModel.criticalCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(CCColor.red)
                        .clipShape(Circle())
                }
                Spacer()
                Button("Ver todas") { session.selectedTab = .alerts }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CCColor.actionBlue)
            }

            if viewModel.criticalShippingAlerts.isEmpty {
                emptyCard(icon: "checkmark.circle.fill",
                          tint: CCColor.green,
                          message: "Sin alertas críticas por ahora.")
            } else {
                ForEach(viewModel.criticalShippingAlerts) { alert in
                    NavigationLink(value: alert.shippingId) {
                        ShippingAlertRow(alert: alert, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Upcoming events

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: CCSpacing.md) {
            Text("Próximos eventos")
                .font(.headline)
                .foregroundStyle(CCColor.textPrimary)

            if viewModel.upcomingEvents.isEmpty {
                VStack(spacing: CCSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(CCColor.actionBlue.opacity(0.08))
                            .frame(width: 64, height: 64)
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(CCColor.navy.opacity(0.45))
                    }
                    VStack(spacing: 4) {
                        Text("Sin eventos próximos")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CCColor.textPrimary)
                        Text("No hay eventos programados\npara tus embarques activos.")
                            .font(.caption)
                            .foregroundStyle(CCColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CCSpacing.xl)
                .ccCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.upcomingEvents.enumerated()), id: \.element.id) { index, event in
                        if let shippingId = event.shippingId {
                            NavigationLink(value: shippingId) {
                                eventRow(event)
                            }
                            .buttonStyle(.plain)
                        } else {
                            eventRow(event)
                        }
                        if index < viewModel.upcomingEvents.count - 1 {
                            Divider().overlay(CCColor.border)
                        }
                    }
                }
                .ccCard()
            }
        }
    }

    private func eventRow(_ event: UpcomingEvent) -> some View {
        HStack(alignment: .center, spacing: CCSpacing.md) {
            // Transport mode icon
            Image(systemName: event.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CCColor.navy)
                .frame(width: 46, height: 46)
                .background(CCColor.actionBlue.opacity(0.10))
                .clipShape(Circle())

            // Folio · event description · route
            VStack(alignment: .leading, spacing: 3) {
                Text(event.refCode)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CCColor.textPrimary)
                    .lineLimit(1)
                Text(event.eventDescription)
                    .font(.footnote)
                    .foregroundStyle(CCColor.textSecondary)
                    .lineLimit(1)
                if let pol = event.pol, let pod = event.pod {
                    Text("\(pol) → \(pod)")
                        .font(.caption)
                        .foregroundStyle(CCColor.textSecondary)
                        .lineLimit(1)
                } else if let pol = event.pol {
                    Text(pol)
                        .font(.caption)
                        .foregroundStyle(CCColor.textSecondary)
                        .lineLimit(1)
                } else if let pod = event.pod {
                    Text(pod)
                        .font(.caption)
                        .foregroundStyle(CCColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Days until event · relevant date (ETD or ETA)
            VStack(alignment: .trailing, spacing: 3) {
                Text(daysLabel(event))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CCColor.textPrimary)
                    .lineLimit(1)
                Text(CCFormat.shortDay(relevantDate(event)))
                    .font(.caption)
                    .foregroundStyle(CCColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, CCSpacing.md)
    }

    /// "Dentro de X días" using API value; falls back to computing from eventDate.
    private func daysLabel(_ event: UpcomingEvent) -> String {
        if let days = event.daysUntilEvent {
            if days == 0 { return "Hoy" }
            if days == 1 { return "Mañana" }
            return "Dentro de \(days) días"
        }
        return CCFormat.relativeDay(event.eventDate)
    }

    /// Prefers ETD for departure events, ETA for arrival; falls back to eventDate.
    private func relevantDate(_ event: UpcomingEvent) -> Date {
        let desc = event.eventDescription.lowercased()
        if desc.contains("arriv") || desc.contains("llegad") || desc.contains("arrival") {
            return event.eta ?? event.eventDate
        }
        if desc.contains("depart") || desc.contains("salid") || desc.contains("etd") {
            return event.etd ?? event.eventDate
        }
        return event.etd ?? event.eta ?? event.eventDate
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Official brand lockup (one-line), leading.
        // The shared glass capsule is hidden so the logo sits directly
        // on the background instead of inside a pill.
        ToolbarItem(placement: .topBarLeading) {
            Image("LogoMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(CCColor.navy)
                .accessibilityLabel("Continente Cargo")
        }
        .sharedBackgroundVisibility(.hidden)

        // Bell with critical-alerts badge → jumps to the Alertas tab.
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                session.selectedTab = .alerts
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(CCColor.textPrimary)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.criticalCount > 0 {
                            Text("\(viewModel.criticalCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 15, height: 15)
                                .background(CCColor.red)
                                .clipShape(Circle())
                                .offset(x: 7, y: -6)
                        }
                    }
            }
        }

        // Avatar menu with sign-out.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) { session.signOut() } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Text(session.currentUser?.initials ?? "CC")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(CCColor.navy)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Helpers

    private func emptyCard(icon: String, tint: Color, message: String) -> some View {
        HStack(spacing: CCSpacing.md) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(CCColor.textSecondary)
            Spacer()
        }
        .ccCard()
    }

}

#Preview {
    HomeView()
        .environment(AppSession())
        .environment(HomeViewModel())
}
