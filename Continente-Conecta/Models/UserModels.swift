import Foundation
import SwiftUI

// MARK: - Enums

enum UserRole: String, Codable, CaseIterable {
    case admin = "admin"
    case carrier = "carrier"
    case independentOperator = "independent_operator"
    case pricer = "pricer"
}

enum UserStatus: String, Codable {
    case pendingApproval = "pending_approval"
    case approved = "approved"
    case rejected = "rejected"
    case suspended = "suspended"

    var displayName: String {
        switch self {
        case .pendingApproval: return "Pendiente de aprobación"
        case .approved:        return "Aprobado"
        case .rejected:        return "Rechazado"
        case .suspended:       return "Suspendido"
        }
    }
}

// MARK: - Carrier Route

struct CarrierRoute: Identifiable, Codable, Hashable {
    var id: UUID
    var originState: String
    var destinationState: String
    var bidirectional: Bool
    var equipmentTypes: [EquipmentType]  // equipo que opera en esta ruta específica

    var display: String {
        bidirectional
            ? "\(originState) ↔ \(destinationState)"
            : "\(originState) → \(destinationState)"
    }

    var equipmentDisplay: String {
        equipmentTypes.isEmpty ? "Cualquier equipo" : equipmentTypes.map { $0.rawValue }.joined(separator: ", ")
    }

    func matches(originState: String, destinationState: String, equipmentType: EquipmentType) -> Bool {
        let stateMatch: Bool
        if self.originState == originState && self.destinationState == destinationState {
            stateMatch = true
        } else if bidirectional && self.originState == destinationState && self.destinationState == originState {
            stateMatch = true
        } else {
            stateMatch = false
        }
        guard stateMatch else { return false }
        return equipmentTypes.isEmpty || equipmentTypes.contains(equipmentType)
    }

    init(id: UUID = UUID(), originState: String, destinationState: String,
         bidirectional: Bool = true, equipmentTypes: [EquipmentType] = []) {
        self.id = id
        self.originState = originState
        self.destinationState = destinationState
        self.bidirectional = bidirectional
        self.equipmentTypes = equipmentTypes
    }
}

// MARK: - User

struct AppUser: Identifiable, Codable {
    var id: UUID
    var name: String
    var email: String
    var phone: String
    var role: UserRole
    var status: UserStatus
    var companyId: UUID?
    var canNegotiateRates: Bool
    /// Rutas que el transportista corre (pares origen-destino).
    var routes: [CarrierRoute]
    /// El carrier también opera cargas LTL (consolidado).
    var handlesLTL: Bool
    /// Opera entregas dentro de la misma ciudad (origen y destino en la misma ciudad).
    var handlesLocal: Bool
    /// Opera entre ciudades del mismo estado (Monterrey ↔ Linares, ambos N.L.).
    var handlesIntraState: Bool
    /// El transportista cubre rutas con origen o destino en Estados Unidos.
    var coversUSA: Bool
    /// Zonas geográficas de cobertura (legacy — usar coverageStates).
    var coverageZones: [MexicanZone]
    /// Estados individuales de cobertura (nuevo — reemplaza coverageZones).
    var coverageStates: [String]
    /// Tipos de equipo para cobertura por zona (vacío = cualquier equipo).
    var coverageEquipmentTypes: [EquipmentType]
    /// Estados de EE.UU. de cobertura (códigos de 2 letras: "TX", "CA"…).
    /// Vacío con coversUSA=true → cubre todo EE.UU.
    var coverageUSAStates: [String]
    /// Correos adicionales donde llegan notificaciones (además del email principal).
    var notificationEmails: [String]
    /// Números celulares con WhatsApp para recibir alertas.
    var whatsappNumbers: [String]
    /// UUID del pricer asignado a este transportista (solo aplica a carriers/operators).
    var pricerId: UUID?
    /// Raw Firestore pricerId string (Firebase Auth UID of the assigned pricer). Populated at parse time.
    var pricerRawId: String = ""
    /// Email of the assigned pricer when stamped on the user doc (web rankPricers also matches on this).
    var pricerEmail: String = ""
    var createdAt: Date
    /// Firebase Auth UID (Firestore document ID). Populated at runtime from the document ID, not stored in the document itself.
    var firebaseUID: String = ""

