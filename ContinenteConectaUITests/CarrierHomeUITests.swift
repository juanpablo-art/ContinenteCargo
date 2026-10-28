import XCTest

final class CarrierHomeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Setup helper

    private func loginAsCarrier() {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'transportista' OR label CONTAINS[c] 'carrier'")
        ).firstMatch
        if btn.waitForExistence(timeout: 5) { btn.tap() }
        // Ensure carrier home tab is active
        let tab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'cargas' OR label CONTAINS[c] 'disponibles'")
        ).firstMatch
        if tab.waitForExistence(timeout: 5) { tab.tap() }
    }

    // MARK: - Navigation title

    func testCarrierHomeNavigationTitle() throws {
        loginAsCarrier()
        let nav = app.navigationBars["Cargas Disponibles"].firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 10),
                      "Carrier home tab should have 'Cargas Disponibles' navigation title")
    }

    // MARK: - Search bar

    func testSearchBarIsVisible() throws {
        loginAsCarrier()
        let search = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'buscar'")
        ).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Search bar should be visible in carrier home")
    }

    func testSearchBarFiltersLoads() throws {
        loginAsCarrier()
        let search = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'buscar'")
        ).firstMatch
        guard search.waitForExistence(timeout: 10) else { XCTSkip("Search bar not found") }

        search.tap()
        search.typeText("zzznomatch")
        // Expect empty state message
        let emptyMsg = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sin cargas' OR label CONTAINS[c] 'no hay'")
        ).firstMatch
        XCTAssertTrue(emptyMsg.waitForExistence(timeout: 5), "Searching non-existent text should show empty state")
    }

    // MARK: - Filter chips

    func testTodosFilterChipIsVisible() throws {
        loginAsCarrier()
        let todos = app.buttons["Todos"].firstMatch
        XCTAssertTrue(todos.waitForExistence(timeout: 10), "'Todos' filter chip should be visible")
    }

    func testFixedRateFilterChipIsVisible() throws {
        loginAsCarrier()
        let chip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'tarifa fija'")
        ).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "'Tarifa Fija' filter chip should be visible")
    }

    func testLTLChipIsHiddenForNonLTLCarrier() throws {
        // Demo carrier1 does not have handlesLTL=true in demo data
        loginAsCarrier()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        let ltlChip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'ltl' OR label CONTAINS[c] 'consolidada'")
        ).firstMatch
        XCTAssertFalse(ltlChip.exists, "LTL chip should not appear for a non-LTL carrier")
    }

    // MARK: - Load detail

    func testTappingLoadCardOpensDetailSheet() throws {
        loginAsCarrier()
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTSkip("No load cards visible in demo data")
        }
        firstCell.tap()
        // Detail sheet shows "Origen" and "Destino" labels (after the headerCard bug fix)
        let origenLabel = app.staticTexts["Origen"].firstMatch
        XCTAssertTrue(origenLabel.waitForExistence(timeout: 5),
                      "Load detail should show 'Origen' label (not duplicate city text)")
        let destinoLabel = app.staticTexts["Destino"].firstMatch
        XCTAssertTrue(destinoLabel.exists, "Load detail should show 'Destino' label")
    }

    func testEquipmentFilterSheetOpens() throws {
        loginAsCarrier()
        let equipoChip = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'equipo'")
        ).firstMatch
        guard equipoChip.waitForExistence(timeout: 10) else { XCTSkip("Equipo filter chip not found") }
        equipoChip.tap()
        let sheet = app.navigationBars.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'equipo'")
        ).firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Equipment filter sheet should open")
    }
}
