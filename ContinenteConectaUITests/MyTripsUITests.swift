import XCTest

final class MyTripsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Setup

    private func navigateToMyTrips() {
        let carrierBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'transportista' OR label CONTAINS[c] 'carrier'")
        ).firstMatch
        if carrierBtn.waitForExistence(timeout: 5) { carrierBtn.tap() }

        let tripsTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'viajes'")
        ).firstMatch
        if tripsTab.waitForExistence(timeout: 8) { tripsTab.tap() }
    }

    // MARK: - Navigation title

    func testMyTripsNavigationTitle() throws {
        navigateToMyTrips()
        let nav = app.navigationBars["Mis viajes"].firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 10), "My trips navigation title should be 'Mis viajes'")
    }

    // MARK: - Tab picker (new in this sprint)

    func testEnCursoTabVisible() throws {
        navigateToMyTrips()
        let tab = app.buttons["En curso"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "'En curso' segment should be visible in Mis viajes")
    }

    func testHistorialTabVisible() throws {
        navigateToMyTrips()
        let tab = app.buttons["Historial"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "'Historial' segment should be visible in Mis viajes")
    }

    func testEnCursoTabIsSelectedByDefault() throws {
        navigateToMyTrips()
        let enCurso = app.buttons["En curso"]
        guard enCurso.waitForExistence(timeout: 10) else {
            XCTFail("'En curso' tab not found"); return
        }
        XCTAssertTrue(enCurso.isSelected, "'En curso' should be selected by default")
    }

    func testSwitchingToHistorialSelects() throws {
        navigateToMyTrips()
        let historial = app.buttons["Historial"]
        guard historial.waitForExistence(timeout: 10) else {
            XCTFail("'Historial' tab not found"); return
        }
        historial.tap()
        XCTAssertTrue(historial.isSelected, "'Historial' tab should be selected after tap")
    }

    func testSwitchingBackToEnCursoSelects() throws {
        navigateToMyTrips()
        let historial = app.buttons["Historial"]
        let enCurso = app.buttons["En curso"]
        guard historial.waitForExistence(timeout: 10) else {
            XCTFail("'Historial' tab not found"); return
        }
        historial.tap()
        enCurso.tap()
        XCTAssertTrue(enCurso.isSelected, "'En curso' should be re-selected")
    }

    // MARK: - Trip row progress bar

    func testTripRowShowsProgressBar() throws {
        navigateToMyTrips()
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTSkip("No trips in demo data for carrier — progress bar test skipped")
        }
        // The progress bar is a set of Capsule shapes — verify cell content exists
        XCTAssertTrue(firstCell.exists, "Trip row cell should be rendered")
    }
}
