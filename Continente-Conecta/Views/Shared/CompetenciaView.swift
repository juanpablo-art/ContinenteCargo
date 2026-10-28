import SwiftUI

// MARK: - Competencia View

struct CompetenciaView: View {
    @Environment(AppStore.self) private var store

    // MARK: - Per-pricer stats

    struct PricerStat: Identifiable {
        let id: UUID
        let name: String
        let openLoads: Int
        let inTransit: Int
        let delivered: Int
        let registeredCarriers: Int
        let totalCarriers: Int
    }

    private var openLoadsTotal: Int {
        store.loads.filter { $0.status == .published && $0.assignedCarrierId == nil && !$0.isFull }.count
    }

    private var pricerStats: [PricerStat] {
        store.pricers().map { pricer in
            let carriers   = store.users.filter { $0.pricerId == pricer.id }
            let carrierIds = Set(carriers.map { $0.id })
            let prLoads    = store.loads.filter { load in
                if let a = load.assignedCarrierId, carrierIds.contains(a) { return true }
                return load.confirmedCarrierIds.contains { carrierIds.contains($0) }
            }
            return PricerStat(
                id: pricer.id,
                name: pricer.name,
                openLoads: openLoadsTotal,
                inTransit: prLoads.filter { $0.status.isActive && $0.status != .published }.count,
                delivered: prLoads.filter { $0.status == .delivered }.count,
                registeredCarriers: carriers.filter { $0.status == .approved }.count,
                totalCarriers: carriers.count
            )
        }
        .sorted { $0.totalCarriers > $1.totalCarriers }
    }

    // MARK: - Heat map data

    private var mexicoHeat: [String: Int] {
        var counts: [String: Int] = [:]
        for load in store.loads where load.status != .cancelled {
            counts[load.originState, default: 0] += 1
            if load.destinationState != load.originState {
                counts[load.destinationState, default: 0] += 1
            }
        }
        return counts
    }

    private var usaHeat: [String: Int] {
        var counts: [String: Int] = [:]
        for load in store.loads where load.status != .cancelled {
            if load.coversUSA {
                for state in load.usaStates {
                    counts[state, default: 0] += 1
                }
            }
        }
        return counts
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pricerTable
                    mexicoHeatMap
                    usaHeatMap
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.ccBackground)
            .navigationTitle("Competencia")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Pricer table

    private var pricerTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Competencia de pricers")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Visibilidad regional del equipo de conductores")
                .font(.caption).foregroundColor(.secondary)

            if pricerStats.isEmpty {
                Text("Sin pricers registrados.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("Pricer").font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statHeader("Por\ncubrir")
                        statHeader("En\ntránsito")
                        statHeader("Entre-\ngadas")
                        statHeader("Regis-\ntradas")
                        statHeader("Trans-\nportistas")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))

                    Divider()

                    ForEach(Array(pricerStats.enumerated()), id: \.element.id) { i, stat in
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(firstName(stat.name))
                                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                Text(stat.name.components(separatedBy: " ").dropFirst().joined(separator: " "))
                                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            statCell(stat.openLoads)
                            statCell(stat.inTransit, accent: stat.inTransit > 0 ? .ccBlue : nil)
                            statCell(stat.delivered, accent: stat.delivered > 0 ? .green : nil)
                            statCell(stat.registeredCarriers)
                            statCell(stat.totalCarriers, accent: .ccNavy)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(i % 2 == 0 ? Color(UIColor.systemBackground) : Color(UIColor.systemGray6).opacity(0.5))

                        if i < pricerStats.count - 1 { Divider() }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    private func statHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(width: 46)
    }

    private func statCell(_ value: Int, accent: Color? = nil) -> some View {
        Text("\(value)")
            .font(.subheadline).fontWeight(.bold).tabularNumerals()
            .foregroundColor(accent ?? Color(UIColor.label))
            .frame(width: 46)
    }

    private func firstName(_ name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    // MARK: - Mexico heat map

    private var mexicoHeatMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mapa de calor: México")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Cargas por estado (origen o destino)")
                .font(.caption).foregroundColor(.secondary)

            let states = MexicanState.allCases
            let maxVal = max(1, mexicoHeat.values.max() ?? 1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(states) { state in
                    let count = mexicoHeat[state.rawValue] ?? 0
                    HeatCell(label: abbreviate(state.rawValue), count: count, maxCount: maxVal)
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - USA heat map

    private var usaHeatMap: some View {
        let activeUSA = USState.allCases.filter { (usaHeat[$0.rawValue] ?? 0) > 0 }
        let maxVal = max(1, usaHeat.values.max() ?? 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Mapa de calor: EE.UU.")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Cargas con destino en Estados Unidos")
                .font(.caption).foregroundColor(.secondary)

            if activeUSA.isEmpty {
                Text("Sin cargas con destino a EE.UU.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                    ForEach(USState.allCases) { state in
                        let count = usaHeat[state.rawValue] ?? 0
                        if count > 0 {
                            HeatCell(label: state.rawValue, count: count, maxCount: maxVal)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    // MARK: - Helpers

    private func abbreviate(_ state: String) -> String {
        switch state {
        case "Aguascalientes":   return "AGS"
        case "B.C.":             return "BC"
        case "B.C.S.":           return "BCS"
        case "Campeche":         return "CAMP"
        case "Chiapas":          return "CHIS"
        case "Chihuahua":        return "CHIH"
        case "Coahuila":         return "COAH"
        case "Colima":           return "COL"
        case "CDMX":             return "CDMX"
        case "Durango":          return "DGO"
        case "Estado de México": return "MEX"
        case "Guanajuato":       return "GTO"
        case "Guerrero":         return "GRO"
        case "Hidalgo":          return "HGO"
        case "Jalisco":          return "JAL"
        case "Michoacán":        return "MICH"
        case "Morelos":          return "MOR"
        case "Nayarit":          return "NAY"
        case "N.L.":             return "NL"
        case "Oaxaca":           return "OAX"
        case "Puebla":           return "PUE"
        case "Querétaro":        return "QRO"
        case "Quintana Roo":     return "QROO"
        case "S.L.P.":           return "SLP"
        case "Sinaloa":          return "SIN"
        case "Sonora":           return "SON"
        case "Tabasco":          return "TAB"
        case "Tamaulipas":       return "TAMS"
        case "Tlaxcala":         return "TLAX"
        case "Veracruz":         return "VER"
        case "Yucatán":          return "YUC"
        case "Zacatecas":        return "ZAC"
        default:                 return String(state.prefix(4)).uppercased()
        }
    }
}

// MARK: - Heat cell

private struct HeatCell: View {
    let label: String
    let count: Int
    let maxCount: Int

    private var intensity: Double {
        guard maxCount > 0 else { return 0 }
        return min(1.0, Double(count) / Double(maxCount))
    }

    private var bg: Color {
        if count == 0 { return Color(UIColor.systemGray6) }
        return Color.ccBlue.opacity(0.15 + intensity * 0.75)
    }

    private var fg: Color {
        count == 0 ? Color(UIColor.systemGray3) : (intensity > 0.5 ? .white : .ccNavy)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .tabularNumerals()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(bg)
        .foregroundColor(fg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Font modifier helper

private extension View {
    func tabularNumerals() -> some View {
        self.monospacedDigit()
    }
}
