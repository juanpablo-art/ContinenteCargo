import Testing
@testable import Continente_Conecta

// AppStore runs in the app host process (BUNDLE_LOADER). Firebase is NOT configured,
// so AppStore.init() returns early (XCTestBundlePath env var detected) leaving the
// store empty. Tests seed it manually via DemoDataService.seed(into:).
@Suite("AppStore Queries")
@MainActor
struct AppStoreQueryTests {

    // MARK: - Open loads panel

    @Test("Open loads contain only published, non-full loads without an assigned carrier")
    func openLoadsCriteria() {
        let store = AppStore()
        DemoDataService.seed(into: store)

        let openLoads = store.loads.filter {
            $0.status == .published && $0.assignedCarrierId == nil && !$0.isFull
        }
        for load in openLoads {
            #expect(load.status == .published)
            #expect(load.assignedCarrierId == nil)
            #expect(!load.isFull)
        }
    }

    // MARK: - loadsForCurrentUser (carrier)

    @Test("Carrier sees only loads matching their explicit routes when status is published")
    func carrierSeesOnlyMatchingRouteLoads() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }
        store.currentUser = carrier

        let visible = store.loadsForCurrentUser()
        let publishedVisible = visible.filter { $0.status == .published && !$0.isFull }

        for load in publishedVisible {
            guard load.assignmentMode != .ltlConsolidated else { continue }
            let matches = carrier.coversLoad(
                originCity: load.originCity, originState: load.originState,
                destinationCity: load.destinationCity, destinationState: load.destinationState,
                equipmentType: load.equipmentType
            )
            #expect(matches, "Load \(load.reference) should match carrier routes but was shown")
        }
    }

    @Test("Carrier always sees loads they are already confirmed on regardless of coverage")
    func carrierSeesOwnConfirmedLoads() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }

        // Inject a load confirmed to carrierId1 for a route they do NOT normally cover
        var uncoveredLoad = Load(
            reference: "UNCOVERED-001",
            originCity: "Mérida", originState: "Yucatán",
            destinationCity: "Ensenada", destinationState: "B.C.",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .flatbed, weightKg: 5000,
            merchandiseDescription: "Carga test",
            offeredPrice: 25_000,
            assignmentMode: .fixedRate,
            deadline: Date().addingTimeInterval(3600),
            publishedBy: DemoDataService.adminId
        )
        uncoveredLoad.status = .assigned
        uncoveredLoad.confirmedCarrierIds = [carrier.id]
        store.loads.append(uncoveredLoad)
        store.currentUser = carrier

        let visible = store.loadsForCurrentUser()
        #expect(visible.contains(where: { $0.id == uncoveredLoad.id }),
                "Carrier should always see loads they're confirmed on")
    }

    // MARK: - LTL filtering

    @Test("LTL loads are hidden from carrier with handlesLTL=false")
    func ltlLoadsHiddenFromNonLTLCarrier() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard var carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }
        carrier.handlesLTL = false
        store.currentUser = carrier

        // Add a published LTL load
        var ltl = Load(
            reference: "LTL-HIDDEN-001",
            originCity: "Monterrey", originState: "N.L.",
            destinationCity: "Ciudad de México", destinationState: "CDMX",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .dryBox53, weightKg: 2000,
            merchandiseDescription: "Consolidado",
            offeredPrice: 3_500,
            assignmentMode: .ltlConsolidated,
            deadline: Date().addingTimeInterval(7200),
            publishedBy: DemoDataService.adminId
        )
        store.loads.append(ltl)

        let visible = store.loadsForCurrentUser()
        let ltlVisible = visible.filter { $0.id == ltl.id }
        #expect(ltlVisible.isEmpty, "Non-LTL carrier must not see LTL loads")
    }

    @Test("LTL loads ARE visible to carrier with handlesLTL=true")
    func ltlLoadsVisibleToLTLCarrier() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard var carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }
        carrier.handlesLTL = true
        store.currentUser = carrier

        var ltl = Load(
            reference: "LTL-VISIBLE-001",
            originCity: "Monterrey", originState: "N.L.",
            destinationCity: "Ciudad de México", destinationState: "CDMX",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .dryBox53, weightKg: 2000,
            merchandiseDescription: "Consolidado",
            offeredPrice: 3_500,
            assignmentMode: .ltlConsolidated,
            deadline: Date().addingTimeInterval(7200),
            publishedBy: DemoDataService.adminId
        )
        store.loads.append(ltl)

        let visible = store.loadsForCurrentUser()
        #expect(visible.contains(where: { $0.id == ltl.id }),
                "LTL carrier should see published LTL loads")
    }

    // MARK: - Unit slot refusal

    @Test("Full multi-unit load is not open for a carrier to take")
    func fullLoadNotOpenForCarrier() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }
        store.currentUser = carrier

        var full = Load(
            reference: "FULL-MULTI-001",
            originCity: "Monterrey", originState: "N.L.",
            destinationCity: "Ciudad de México", destinationState: "CDMX",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .dryBox53, unitCount: 3, weightKg: 10_000,
            merchandiseDescription: "Multi-unit",
            offeredPrice: 15_000,
            assignmentMode: .fixedRate,
            deadline: Date().addingTimeInterval(3600),
            publishedBy: DemoDataService.adminId
        )
        full.confirmedUnitCount = 3
        store.loads.append(full)

        #expect(full.isFull, "Load with confirmedUnitCount == unitCount should be full")
        #expect(!full.isOpen, "Full load should not be open")
    }

    // MARK: - Pricer queries

    @Test("carriersForPricer returns only carriers whose pricerId matches the current pricer")
    func carriersForPricerMatchesPricerId() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let pricer = store.users.first(where: { $0.id == DemoDataService.pricerId1 }) else {
            Issue.record("Demo pricer not found"); return
        }
        store.currentUser = pricer

        let carriers = store.carriersForPricer()
        for c in carriers {
            #expect(c.pricerId == pricer.id,
                    "Carrier \(c.name) should have pricerId matching the pricer")
        }
    }

    @Test("loadsForPricer includes all published loads (any carrier can work them)")
    func loadsForPricerIncludesAllPublished() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let pricer = store.users.first(where: { $0.id == DemoDataService.pricerId1 }) else {
            Issue.record("Demo pricer not found"); return
        }
        store.currentUser = pricer

        let pricerLoads = store.loadsForPricer()
        let publishedLoads = store.loads.filter { $0.status == .published }

        for load in publishedLoads {
            #expect(pricerLoads.contains(where: { $0.id == load.id }),
                    "Pricer should see published load \(load.reference)")
        }
    }

    // MARK: - myTrips

    @Test("myTrips includes loads where carrier is in confirmedCarrierIds")
    func myTripsIncludesConfirmedCarrierLoads() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }

        var trip = Load(
            reference: "MYTRIP-001",
            originCity: "Monterrey", originState: "N.L.",
            destinationCity: "Ciudad de México", destinationState: "CDMX",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .dryBox53, weightKg: 10_000,
            merchandiseDescription: "Trip test",
            offeredPrice: 15_000,
            assignmentMode: .fixedRate,
            deadline: Date().addingTimeInterval(3600),
            publishedBy: DemoDataService.adminId
        )
        trip.status = .inTransit
        trip.confirmedCarrierIds = [carrier.id]
        store.loads.append(trip)
        store.currentUser = carrier

        let trips = store.myTrips()
        #expect(trips.contains(where: { $0.id == trip.id }),
                "myTrips should include loads where carrier is in confirmedCarrierIds")
    }

    @Test("myTrips includes loads won via a won offer")
    func myTripsIncludesWonOfferLoads() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }

        var wonLoad = Load(
            reference: "WONOFFER-001",
            originCity: "Guadalajara", originState: "Jalisco",
            destinationCity: "Tijuana", destinationState: "B.C.",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .flatbed, weightKg: 8000,
            merchandiseDescription: "Won offer test",
            offeredPrice: 22_000,
            assignmentMode: .reverseAuction,
            deadline: Date().addingTimeInterval(3600),
            publishedBy: DemoDataService.adminId
        )
        wonLoad.status = .assigned
        store.loads.append(wonLoad)

        var wonOffer = Offer(
            loadId: wonLoad.id,
            carrierId: carrier.id,
            carrierName: carrier.name,
            amount: 20_000
        )
        wonOffer.status = .won
        store.offers.append(wonOffer)
        store.currentUser = carrier

        let trips = store.myTrips()
        #expect(trips.contains(where: { $0.id == wonLoad.id }),
                "myTrips should include loads the carrier won via an offer")
    }

    // MARK: - myOffers

    @Test("myOffers returns only offers with pending statuses (active/winning/outbid/pendingApproval)")
    func myOffersExcludesTerminalStatuses() {
        let store = AppStore()
        DemoDataService.seed(into: store)
        guard let carrier = store.users.first(where: { $0.id == DemoDataService.carrierId1 }) else {
            Issue.record("Demo carrier1 not found"); return
        }
        store.currentUser = carrier

        let offers = store.myOffers()
        let terminal: Set<OfferStatus> = [.won, .lost, .cancelled, .rejected]
        for offer in offers {
            #expect(!terminal.contains(offer.status),
                    "myOffers should exclude terminal status: \(offer.status.rawValue)")
        }
    }
}
