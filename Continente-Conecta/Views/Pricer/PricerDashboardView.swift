import SwiftUI
import Charts

// MARK: - Pricer Dashboard

struct PricerDashboardView: View {
    @Environment(AppStore.self) private var store

    // MARK: - Derived data

    private var myCarriers: [AppUser] { store.carriersForPricer() }
    private var myCarrierIds: Set<UUID> { Set(myCarriers.map { $0.id }) }

    /// Loads where at least one of this pricer's carriers is confirmed/assigned.
    private var myCarrierLoads: [Load] {
        store.loads.filter { load in
            if let a = load.assignedCarrierId, myCarrierIds.contains(a) { return true }
            return load.confirmedCarrierIds.contains(where: { myCarrierIds.contains($0) })
        }
    }

    private var deliveredLoads: [Load] { myCarrierLoads.filter { $0.status == .delivered } }
    private var inProgressLoads: [Load] {
        myCarrierLoads.filter { $0.status.isActive && $0.status != .published }
    }
    private var cancelledLoads: [Load] { myCarrierLoads.filter { $0.status == .cancelled } }

    /// Total units (confirmedUnitCount ≥ 1) delivered by pricer's carriers.
    private var deliveredUnits: Int {
        deliveredLoads.reduce(0) { $0 + max(1, $1.confirmedUnitCount) }
    }

    private var completionRate: Double {
        let finished = deliveredLoads.count + cancelledLoads.count
        guard finished > 0 else { return 0 }
        return Double(deliveredLoads.count) / Double(finished)
    }

    // MARK: - This-month units