    var isApproved: Bool { status == .approved }
    var isPending: Bool { status == .pendingApproval }

    /// Three service tiers: local (same city), intra-state (same state / different city), interstate.
    /// US loads (2-letter state codes like "TX") are matched via coversUSA + coverageUSAStates.
    /// Routes (explicit mode) always override flag-based matching for Mexican routes.
    func coversLoad(originCity: String = "", originState: String,
                    destinationCity: String = "", destinationState: String,
                    equipmentType: EquipmentType) -> Bool {

        let originIsUSA = USState(rawValue: originState) != nil
        let destIsUSA   = USState(rawValue: destinationState) != nil

        // Any route with a US end requires the coversUSA flag
        if originIsUSA || destIsUSA {
            guard coversUSA else { return false }

            if originIsUSA && destIsUSA {
                // Purely US-to-US: check specific state coverage
                if coverageUSAStates.isEmpty { return true }
                return coverageUSAStates.contains(originState) && coverageUSAStates.contains(destinationState)
            }

            // Cross-border: check that the US state is covered (if specific states configured)
            let usaState = originIsUSA ? originState : destinationState
            if !coverageUSAStates.isEmpty && !coverageUSAStates.contains(usaState) {
                return false
            }
            // Route mode handles cross-border explicitly
            if !routes.isEmpty {
                return routes.contains { $0.matches(originState: originState,
                                                    destinationState: destinationState,
                                                    equipmentType: equipmentType) }
            }
            // coversUSA + US state covered + no route restriction = match
            return true
        }

        // Route mode: explicit routes take full precedence including same-state routes
        if !routes.isEmpty {
            return routes.contains { $0.matches(originState: originState,
                                                destinationState: destinationState,
                                                equipmentType: equipmentType) }
        }

        let isSameState = originState == destinationState

        if isSameState {
            // Distinguish local (same city) vs intra-state (different cities, same state)
            let citiesKnown = !originCity.isEmpty && !destinationCity.isEmpty
            let isSameCity = citiesKnown && originCity.lowercased() == destinationCity.lowercased()
            return isSameCity ? handlesLocal : handlesIntraState
        }

        // Interstate: zone/state coverage matching
        if !coverageStates.isEmpty {
            guard coverageStates.contains(originState) && coverageStates.contains(destinationState) else {
                return false
            }
            return coverageEquipmentTypes.isEmpty || coverageEquipmentTypes.contains(equipmentType)
        }
        if !coverageZones.isEmpty {
            let originZone = MexicanZone.zone(for: originState)
            let destZone   = MexicanZone.zone(for: destinationState)
            let coversOrigin = originZone.map { coverageZones.contains($0) } ?? false
            let coversDest   = destZone.map   { coverageZones.contains($0) } ?? false
            guard coversOrigin || coversDest else { return false }
            return coverageEquipmentTypes.isEmpty || coverageEquipmentTypes.contains(equipmentType)
        }
        return true
    }

    /// Equipment types from routes (route mode) or zone equipment selection (zone mode).
    var allEquipmentTypes: [EquipmentType] {
        if !routes.isEmpty { return Array(Set(routes.flatMap { $0.equipmentTypes })) }
        return coverageEquipmentTypes
    }

