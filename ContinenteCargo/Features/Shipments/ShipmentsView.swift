//
//  ShipmentsView.swift
//  ContinenteCargo
//
//  Searchable, filterable list of all shipments.
//

import SwiftUI

struct ShipmentsView: View {
    @Environment(AppSession.self) private var session
    @Environment(ShipmentsViewModel.self) private var viewModel
    @State private var navigationPath: [Int] = []

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: CCSpacing.md) {
                    Text("Embarques")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, CCSpacing.xs)

                    filterBar

                    if viewModel.isLoading {
                        LazyVStack(spacing: CCSpacing.md) {
                            ForEach(0..<6, id: \.self) { _ in
                                ShipmentCard(shipment: MockData.shipments[0])
                                    .redacted(reason: .placeholder)
                            }
                        }
                        .allowsHitTesting(false)
                    } else if viewModel.filteredShipments.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: CCSpacing.md) {
                            ForEach(viewModel.filteredShipments) { shipment in
                                if let shippingId = shipment.shippingId {
                                    NavigationLink(value: shippingId) {
                                        ShipmentCard(shipment: shipment)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: shipment) {
                                        ShipmentCard(shipment: shipment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if viewModel.hasNextPage || viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, CCSpacing.md)
                                    .onAppear {
                                        Task { await viewModel.loadNextPage() }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, CCSpacing.lg)
                .padding(.bottom, CCSpacing.lg)
            }
            .background(CCColor.surface.ignoresSafeArea())
            .navigationTitle("Embarques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CCColor.surface, for: .navigationBar, .tabBar)
            .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            .toolbarColorScheme(.light, for: .navigationBar, .tabBar)
            .searchable(text: $vm.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "BL, booking, contenedor, origen o destino")
            .navigationDestination(for: Shipment.self) { shipment in
                ShipmentDetailView(shipment: shipment)
            }
            .navigationDestination(for: Int.self) { shippingId in
                ShipmentDetailLoaderView(shippingId: shippingId)
            }
            .onChange(of: session.deepLinkShipmentID) { _, newID in
                guard let id = newID else { return }
                navigationPath.append(id)
                session.deepLinkShipmentID = nil
            }
            .task(id: session.authSession?.idToken) {
                await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID)
            }
            .onAppear {
                if let filter = session.shipmentFilter {
                    viewModel.filter = filter
                    session.shipmentFilter = nil
                }
            }
            .onChange(of: session.shipmentFilter) { _, newFilter in
                guard let filter = newFilter else { return }
                withAnimation(.smooth(duration: 0.2)) { viewModel.filter = filter }
                session.shipmentFilter = nil
            }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.onSearchChanged() }
            .refreshable { await viewModel.load(idToken: session.authSession?.idToken, clientID: session.clientID, force: true) }
        }
    }

    // MARK: - Filter bar

    /// Underlined text tabs with per-status counters, per the brand mockup.
    private var filterBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CCSpacing.xl) {
                    ForEach(ShipmentFilter.allCases) { option in
                        FilterTab(title: option.title,
                                  count: viewModel.count(for: option),
                                  isSelected: viewModel.filter == option) {
                            withAnimation(.smooth(duration: 0.2)) { viewModel.filter = option }
                        }
                        .id(option)
                    }
                }
                .padding(.top, CCSpacing.sm)
            }
            .scrollClipDisabled()
            .onChange(of: viewModel.filter) { _, newFilter in
                withAnimation(.smooth(duration: 0.3)) {
                    proxy.scrollTo(newFilter, anchor: .center)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin resultados", systemImage: "shippingbox")
        } description: {
            Text("No encontramos embarques con esos criterios.")
        }
        .padding(.top, CCSpacing.xxxl)
    }
}

#Preview {
    ShipmentsView()
        .environment(AppSession())
        .environment(ShipmentsViewModel())
}
