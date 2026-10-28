import Testing
@testable import Continente_Conecta

// Tests for AppUser.coversLoad() — the core carrier-to-load matching algorithm.
// This logic decides which loads a carrier sees in CarrierHomeView.
@Suite("AppUser Coverage Logic")
struct UserCoverageTests {

    private func carrier(
        routes: [CarrierRoute] = [],
        handlesLTL: Bool = false,
        handlesLocal: Bool = false,
        handlesIntraState: Bool = false,
        coversUSA: Bool = false,
        coverageZones: [MexicanZone] = [],
        coverageStates: [String] = [],
        coverageEquipmentTypes: [EquipmentType] = [],
        coverageUSAStates: [String] = []
    ) -> AppUser {
        AppUser(
            name: "Test Carrier", email: "t@test.com", phone: "1234567890",
            role: .carrier, status: .approved,
            routes: routes,
            handlesLTL: handlesLTL,
            handlesLocal: handlesLocal,
            handlesIntraState: handlesIntraState,
            coversUSA: coversUSA,
            coverageZones: coverageZones,
            coverageStates: coverageStates,
            coverageEquipmentTypes: coverageEquipmentTypes,
            coverageUSAStates: coverageUSAStates
        )
    }

    // MARK: - Route Mode (explicit origin→destination pairs)

    @Test("Route mode: NL→CDMX explicit route matches NL→CDMX load")
    func routeExplicitForwardMatch() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: false)])
        #expect(c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("Route mode: unidirectional NL→CDMX does NOT match CDMX→NL")
    func routeUnidirectionalRejectsReverse() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: false)])
        #expect(!c.coversLoad(originState: "CDMX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("Route mode: bidirectional NL↔CDMX matches CDMX→NL direction")
    func routeBidirectionalMatchesReverse() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)])
        #expect(c.coversLoad(originState: "CDMX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("Route mode: equipment filter rejects mismatched equipment type")
    func routeEquipmentFilterRejects() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX",
                                              bidirectional: true, equipmentTypes: [.flatbed])])
        #expect(!c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("Route mode: empty equipment list matches any equipment")
    func routeEmptyEquipmentMatchesAll() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX",
                                              bidirectional: true, equipmentTypes: [])])
        for eq in EquipmentType.allCases {
            #expect(c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: eq),
                    "Expected \(eq.rawValue) to match empty equipment filter")
        }
    }

    @Test("Route mode: unrelated route does not match different states")
    func routeDoesNotMatchUnrelatedRoute() {
        let c = carrier(routes: [CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)])
        #expect(!c.coversLoad(originState: "Jalisco", destinationState: "Sonora", equipmentType: .dryBox53))
    }

    // MARK: - State Mode (coverage by individual states)

    @Test("State mode: both endpoints covered → match")
    func stateModeCoversLoad() {
        let c = carrier(coverageStates: ["N.L.", "CDMX"])
        #expect(c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("State mode: only origin covered → no match")
    func stateModeOnlyOriginCoveredRejects() {
        let c = carrier(coverageStates: ["N.L."])
        #expect(!c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("State mode: equipment type filter applies")
    func stateModeEquipmentFilterApplies() {
        let c = carrier(coverageStates: ["N.L.", "CDMX"], coverageEquipmentTypes: [.flatbed])
        #expect(!c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
        #expect(c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .flatbed))
    }

    // MARK: - Zone Mode (coverage by geographic zone)

    @Test("Zone mode: Norte + Centro zones cover N.L.→CDMX interstate")
    func zoneModeCoversInterstate() {
        let c = carrier(coverageZones: [.norte, .centro])
        #expect(c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("Zone mode: unrelated zones do not cover a route outside those zones")
    func zoneModeRejectsUnrelatedRoute() {
        let c = carrier(coverageZones: [.noroeste])
        #expect(!c.coversLoad(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    // MARK: - Local delivery (same city)

    @Test("handlesLocal=true matches same-city same-state load")
    func handlesLocalMatchesSameCity() {
        let c = carrier(handlesLocal: true)
        #expect(c.coversLoad(originCity: "Monterrey", originState: "N.L.",
                             destinationCity: "Monterrey", destinationState: "N.L.",
                             equipmentType: .rabon))
    }

    @Test("handlesLocal=false rejects same-city same-state load")
    func handlesLocalFalseRejectsSameCity() {
        let c = carrier(handlesLocal: false)
        #expect(!c.coversLoad(originCity: "Monterrey", originState: "N.L.",
                              destinationCity: "Monterrey", destinationState: "N.L.",
                              equipmentType: .rabon))
    }

    @Test("handlesLocal=true does NOT match different cities in same state")
    func handlesLocalDoesNotCoverIntraState() {
        let c = carrier(handlesLocal: true)
        #expect(!c.coversLoad(originCity: "Monterrey", originState: "N.L.",
                              destinationCity: "Linares", destinationState: "N.L.",
                              equipmentType: .rabon))
    }

    // MARK: - Intra-state delivery (different cities, same state)

    @Test("handlesIntraState=true matches different cities in same state")
    func handlesIntraStateMatchesDifferentCitiesSameState() {
        let c = carrier(handlesIntraState: true)
        #expect(c.coversLoad(originCity: "Monterrey", originState: "N.L.",
                             destinationCity: "Linares", destinationState: "N.L.",
                             equipmentType: .rabon))
    }

    @Test("handlesIntraState=false rejects different cities in same state")
    func handlesIntraStateFalseRejects() {
        let c = carrier(handlesIntraState: false)
        #expect(!c.coversLoad(originCity: "Monterrey", originState: "N.L.",
                              destinationCity: "Linares", destinationState: "N.L.",
                              equipmentType: .rabon))
    }

    // MARK: - USA coverage

    @Test("coversUSA=false always rejects US-endpoint load")
    func noUSAFlagRejectsUSLoad() {
        let c = carrier(coversUSA: false)
        #expect(!c.coversLoad(originState: "TX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("coversUSA=true with explicit route covers that cross-border route")
    func coversUSAWithRouteMatchesCrossBorder() {
        let c = carrier(
            routes: [CarrierRoute(originState: "TX", destinationState: "N.L.", bidirectional: true)],
            coversUSA: true
        )
        #expect(c.coversLoad(originState: "TX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("coversUSA=true with specific state list rejects unlisted US state")
    func coversUSAStateListRejectsUnlistedState() {
        let c = carrier(coversUSA: true, coverageUSAStates: ["TX"])
        #expect(!c.coversLoad(originState: "CA", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("Purely US-to-US load requires coversUSA flag")
    func purelyUSLoadRequiresCoversUSAFlag() {
        let withFlag = carrier(coversUSA: true, coverageUSAStates: ["TX", "NM"])
        let withoutFlag = carrier(coversUSA: false)
        #expect(withFlag.coversLoad(originState: "TX", destinationState: "NM", equipmentType: .dryBox53))
        #expect(!withoutFlag.coversLoad(originState: "TX", destinationState: "NM", equipmentType: .dryBox53))
    }
}
