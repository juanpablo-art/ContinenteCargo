import Testing
@testable import Continente_Conecta

@Suite("Load Model")
struct LoadModelTests {

    private func makeLoad(
        unitCount: Int = 1,
        confirmedUnitCount: Int = 0,
        status: LoadStatus = .published,
        deadlineOffset: TimeInterval = 3600,
        offeredPrice: Decimal = 15_000
    ) -> Load {
        var load = Load(
            reference: "TEST-001",
            originCity: "Monterrey",
            originState: "N.L.",
            destinationCity: "Ciudad de México",
            destinationState: "CDMX",
            pickupDate: Date().addingTimeInterval(86400),
            deliveryDate: Date().addingTimeInterval(172800),
            equipmentType: .dryBox53,
            unitCount: unitCount,
            weightKg: 10_000,
            merchandiseDescription: "Electrónica",
            offeredPrice: offeredPrice,
            assignmentMode: .fixedRate,
            deadline: Date().addingTimeInterval(deadlineOffset),
            publishedBy: UUID()
        )
        load.confirmedUnitCount = confirmedUnitCount
        load.status = status
        return load
    }

    // MARK: isFull

    @Test("Single unit load with no confirmed units is not full")
    func notFullWhenNoConfirmedUnits() {
        #expect(makeLoad(unitCount: 1, confirmedUnitCount: 0).isFull == false)
    }

    @Test("Multi-unit load is full when confirmedUnitCount reaches unitCount")
    func fullWhenAllUnitsConfirmed() {
        #expect(makeLoad(unitCount: 2, confirmedUnitCount: 2).isFull == true)
    }

    @Test("Multi-unit load with some remaining slots is not full")
    func notFullWhenPartiallyConfirmed() {
        #expect(makeLoad(unitCount: 3, confirmedUnitCount: 1).isFull == false)
    }

    @Test("Confirming one unit beyond total marks load as full")
    func fullWhenOverConfirmed() {
        #expect(makeLoad(unitCount: 1, confirmedUnitCount: 2).isFull == true)
    }

    // MARK: isOpen

    @Test("Published load before deadline with free slots is open")
    func openWhenPublishedNotFullBeforeDeadline() {
        #expect(makeLoad().isOpen == true)
    }

    @Test("Load is not open after deadline has passed")
    func notOpenAfterDeadline() {
        #expect(makeLoad(deadlineOffset: -1).isOpen == false)
    }

    @Test("Full load is not open even if still published")
    func notOpenWhenFull() {
        #expect(makeLoad(unitCount: 1, confirmedUnitCount: 1).isOpen == false)
    }

    @Test("Assigned load is not open")
    func notOpenWhenAssigned() {
        #expect(makeLoad(status: .assigned).isOpen == false)
    }

    @Test("Delivered load is not open")
    func notOpenWhenDelivered() {
        #expect(makeLoad(status: .delivered).isOpen == false)
    }

    // MARK: Display strings

    @Test("originDisplay joins city and state with comma-space")
    func originDisplay() {
        #expect(makeLoad().originDisplay == "Monterrey, N.L.")
    }

    @Test("destinationDisplay joins city and state with comma-space")
    func destinationDisplay() {
        #expect(makeLoad().destinationDisplay == "Ciudad de México, CDMX")
    }

    // MARK: Pricing

    @Test("totalPrice is offeredPrice × unitCount for multi-unit load")
    func totalPriceMultiUnit() {
        let load = makeLoad(unitCount: 3, offeredPrice: 15_000)
        #expect(load.totalPrice == 45_000)
    }

    @Test("totalPrice equals offeredPrice for single-unit load")
    func totalPriceSingleUnit() {
        let load = makeLoad(unitCount: 1, offeredPrice: 15_000)
        #expect(load.totalPrice == 15_000)
    }

    @Test("pricePerUnit equals offeredPrice regardless of unit count")
    func pricePerUnitAlwaysEqualsOfferedPrice() {
        let load = makeLoad(unitCount: 5, offeredPrice: 8_000)
        #expect(load.pricePerUnit == 8_000)
    }

    // MARK: Default state after init

    @Test("New load defaults to published status")
    func newLoadDefaultsToPublished() {
        #expect(makeLoad().status == .published)
    }

    @Test("New load has no assigned carrier")
    func newLoadHasNoAssignedCarrier() {
        #expect(makeLoad().assignedCarrierId == nil)
    }

    @Test("New load has zero confirmed units")
    func newLoadHasZeroConfirmedUnits() {
        #expect(makeLoad().confirmedUnitCount == 0)
    }
}
