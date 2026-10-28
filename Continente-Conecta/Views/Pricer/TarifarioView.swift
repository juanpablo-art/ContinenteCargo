import SwiftUI

// MARK: - Tarifario View

struct TarifarioView: View {
    @State private var selectedPort: String = "VERACRUZ"
    @State private var searchText = ""

    private let ports = ["VERACRUZ", "MANZANILLO", "LAZARO CARDENAS", "ALTAMIRA"]

    private let portDisplayNames: [String: String] = [
        "VERACRUZ":         "Veracruz",
        "MANZANILLO":       "Manzanillo",
        "LAZARO CARDENAS":  "Lázaro Cárdenas",
        "ALTAMIRA":         "Altamira",
    ]

    // MARK: - Parsed rows

    struct TarifaRow: Identifiable {
        let id = UUID()
        let destination: String
        let sencillo: ReferencePrice?
        let full: ReferencePrice?
    }

    private var rows: [TarifaRow] {
        // Collect unique destinations for the selected port
        var destinations = Set<String>()
        for key in Tarifario.rates.keys {
            let parts = key.components(separatedBy: "|")
            guard parts.count == 3, parts[0] == selectedPort else { continue }
            destinations.insert(parts[1])
        }

        let q = searchText.trimmingCharacters(in: .whitespaces).uppercased()
        return destinations
            .filter { q.isEmpty || $0.contains(q) }
            .sorted()
            .map { dest in
                let sKey = "\(selectedPort)|\(dest)|SENCILLO"
                let fKey = "\(selectedPort)|\(dest)|FULL"
                let sPrice = Tarifario.rates[sKey].map { ReferencePrice(compraMedia: Decimal($0)) }
                let fPrice = Tarifario.rates[fKey].map { ReferencePrice(compraMedia: Decimal($0)) }
                return TarifaRow(destination: dest, sencillo: sPrice, full: fPrice)
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary).font(.subheadline)
                    TextField("Buscar destino…", text: $searchText)
                        .autocorrectionDisabled()
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                // Port filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ports, id: \.self) { port in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedPort = port }
                            } label: {
                                Text(portDisplayNames[port] ?? port)
                                    .font(.subheadline)
                                    .fontWeight(selectedPort == port ? .semibold : .regular)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(selectedPort == port ? Color.ccBlue : Color(UIColor.systemBackground))
                                    .foregroundColor(selectedPort == port ? .white : .primary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(
                                        selectedPort == port ? Color.clear : Color(UIColor.separator),
                                        lineWidth: 1
                                    ))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }

                Divider()

                // Column headers
                HStack(spacing: 0) {
                    Text("Destino")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    columnHeader("Sencillo\nCompra")
                    columnHeader("Sencillo\nVenta")
                    columnHeader("Full\nCompra")
                    columnHeader("Full\nVenta")
                }
                .font(.caption2).fontWeight(.semibold).foregroundColor(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))

                Divider()

                if rows.isEmpty {
                    Spacer()
                    Text(searchText.isEmpty ? "Sin tarifas para este puerto." : "Sin resultados para \"\(searchText)\"")
                        .font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                            TarifaRowView(row: row, index: i)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(i % 2 == 0
                                    ? Color(UIColor.systemBackground)
                                    : Color(UIColor.systemGray6).opacity(0.4))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.ccBackground)
            .navigationTitle("Tarifarios")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .frame(width: 68)
    }
}

// MARK: - Row view

private struct TarifaRowView: View {
    let row: TarifarioView.TarifaRow
    let index: Int

    var body: some View {
        HStack(spacing: 0) {
            Text(row.destination.capitalized)
                .font(.subheadline).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            priceCell(row.sencillo?.compraMedia, color: .secondary)
            priceCell(row.sencillo?.ventaSugerida, color: .ccBlue, bold: true)
            priceCell(row.full?.compraMedia, color: .secondary)
            priceCell(row.full?.ventaSugerida, color: .ccNavy, bold: true)
        }
        .padding(.vertical, 10)
    }

    private func priceCell(_ value: Decimal?, color: Color, bold: Bool = false) -> some View {
        Group {
            if let v = value {
                Text(formatMXN(v))
                    .font(.system(size: 11, weight: bold ? .semibold : .regular))
                    .foregroundColor(color)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            } else {
                Text("—").font(.caption2).foregroundColor(Color(UIColor.systemGray3))
            }
        }
        .frame(width: 68)
        .multilineTextAlignment(.center)
    }

    private func formatMXN(_ value: Decimal) -> String {
        let n = (value as NSDecimalNumber).intValue
        if n >= 1_000 {
            return "$\(n / 1_000)k"
        }
        return "$\(n)"
    }
}

// MARK: - ReferencePrice helper (local re-declaration for view use)

private struct ReferencePrice {
    let compraMedia: Decimal
    var ventaSugerida: Decimal { (compraMedia * Decimal(1.15)).rounded(scale: 0) }
    var ventaMinima: Decimal    { (compraMedia * Decimal(1.13)).rounded(scale: 0) }
    var ventaAlta: Decimal      { (compraMedia * Decimal(1.20)).rounded(scale: 0) }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var copy = self
        NSDecimalRound(&result, &copy, scale, .plain)
        return result
    }
}
