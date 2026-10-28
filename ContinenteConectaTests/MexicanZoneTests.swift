import Testing
@testable import Continente_Conecta

@Suite("Mexican Zone Logic")
struct MexicanZoneTests {

    // MARK: Known state → zone mappings

    @Test("Nuevo León maps to Norte")
    func nuevoLeonIsNorte() {
        #expect(MexicanZone.zone(for: "N.L.") == .norte)
    }

    @Test("CDMX maps to Centro")
    func cdmxIsCentro() {
        #expect(MexicanZone.zone(for: "CDMX") == .centro)
    }

    @Test("Jalisco maps to Centro Occidente")
    func jaliscoIsCentroOccidente() {
        #expect(MexicanZone.zone(for: "Jalisco") == .centroOccidente)
    }

    @Test("Sonora maps to Noroeste")
    func sonoraIsNoroeste() {
        #expect(MexicanZone.zone(for: "Sonora") == .noroeste)
    }

    @Test("Yucatán maps to Sureste")
    func yucatanIsSureste() {
        #expect(MexicanZone.zone(for: "Yucatán") == .sureste)
    }

    @Test("Veracruz maps to Sur")
    func veracruzIsSur() {
        #expect(MexicanZone.zone(for: "Veracruz") == .sur)
    }

    // MARK: Completeness

    @Test("Every MexicanState maps to exactly one zone")
    func allStatesHaveAZone() {
        for state in MexicanState.allCases {
            #expect(MexicanZone.zone(for: state.rawValue) != nil,
                    "State \(state.rawValue) should map to a zone")
        }
    }

    @Test("Every zone contains at least two states")
    func eachZoneHasMultipleStates() {
        for zone in MexicanZone.allCases {
            #expect(zone.states.count >= 2,
                    "Zone \(zone.rawValue) should have at least 2 states")
        }
    }

    @Test("Zone stateNames are the rawValues of their states")
    func zoneStateNamesMatchRawValues() {
        for zone in MexicanZone.allCases {
            #expect(zone.stateNames == zone.states.map { $0.rawValue })
        }
    }

    @Test("No state appears in more than one zone")
    func noStateDuplicated() {
        var seen: Set<String> = []
        for zone in MexicanZone.allCases {
            for state in zone.stateNames {
                #expect(!seen.contains(state), "State \(state) appears in multiple zones")
                seen.insert(state)
            }
        }
    }

    @Test("Zone.contains(state:) works for known member")
    func zoneContainsKnownMember() {
        #expect(MexicanZone.norte.contains(state: "N.L."))
    }

    @Test("Zone.contains(state:) returns false for non-member")
    func zoneDoesNotContainNonMember() {
        #expect(!MexicanZone.norte.contains(state: "Jalisco"))
    }

    // MARK: USAZone completeness

    @Test("Every USState maps to exactly one USAZone")
    func allUSStatesHaveAZone() {
        for state in USState.allCases {
            #expect(USAZone.zone(for: state.rawValue) != nil,
                    "US state \(state.rawValue) should map to a zone")
        }
    }
}