    private var thisMonthUnits: Int {
        let cal = Calendar.current
        let now = Date()
        return deliveredLoads.filter {
            cal.isDate($0.pickupDate, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + max(1, $1.confirmedUnitCount) }
    }

    // MARK: - Monthly trend (last 6 months, by pickupDate)

    private var monthlyStats: [MonthStat] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).reversed().compactMap { offset -> MonthStat? in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let yr = cal.component(.year,  from: date)
            let mo = cal.component(.month, from: date)
            let units = deliveredLoads
                .filter {
                    cal.component(.year,  from: $0.pickupDate) == yr &&
                    cal.component(.month, from: $0.pickupDate) == mo
                }
                .reduce(0) { $0 + max(1, $1.confirmedUnitCount) }
            return MonthStat(label: date.formatted(.dateTime.month(.abbreviated)), count: units)
        }
    }

    // MARK: - Top origins

    private var topOrigins: [(state: String, count: Int)] {
        var freq: [String: Int] = [:]
        for load in myCarrierLoads where load.status != .cancelled {
            freq[load.originState, default: 0] += max(1, load.confirmedUnitCount)
        }
        return freq.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    // MARK: - Top routes

    private var topRoutes: [(route: String, count: Int)] {
        var freq: [String: Int] = [:]
        for load in myCarrierLoads where load.status != .cancelled {
            freq["\(load.originState) → \(load.destinationState)", default: 0] += 1
        }
        return freq.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    // MARK: - Top carriers by load count

    private var topCarriers: [(carrier: AppUser, count: Int)] {
        Array(
            myCarriers
                .map { c in
                    let n = myCarrierLoads.filter {
                        $0.confirmedCarrierIds.contains(c.id) || $0.assignedCarrierId == c.id
                    }.count
                    return (carrier: c, count: n)
                }
                .filter { $0.count > 0 }
                .sorted { $0.count > $1.count }
                .prefix(5)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    kpiRow
                    monthlyChartSection
                    completionSection
                    if !topOrigins.isEmpty  { originsSection }
                    if !topRoutes.isEmpty   { routesSection }
                    if !topCarriers.isEmpty { carriersSection }
                    Spacer(minLength: 32)
                }
                .padding(16)
            }
            .background(Color.ccBackground)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 10) {
            KPICard(
                title: "Este mes",
                value: "\(thisMonthUnits)",
                subtitle: "cargas cerradas",
                icon: "checkmark.seal.fill",
                color: .green
            )
            KPICard(
                title: "En progreso",
                value: "\(inProgressLoads.count)",
                subtitle: "activas ahora",
                icon: "truck.box.fill",
                color: .ccBlue
            )
            KPICard(
                title: "Cumplimiento",
                value: completionRate > 0 ? "\(Int(completionRate * 100))%" : "—",
                subtitle: "entregas exitosas",
                icon: "chart.bar.fill",
                color: completionRate >= 0.8 ? .green : (completionRate > 0 ? .orange : .secondary)
            )
        }
    }

    // MARK: - Monthly Chart

    private var monthlyChartSection: some View {
        DashboardCard(title: "Tendencia mensual", icon: "chart.bar.fill") {
            if monthlyStats.allSatisfy({ $0.count == 0 }) {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(Color(UIColor.systemGray3))
                    Text("Sin cargas cerradas aún")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)
            } else {
                Chart(monthlyStats) { stat in
                    BarMark(
                        x: .value("Mes", stat.label),
                        y: .value("Unidades", stat.count)
                    )
                    .foregroundStyle(Color.ccBlue.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        if stat.count > 0 {
                            Text("\(stat.count)")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundColor(.ccNavy)
                        }
                    }
                }
                .frame(height: 190)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption) }
                }
            }
        }
    }

    // MARK: - Completion Section

    private var completionSection: some View {
        let total = deliveredLoads.count + inProgressLoads.count + cancelledLoads.count
        return DashboardCard(title: "Estado de cargas", icon: "chart.pie.fill") {
            VStack(spacing: 12) {
                if total == 0 {
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 16)
                } else {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Color.green
                                .frame(width: geo.size.width * CGFloat(deliveredLoads.count) / CGFloat(total))
                            Color.orange
                                .frame(width: geo.size.width * CGFloat(inProgressLoads.count) / CGFloat(total))
                            Color.red.opacity(0.75)
                                .frame(width: geo.size.width * CGFloat(cancelledLoads.count) / CGFloat(total))
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 16)
                }

                HStack {
                    LegendDot(color: .green,          label: "Entregadas", count: deliveredLoads.count)
                    Spacer()
                    LegendDot(color: .orange,         label: "En progreso", count: inProgressLoads.count)
                    Spacer()
                    LegendDot(color: .red.opacity(0.75), label: "Canceladas", count: cancelledLoads.count)
                }

                if deliveredUnits > 0 {
                    HStack {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption).foregroundColor(.ccBlue)
                        Text("\(deliveredUnits) unidades totales entregadas")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Origins Section

    private var originsSection: some View {
        let maxCount = topOrigins.first?.count ?? 1
        return DashboardCard(title: "Principales orígenes", icon: "mappin.circle.fill") {
            VStack(spacing: 10) {
                ForEach(topOrigins, id: \.state) { item in
                    OriginBar(state: item.state, count: item.count, maxCount: maxCount)
                }
            }
        }
    }

    // MARK: - Routes Section

    private var routesSection: some View {
        DashboardCard(title: "Rutas frecuentes", icon: "arrow.triangle.swap") {
            VStack(spacing: 0) {
                ForEach(Array(topRoutes.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.ccBlue)
                            .clipShape(Circle())
                        Text(item.route)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(.ccNavy)
                        Text(item.count == 1 ? "viaje" : "viajes")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 9)
                    if idx < topRoutes.count - 1 { Divider() }
                }
            }
        }
    }

    // MARK: - Carriers Section

    private var carriersSection: some View {
        DashboardCard(title: "Mis transportistas", icon: "person.2.fill") {
            VStack(spacing: 0) {
                ForEach(Array(topCarriers.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.ccLightBlue).frame(width: 38, height: 38)
                            Text(String(item.carrier.name.prefix(1)))
                                .font(.subheadline).fontWeight(.bold).foregroundColor(.ccBlue)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.carrier.name)
                                .font(.subheadline).fontWeight(.semibold)
                                .lineLimit(1)
                            Text(item.carrier.phone)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(item.count)")
                                .font(.headline).fontWeight(.bold).foregroundColor(.ccNavy)
                            Text(item.count == 1 ? "carga" : "cargas")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    if idx < topCarriers.count - 1 { Divider() }
                }
            }
        }
    }
}

// MARK: - Supporting types

private struct MonthStat: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

// MARK: - KPI Card

private struct KPICard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2).fontWeight(.bold).foregroundColor(.ccNavy)
                .minimumScaleFactor(0.7).lineLimit(1)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                Text(subtitle)
                    .font(.caption2).foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Dashboard Card container

private struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.icon    = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline).foregroundColor(.ccBlue)
                Text(title)
                    .font(.headline).foregroundColor(.ccNavy)
            }
            content
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Legend Dot

private struct LegendDot: View {
    let color: Color
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Origin Bar

private struct OriginBar: View {
    let state: String
    let count: Int
    let maxCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(state)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor.systemGray5))
                    Capsule()
                        .fill(Color.ccBlue.gradient)
                        .frame(width: max(6, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                }
            }
            .frame(height: 14)
            Text("\(count)")
                .font(.caption).fontWeight(.semibold).foregroundColor(.ccNavy)
                .frame(width: 28, alignment: .trailing)
        }
    }
}
