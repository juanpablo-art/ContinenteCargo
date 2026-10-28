import SwiftUI

// MARK: - Competencia View

struct CompetenciaView: View {
    @Environment(AppStore.self) private var store
    @State private var directory: [CarrierDirectoryRecord] = []
    @State private var toInviteCounts: [String: Int] = [:]
    @State private var isLoading = false

    // MARK: - Per-pricer stats (mirrors web's rankPricers in pricer-board-page-…js)

    struct PricerStat: Identifiable {
        let id: UUID
        let name: String
        let porInvitar: Int?      // nil → "—" (alta_pending unreadable); else pendingToInvite
        let invitaciones: Int     // carrier_preprofiles: pricerEmail==email OR invitedBy==authUID
        let enProceso: Int        // carriers: (pricerRawId==authUID OR pricerEmail==mail) && pending
        let exitosos: Int         // carriers: (pricerRawId==authUID OR pricerEmail==mail) && approved
    }

    private var pricerStats: [PricerStat] {
        // Mirrors web: isCarrierRole && status !== "suspended"
        let carriers = store.users.filter {
            ($0.role == .carrier || $0.role == .independentOperator) && $0.status != .suspended
        }
        return store.pricers().map { pricer in
            let prEmail = FirestoreService.emailOf(pricer.email)
            let authUID = pricer.firebaseUID

            // invitaciones: preprofiles matching by email OR by invitedBy == Auth UID / uuid
            let inviteRecords = directory.filter {
                FirestoreService.emailOf($0.pricerEmail) == prEmail ||
                (!authUID.isEmpty && $0.invitedBy == authUID)
            }

            // exitosos / enProceso: web rankPricers —
            // row.pricerId === pricer.uuid || emailOf(row.pricerEmail) === mail
            let mine = carriers.filter {
                let carrierMail = FirestoreService.emailOf($0.pricerEmail)
                return (!authUID.isEmpty && $0.pricerRawId == authUID) ||
                    (!prEmail.isEmpty && carrierMail == prEmail)
            }

            return PricerStat(
                id: pricer.id,
                name: pricer.name,
                porInvitar:   toInviteCounts[authUID],
                invitaciones: inviteRecords.count,
                enProceso:    mine.filter { $0.status == .pendingApproval }.count,
                exitosos:     mine.filter { $0.isApproved }.count
            )
        }
        .sorted {
            if $0.exitosos != $1.exitosos { return $0.exitosos > $1.exitosos }
            return $0.invitaciones > $1.invitaciones
        }
    }

    // MARK: - Heat map data

    private var approvedCarriers: [AppUser] {
        store.users.filter { ($0.role == .carrier || $0.role == .independentOperator) && $0.isApproved }
    }

    // Approved carriers per Mexican state (from coverageStates).
    private var mexicoHeat: [String: Int] {
        var counts: [String: Int] = [:]
        for user in approvedCarriers {
            for state in user.coverageStates {
                counts[state, default: 0] += 1
            }
        }
        return counts
    }

    // Approved carriers per US state; if coversUSA=true with no state list → counts for every state.
    private var usaHeat: [String: Int] {
        let allUSStates = USState.allCases.map { $0.rawValue }
        var counts: [String: Int] = [:]
        for user in approvedCarriers where user.coversUSA {
            let states = user.coverageUSAStates.isEmpty ? allUSStates : user.coverageUSAStates
            for state in states {
                counts[state, default: 0] += 1
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
        .task {
            isLoading = true
            // Listener may still be filling store.users; wait briefly so exitosos
            // and registrationIndex see the full carrier roster.
            for _ in 0..<30 where store.pricers().isEmpty || store.users.count < 10 {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let dir = await store.loadFullCarrierDirectory()
            directory = dir
            toInviteCounts = await store.loadToInviteCounts(directory: dir)
            isLoading = false
        }
    }

    // MARK: - Pricer table

    private var pricerTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Competencia de pricers")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Quién está metiendo más transportistas. El ranking usa registros aprobados.")
                .font(.caption).foregroundColor(.secondary)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
            } else if pricerStats.isEmpty {
                Text("Sin pricers registrados.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("#").font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                            .frame(width: 22, alignment: .leading)
                        Text("Pricer").font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        statHeader("Por\ninvitar")
                        statHeader("Invita-\nciones")
                        statHeader("En\nproceso")
                        statHeader("Exitosos")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray6))

                    Divider()

                    ForEach(Array(pricerStats.enumerated()), id: \.element.id) { i, stat in
                        HStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.caption2).foregroundColor(.secondary)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(firstName(stat.name))
                                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                Text(stat.name.components(separatedBy: " ").dropFirst().joined(separator: " "))
                                    .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            optionalStatCell(stat.porInvitar)
                            statCell(stat.invitaciones, accent: stat.invitaciones > 0 ? .ccBlue : nil)
                            statCell(stat.enProceso, accent: stat.enProceso > 0 ? .orange : nil)
                            statCell(stat.exitosos, accent: stat.exitosos > 0 ? .green : nil)
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
            .frame(width: 52)
    }

    private func statCell(_ value: Int, accent: Color? = nil) -> some View {
        Text("\(value)")
            .font(.subheadline).fontWeight(.bold).tabularNumerals()
            .foregroundColor(accent ?? Color(UIColor.label))
            .frame(width: 52)
    }

    /// Web shows "—" when toInvite map has no entry (alta_pending unreadable).
    private func optionalStatCell(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "—")
            .font(.subheadline).fontWeight(.bold).tabularNumerals()
            .foregroundColor(Color(UIColor.label))
            .frame(width: 52)
    }

    private func firstName(_ name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    // MARK: - Mexico heat map

    private var mexicoHeatMap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mapa de calor · México")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Transportistas aprobados por zona y estado. Bajo es donde estamos escasos. Algunos es donde ya hay presencia, pero no sobra.")
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
            Text("Mapa de calor · EE.UU.")
                .font(.headline).foregroundColor(.ccNavy)
            Text("Cobertura en Estados Unidos de los transportistas aprobados. Cuenta los estados que marcaron, o todo el país si indicaron EE.UU. sin lista.")
                .font(.caption).foregroundColor(.secondary)

            if activeUSA.isEmpty {
                Text("Sin transportistas con cobertura en EE.UU.")
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
