import Testing
@testable import Continente_Conecta

@Suite("Load Status")
struct LoadStatusTests {

    // MARK: isActive

    @Test("Published is active")
    func publishedIsActive() { #expect(LoadStatus.published.isActive == true) }

    @Test("Assigned is active")
    func assignedIsActive() { #expect(LoadStatus.assigned.isActive == true) }

    @Test("En camino a recolección is active")
    func enRouteIsActive() { #expect(LoadStatus.enRouteToPickup.isActive == true) }

    @Test("En origen is active")
    func atOriginIsActive() { #expect(LoadStatus.atOrigin.isActive == true) }

    @Test("Cargado is active")
    func loadedIsActive() { #expect(LoadStatus.loaded.isActive == true) }

    @Test("En tránsito is active")
    func inTransitIsActive() { #expect(LoadStatus.inTransit.isActive == true) }

    @Test("Entregado is NOT active")
    func deliveredIsNotActive() { #expect(LoadStatus.delivered.isActive == false) }

    @Test("Cancelado is NOT active")
    func cancelledIsNotActive() { #expect(LoadStatus.cancelled.isActive == false) }

    // MARK: progressStep ordering

    @Test("Progress steps follow pipeline order: assigned < enRoute < atOrigin < loaded < inTransit < delivered")
    func progressStepsMonotonicallyIncrease() {
        let pipeline: [LoadStatus] = [.assigned, .enRouteToPickup, .atOrigin, .loaded, .inTransit, .delivered]
        for i in 0..<(pipeline.count - 1) {
            #expect(pipeline[i].progressStep < pipeline[i+1].progressStep,
                    "\(pipeline[i].rawValue) step should be less than \(pipeline[i+1].rawValue)")
        }
    }

    @Test("Cancelled has a negative progress step (off the normal pipeline)")
    func cancelledNegativeStep() {
        #expect(LoadStatus.cancelled.progressStep < 0)
    }

    @Test("All raw values are unique Spanish strings (no collision in Firebase deserialization)")
    func uniqueRawValues() {
        let values = LoadStatus.allCases.map { $0.rawValue }
        #expect(Set(values).count == values.count,
                "Duplicate raw values would break Firestore round-trips")
    }

    @Test("All expected Spanish raw values exist")
    func expectedRawValues() {
        #expect(LoadStatus.published.rawValue == "Publicado")
        #expect(LoadStatus.assigned.rawValue == "Asignado")
        #expect(LoadStatus.delivered.rawValue == "Entregado")
        #expect(LoadStatus.cancelled.rawValue == "Cancelado")
    }
}
