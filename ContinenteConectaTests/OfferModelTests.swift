import Testing
@testable import Continente_Conecta

@Suite("Offer Model")
struct OfferModelTests {

    private func makeOffer(
        amount: Decimal = 12_000,
        availableUnitCount: Int = 1,
        isAvailabilityOnly: Bool = false
    ) -> Offer {
        Offer(
            loadId: UUID(),
            carrierId: UUID(),
            carrierName: "Test Carrier",
            amount: amount,
            isAvailabilityOnly: isAvailabilityOnly,
            availableUnitCount: availableUnitCount
        )
    }

    // MARK: Status raw values — must match Firestore strings exactly

    @Test("OfferStatus raw values match Firestore document strings")
    func offerStatusRawValues() {
        #expect(OfferStatus.active.rawValue == "Activa")
        #expect(OfferStatus.winning.rawValue == "Ganando")
        #expect(OfferStatus.outbid.rawValue == "Superada")
        #expect(OfferStatus.won.rawValue == "Ganadora")
        #expect(OfferStatus.lost.rawValue == "Perdida")
        #expect(OfferStatus.cancelled.rawValue == "Cancelada")
        #expect(OfferStatus.rejected.rawValue == "Rechazada")
        #expect(OfferStatus.pendingApproval.rawValue == "PendienteAprobacion")
    }

    // MARK: Default values

    @Test("New offer defaults to active status")
    func newOfferDefaultsToActive() {
        #expect(makeOffer().status == .active)
    }

    @Test("New offer's submittedAt is recent (within 5 seconds)")
    func newOfferSubmittedAtIsRecent() {
        let offer = makeOffer()
        #expect(abs(offer.submittedAt.timeIntervalSinceNow) < 5)
    }

    // MARK: Unit pricing

    @Test("Total for multi-unit offer equals amount × availableUnitCount")
    func totalPriceMultiUnit() {
        let offer = makeOffer(amount: 12_000, availableUnitCount: 3)
        let total = offer.amount * Decimal(offer.availableUnitCount)
        #expect(total == 36_000)
    }

    @Test("Single-unit offer total equals the offer amount")
    func totalPriceSingleUnit() {
        let offer = makeOffer(amount: 15_000, availableUnitCount: 1)
        #expect(offer.amount * Decimal(offer.availableUnitCount) == 15_000)
    }

    // MARK: Availability-only flag

    @Test("isAvailabilityOnly defaults to false for a normal offer")
    func availabilityOnlyDefaultsFalse() {
        #expect(makeOffer().isAvailabilityOnly == false)
    }

    @Test("Availability-only offer carries the flag through init")
    func availabilityOnlyFlagSet() {
        #expect(makeOffer(isAvailabilityOnly: true).isAvailabilityOnly == true)
    }
}