    init(id: UUID = UUID(), name: String, email: String, phone: String,
         role: UserRole, status: UserStatus = .pendingApproval,
         companyId: UUID? = nil, canNegotiateRates: Bool = true,
         routes: [CarrierRoute] = [], handlesLTL: Bool = false,
         handlesLocal: Bool = false, handlesIntraState: Bool = false,
         coversUSA: Bool = false,
         coverageZones: [MexicanZone] = [], coverageStates: [String] = [],
         coverageEquipmentTypes: [EquipmentType] = [],
         coverageUSAStates: [String] = [],
         notificationEmails: [String] = [], whatsappNumbers: [String] = [],
         pricerId: UUID? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.role = role
        self.status = status
        self.companyId = companyId
        self.canNegotiateRates = canNegotiateRates
        self.routes = routes
        self.handlesLTL = handlesLTL
        self.handlesLocal = handlesLocal
        self.handlesIntraState = handlesIntraState
        self.coversUSA = coversUSA
        self.coverageZones = coverageZones
        self.coverageStates = coverageStates
        self.coverageEquipmentTypes = coverageEquipmentTypes
        self.coverageUSAStates = coverageUSAStates
        self.notificationEmails = notificationEmails
        self.whatsappNumbers = whatsappNumbers
        self.pricerId = pricerId
        self.createdAt = Date()
    }
}

// MARK: - Mexican states catalog

enum MexicanState: String, CaseIterable, Identifiable {
    case aguascalientes    = "Aguascalientes"
    case bajaCalifornia    = "B.C."
    case bajaCaliforniaSur = "B.C.S."
    case campeche          = "Campeche"
    case chiapas           = "Chiapas"
    case chihuahua         = "Chihuahua"
    case coahuila          = "Coahuila"
    case colima            = "Colima"
    case cdmx              = "CDMX"
    case durango           = "Durango"
    case estadoDeMexico    = "Estado de México"
    case guanajuato        = "Guanajuato"
    case guerrero          = "Guerrero"
    case hidalgo           = "Hidalgo"
    case jalisco           = "Jalisco"
    case michoacan         = "Michoacán"
    case morelos           = "Morelos"
    case nayarit           = "Nayarit"
    case nuevoLeon         = "N.L."
    case oaxaca            = "Oaxaca"
    case puebla            = "Puebla"
    case queretaro         = "Querétaro"
    case quintanaRoo       = "Quintana Roo"
    case sanLuisPotosi     = "S.L.P."
    case sinaloa           = "Sinaloa"
    case sonora            = "Sonora"
    case tabasco           = "Tabasco"
    case tamaulipas        = "Tamaulipas"
    case tlaxcala          = "Tlaxcala"
    case veracruz          = "Veracruz"
    case yucatan           = "Yucatán"
    case zacatecas         = "Zacatecas"

    var id: String { rawValue }
}

// MARK: - Mexican logistics zones

enum MexicanZone: String, CaseIterable, Identifiable, Codable {
    case noroeste        = "Noroeste"
    case norte           = "Norte"
    case bajio           = "Bajío"
    case centroOccidente = "Centro Occidente"
    case centro          = "Centro"
    case sur             = "Sur"
    case sureste         = "Sureste"

    var id: String { rawValue }

    var states: [MexicanState] {
        switch self {
        case .noroeste:        return [.bajaCalifornia, .bajaCaliforniaSur, .sonora, .sinaloa, .nayarit]
        case .norte:           return [.chihuahua, .coahuila, .durango, .nuevoLeon, .tamaulipas, .zacatecas]
        case .bajio:           return [.aguascalientes, .guanajuato, .queretaro, .sanLuisPotosi]
        case .centroOccidente: return [.jalisco, .colima, .michoacan]
        case .centro:          return [.cdmx, .estadoDeMexico, .hidalgo, .morelos, .puebla, .tlaxcala]
        case .sur:             return [.guerrero, .oaxaca, .veracruz]
        case .sureste:         return [.campeche, .chiapas, .quintanaRoo, .tabasco, .yucatan]
        }
    }

    var stateNames: [String] { states.map { $0.rawValue } }

    func contains(state: String) -> Bool { stateNames.contains(state) }

    static func zone(for state: String) -> MexicanZone? {
        allCases.first { $0.contains(state: state) }
    }

    var shortLabel: String {
        switch self {
        case .noroeste:        return "Noroeste"
        case .norte:           return "Norte"
        case .bajio:           return "Bajío"
        case .centroOccidente: return "C. Occ."
        case .centro:          return "Centro"
        case .sur:             return "Sur"
        case .sureste:         return "Sureste"
        }
    }

