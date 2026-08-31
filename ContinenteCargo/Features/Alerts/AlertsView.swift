//
//  AlertsView.swift
//  ContinenteCargo
//
//  Detected problems across the operation, served by the Continente API
//  (GET /api/Client/shipping/alerts). Uses the same underlined filter-tab
//  pattern as the Embarques list for a consistent app feel.
//

import SwiftUI

struct AlertsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AlertsViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CCSpacing.md) {
                    Text("Alertas")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, CCSpacing.xs)

                    filterBar

                    if viewModel.isLoading {
                        LazyVStack(spacing: CCSpacing.md) {
                            ForEach(0..<5, id: \.self) { _ in
                                ShippingAlertRow(alert: Self.placeholderAlert, showsChevron: true)
                                    .redacted(reason: .placeholder)
                            }
                        }
                        .allowsHitTesting(false)
                    } else if viewModel.filteredAlerts.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: CCSpacing.md) {
                            ForEach(viewModel.filteredAlerts) { alert in
                                alertLink(for: alert)
                                    .task { await viewModel.loadMoreIfNeeded(after: alert) }
                            }
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, CCSpacing.md)
                            }
                        }
                    }
                }
                .padding(.horizontal, CCSpacing.lg)
                .padding(.bottom, CCSpacing.lg)
            }
            .background(CCColor.surface.ignoresSafeArea())
            .navigationTitle("Alertas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CCColor.surface, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Folio, contenedor, origen o destino")
            .navigationDestination(for: Int.self) { shippingId in
                ShipmentDetailLoaderView(shippingId: shippingId)
            }
            .navigationDestination(for: Shipment.self) { shipment in
                ShipmentDetailView(shipment: shipment)
            }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.onSearchChanged() }
            .task(id: session.authSession?.idToken) {
                await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID)
            }
            .refreshable { await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID, force: true) }
        }
    }

    private func alertLink(for alert: ShippingAlert) -> some View {
        NavigationLink(value: alert.shippingId) {
            ShippingAlertRow(alert: alert, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter bar

    /// Same underlined tabs as the Embarques list.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CCSpacing.xl) {
                ForEach(AlertFilter.allCases) { option in
                    FilterTab(title: option.title,
                              count: viewModel.count(for: option),
                              isSelected: viewModel.filter == option) {
                        withAnimation(.smooth(duration: 0.2)) { viewModel.filter = option }
                    }
                }
            }
            .padding(.top, CCSpacing.sm)
        }
        .scrollClipDisabled()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin alertas", systemImage: "checkmark.seal.fill")
        } description: {
            Text("Tu operación no tiene problemas detectados.")
        }
        .padding(.top, CCSpacing.xxxl)
    }

    // MARK: - Skeleton placeholder

    private static let placeholderAlert = ShippingAlert(
        shippingId: 0,
        transportation: "Marítimo",
        reasons: [AlertReason(code: nil, severity: "critical", description: nil)],
        refCode: "CC-0000-PLACEHOLDER",
        refNumber: nil,
        pol: "ORIGEN",
        pod: "DESTINO",
        containers: [APIContainer(containerNumber: "XXXX0000000", containerType: nil, quantity: nil)],
        etdDelayDays: nil,
        etaDelayDays: nil,
        updatedAt: nil
    )
}

#Preview {
    AlertsView()
        .environment(AppSession())
        .environment(AlertsViewModel())
}
