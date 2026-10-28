import Testing
@testable import Continente_Conecta

@Suite("CarrierRoute Matching")
struct CarrierRouteTests {

    @Test("Unidirectional route matches correct direction")
    func unidirectionalForwardMatch() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: false)
        #expect(route.matches(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("Unidirectional route rejects reverse direction")
    func unidirectionalReverseReject() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: false)
        #expect(!route.matches(originState: "CDMX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("Bidirectional route matches forward direction")
    func bidirectionalForwardMatch() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)
        #expect(route.matches(originState: "N.L.", destinationState: "CDMX", equipmentType: .dryBox53))
    }

    @Test("Bidirectional route matches reverse direction")
    func bidirectionalReverseMatch() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)
        #expect(route.matches(originState: "CDMX", destinationState: "N.L.", equipmentType: .dryBox53))
    }

    @Test("Equipment filter allows listed equipment type")
    func equipmentFilterAllowsMatch() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX",
                                 bidirectional: true, equipmentTypes: [.dryBox53, .flatbed])
        #expect(route.matches(originState: "N.L.", destinationState: "CDMX", equipmentType: .flatbed))
    }

    @Test("Equipment filter rejects unlisted equipment type")
    func equipmentFilterRejectsMismatch() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX",
                                 bidirectional: true, equipmentTypes: [.dryBox53])
        #expect(!route.matches(originState: "N.L.", destinationState: "CDMX", equipmentType: .refrigerated))
    }

    @Test("Empty equipment list matches every equipment type")
    func emptyEquipmentMatchesAll() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX",
                                 bidirectional: true, equipmentTypes: [])
        for equipment in EquipmentType.allCases {
            #expect(route.matches(originState: "N.L.", destinationState: "CDMX", equipmentType: equipment),
                    "Empty equipment filter should accept \(equipment.rawValue)")
        }
    }

    @Test("Route does not match completely different state pair")
    func routeDoesNotMatchDifferentStates() {
        let route = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)
        #expect(!route.matches(originState: "Jalisco", destinationState: "Sonora", equipmentType: .dryBox53))
    }

    @Test("display string uses → for unidirectional and ↔ for bidirectional")
    func displayStringFormat() {
        let uni = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: false)
        let bi  = CarrierRoute(originState: "N.L.", destinationState: "CDMX", bidirectional: true)
        #expect(uni.display.contains("→"))
        #expect(bi.display.contains("↔"))
    }
}