    // Distinct fill color for each zone (unselected state)
    var zoneColor: Color {
        switch self {
        case .noroeste:        return Color(red: 0.18, green: 0.52, blue: 0.80)
        case .norte:           return Color(red: 0.25, green: 0.60, blue: 0.48)
        case .bajio:           return Color(red: 0.76, green: 0.58, blue: 0.15)
        case .centroOccidente: return Color(red: 0.78, green: 0.30, blue: 0.22)
        case .centro:          return Color(red: 0.46, green: 0.26, blue: 0.72)
        case .sur:             return Color(red: 0.20, green: 0.60, blue: 0.42)
        case .sureste:         return Color(red: 0.82, green: 0.42, blue: 0.16)
        }
    }

    var labelAnchor: CGPoint {
        switch self {
        case .noroeste:        return CGPoint(x: 0.12, y: 0.25)
        case .norte:           return CGPoint(x: 0.62, y: 0.22)
        case .bajio:           return CGPoint(x: 0.44, y: 0.57)
        case .centroOccidente: return CGPoint(x: 0.22, y: 0.74)
        case .centro:          return CGPoint(x: 0.43, y: 0.74)
        case .sur:             return CGPoint(x: 0.29, y: 0.88)
        case .sureste:         return CGPoint(x: 0.80, y: 0.72)
        }
    }

    // Normalized polygons (0-1 space) designed for a 1.4:1 viewport.
    // Border tilts: (0,0) NW corner → (1,0.14) NE corner.
    // Sureste extends to NE to represent Gulf coast + Yucatán peninsula.
    // Shared vertices are exact matches to avoid gaps.
    var polygonPoints: [CGPoint] {
        switch self {
        case .noroeste:
            return [
                CGPoint(x:0.00, y:0.00), CGPoint(x:0.27, y:0.03),
                CGPoint(x:0.27, y:0.35), CGPoint(x:0.31, y:0.52),
                CGPoint(x:0.25, y:0.63), CGPoint(x:0.13, y:0.65),
                CGPoint(x:0.05, y:0.58), CGPoint(x:0.00, y:0.44),
            ]
        case .norte:
            return [
                CGPoint(x:0.27, y:0.03), CGPoint(x:1.00, y:0.14),
                CGPoint(x:0.90, y:0.44), CGPoint(x:0.65, y:0.50),
                CGPoint(x:0.47, y:0.52), CGPoint(x:0.31, y:0.52),
                CGPoint(x:0.27, y:0.35),
            ]
        case .bajio:
            return [
                CGPoint(x:0.31, y:0.52), CGPoint(x:0.47, y:0.52),
                CGPoint(x:0.65, y:0.50), CGPoint(x:0.63, y:0.62),
                CGPoint(x:0.46, y:0.68), CGPoint(x:0.34, y:0.66),
                CGPoint(x:0.25, y:0.63),
            ]
        case .centroOccidente:
            return [
                CGPoint(x:0.13, y:0.65), CGPoint(x:0.25, y:0.63),
                CGPoint(x:0.34, y:0.66), CGPoint(x:0.34, y:0.80),
                CGPoint(x:0.22, y:0.86), CGPoint(x:0.10, y:0.80),
            ]
        case .centro:
            return [
                CGPoint(x:0.34, y:0.66), CGPoint(x:0.46, y:0.68),
                CGPoint(x:0.58, y:0.73), CGPoint(x:0.48, y:0.80),
                CGPoint(x:0.38, y:0.84), CGPoint(x:0.34, y:0.80),
            ]
        case .sur:
            return [
                CGPoint(x:0.10, y:0.80), CGPoint(x:0.22, y:0.86),
                CGPoint(x:0.34, y:0.80), CGPoint(x:0.38, y:0.84),
                CGPoint(x:0.48, y:0.80), CGPoint(x:0.52, y:0.90),
                CGPoint(x:0.44, y:0.98), CGPoint(x:0.22, y:0.98),
                CGPoint(x:0.10, y:0.90),
            ]
        case .sureste:
            // Wraps up to (1.00,0.14) to show Gulf coast + Yucatán peninsula at bottom-right.
            return [
                CGPoint(x:0.46, y:0.68), CGPoint(x:0.63, y:0.62),
                CGPoint(x:0.65, y:0.50), CGPoint(x:0.90, y:0.44),
                CGPoint(x:1.00, y:0.14), CGPoint(x:1.00, y:0.84),
                CGPoint(x:0.88, y:0.95), CGPoint(x:0.70, y:1.00),
                CGPoint(x:0.55, y:1.00), CGPoint(x:0.52, y:0.90),
                CGPoint(x:0.48, y:0.80), CGPoint(x:0.58, y:0.73),
            ]
        }
    }
}

// MARK: - USA states catalog

enum USState: String, CaseIterable, Identifiable {
    case alabama       = "AL"
    case alaska        = "AK"
    case arizona       = "AZ"
    case arkansas      = "AR"
    case california    = "CA"
    case colorado      = "CO"
    case connecticut   = "CT"
    case delaware      = "DE"
    case dc            = "DC"
    case florida       = "FL"
    case georgia       = "GA"
    case hawaii        = "HI"
    case idaho         = "ID"
    case illinois      = "IL"
    case indiana       = "IN"
    case iowa          = "IA"
    case kansas        = "KS"
    case kentucky      = "KY"
    case louisiana     = "LA"
    case maine         = "ME"
    case maryland      = "MD"
    case massachusetts = "MA"
    case michigan      = "MI"
    case minnesota     = "MN"
    case mississippi   = "MS"
    case missouri      = "MO"
    case montana       = "MT"
    case nebraska      = "NE"
    case nevada        = "NV"
    case newHampshire  = "NH"
    case newJersey     = "NJ"
    case newMexico     = "NM"
    case newYork       = "NY"
    case northCarolina = "NC"
    case northDakota   = "ND"
    case ohio          = "OH"
    case oklahoma      = "OK"
    case oregon        = "OR"
    case pennsylvania  = "PA"
    case rhodeIsland   = "RI"
    case southCarolina = "SC"
    case southDakota   = "SD"
    case tennessee     = "TN"
    case texas         = "TX"
    case utah          = "UT"
    case vermont       = "VT"
    case virginia      = "VA"
    case washington    = "WA"
    case westVirginia  = "WV"
    case wisconsin     = "WI"
    case wyoming       = "WY"

    var id: String { rawValue }

    var fullName: String {
        switch self {
        case .alabama:       return "Alabama"
        case .alaska:        return "Alaska"
        case .arizona:       return "Arizona"
        case .arkansas:      return "Arkansas"
        case .california:    return "California"
        case .colorado:      return "Colorado"
        case .connecticut:   return "Connecticut"
        case .delaware:      return "Delaware"
        case .dc:            return "D.C."
        case .florida:       return "Florida"
        case .georgia:       return "Georgia"
        case .hawaii:        return "Hawaii"
        case .idaho:         return "Idaho"
        case .illinois:      return "Illinois"
        case .indiana:       return "Indiana"
        case .iowa:          return "Iowa"
        case .kansas:        return "Kansas"
        case .kentucky:      return "Kentucky"
        case .louisiana:     return "Louisiana"
        case .maine:         return "Maine"
        case .maryland:      return "Maryland"
        case .massachusetts: return "Massachusetts"
        case .michigan:      return "Michigan"
        case .minnesota:     return "Minnesota"
        case .mississippi:   return "Mississippi"
        case .missouri:      return "Missouri"
        case .montana:       return "Montana"
        case .nebraska:      return "Nebraska"
        case .nevada:        return "Nevada"
        case .newHampshire:  return "New Hampshire"
        case .newJersey:     return "New Jersey"
        case .newMexico:     return "New Mexico"
        case .newYork:       return "New York"
        case .northCarolina: return "North Carolina"
        case .northDakota:   return "North Dakota"
        case .ohio:          return "Ohio"
        case .oklahoma:      return "Oklahoma"
        case .oregon:        return "Oregon"
        case .pennsylvania:  return "Pennsylvania"
        case .rhodeIsland:   return "Rhode Island"
        case .southCarolina: return "South Carolina"
        case .southDakota:   return "South Dakota"
        case .tennessee:     return "Tennessee"
        case .texas:         return "Texas"
        case .utah:          return "Utah"
        case .vermont:       return "Vermont"
        case .virginia:      return "Virginia"
        case .washington:    return "Washington"
        case .westVirginia:  return "West Virginia"
        case .wisconsin:     return "Wisconsin"
        case .wyoming:       return "Wyoming"
        }
    }
}

// MARK: - USA logistics zones

enum USAZone: String, CaseIterable, Identifiable, Codable {
    case pacifico   = "Pacífico"
    case rocosas    = "Montaña Rocosa"
    case medioOeste = "Medio Oeste"
    case surCentral = "Sur Central"
    case sureste    = "Sureste EE.UU."
    case noreste    = "Noreste EE.UU."

    var id: String { rawValue }

    var states: [USState] {
        switch self {
        case .pacifico:
            return [.washington, .oregon, .california, .alaska, .hawaii]
        case .rocosas:
            return [.montana, .idaho, .wyoming, .colorado, .utah, .nevada, .arizona, .newMexico]
        case .medioOeste:
            return [.minnesota, .wisconsin, .michigan, .ohio, .indiana, .illinois,
                    .iowa, .missouri, .northDakota, .southDakota, .nebraska, .kansas]
        case .surCentral:
            return [.texas, .oklahoma, .arkansas, .louisiana]
        case .sureste:
            return [.tennessee, .kentucky, .virginia, .westVirginia,
                    .northCarolina, .southCarolina, .georgia, .florida, .alabama, .mississippi]
        case .noreste:
            return [.maine, .vermont, .newHampshire, .massachusetts, .rhodeIsland,
                    .connecticut, .newYork, .newJersey, .pennsylvania, .delaware, .maryland, .dc]
        }
    }

    var shortLabel: String {
        switch self {
        case .pacifico:   return "Pacífico"
        case .rocosas:    return "Montaña"
        case .medioOeste: return "Medio Oeste"
        case .surCentral: return "Sur Central"
        case .sureste:    return "Sureste"
        case .noreste:    return "Noreste"
        }
    }

    var keyStatesLabel: String {
        switch self {
        case .pacifico:   return "CA · OR · WA"
        case .rocosas:    return "CO · AZ · NV"
        case .medioOeste: return "IL · OH · MI"
        case .surCentral: return "TX · OK · LA"
        case .sureste:    return "FL · GA · NC"
        case .noreste:    return "NY · PA · MA"
        }
    }

    var zoneColor: Color {
        switch self {
        case .pacifico:   return Color(red: 0.15, green: 0.52, blue: 0.82)
        case .rocosas:    return Color(red: 0.22, green: 0.58, blue: 0.38)
        case .medioOeste: return Color(red: 0.76, green: 0.55, blue: 0.12)
        case .surCentral: return Color(red: 0.82, green: 0.28, blue: 0.18)
        case .sureste:    return Color(red: 0.18, green: 0.60, blue: 0.55)
        case .noreste:    return Color(red: 0.50, green: 0.28, blue: 0.75)
        }
    }

    static func zone(for state: String) -> USAZone? {
        allCases.first { $0.states.map { $0.rawValue }.contains(state) }
    }
}

// MARK: - Transport Company

struct TransportCompany: Identifiable, Codable {
    var id: UUID
    var name: String
    var contactName: String
    var phone: String
    var email: String
    var rfc: String
    var status: UserStatus
    var createdAt: Date

    init(id: UUID = UUID(), name: String, contactName: String,
         phone: String, email: String, rfc: String = "",
         status: UserStatus = .pendingApproval) {
        self.id = id
        self.name = name
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.rfc = rfc
        self.status = status
        self.createdAt = Date()
    }
}
