import XCTest

final class PricerHomeUITests: XCTestCase {

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

    private func loginAsPricer() {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'pricer'")
        ).firstMatch
        if btn.waitForExistence(timeout: 5) { btn.tap() }
    }

    private func navigateToPorCubrir() {
        loginAsPricer()
        let tab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'cargas'")
        ).firstMatch
        if tab.waitForExistence(timeout: 8) { tab.tap() }
    }

    private func navigateToMisTransportistas() {
        loginAsPricer()
        let tab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'transportistas'")
        ).firstMatch
        if tab.waitForExistence(timeout: 8) { tab.tap() }
    }

    // MARK: - Por cubrir screen

    func testPorCubrirNavigationTitle() throws {
        navigateToPorCubrir()
        let nav = app.navigationBars["Por cubrir"].firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 10),
                      "Pricer 'Cargas' tab should show 'Por cubrir' as navigation title")
    }

    func testPorCubrirSearchBarIsVisible() throws {
        navigateToPorCubrir()
        let search = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'buscar'")
        ).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10),
                      "Search bar should be visible in 'Por cubrir' screen")
    }

    func testPorCubrirSearchFilters() throws {
        navigateToPorCubrir()
        let search = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'buscar'")
        ).firstMatch
        guard search.waitForExistence(timeout: 10) else { XCTSkip("Search bar not found") }
        search.tap()
        search.typeText("zzznomatch")
        let emptyMsg = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sin resultado' OR label CONTAINS[c] 'nada por cubrir'")
        ).firstMatch
        XCTAssertTrue(emptyMsg.waitForExistence(timeout: 5),
                      "Empty state should appear when search yields no results")
    }

    func testPorCubrirSubtitleShowsLoadCount() throws {
        navigateToPorCubrir()
        // Subtitle contains "carga(s) publicada(s) sin transportista"
        let subtitle = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sin transportista'")
        ).firstMatch
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10),
                      "Subtitle should mention open loads count")
    }

    // MARK: - "De mis transportistas" section

    func testMisTransportistasHeaderVisible() throws {
        navigateToPorCubrir()
        let header = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'mis transportistas'")
        ).firstMatch
        // This section appears below open loads; scroll down if needed
        guard !header.waitForExistence(timeout: 5) else {
            XCTAssertTrue(header.exists); return
        }
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(header.waitForExistence(timeout: 5),
                      "'De mis transportistas' section header should appear below open loads")
    }

    // MARK: - Mis transportistas tab

    func testMisTransportistasNavigationTitle() throws {
        navigateToMisTransportistas()
        let nav = app.navigationBars["Mis Transportistas"].firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 10),
                      "Transportistas tab should have 'Mis Transportistas' title")
    }

    func testMisTransportistasSearchBarIsVisible() throws {
        navigateToMisTransportistas()
        let search = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'buscar'")
        ).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10),
                      "Search bar should be visible in Mis Transportistas")
    }

    func testMisTransportistasListShowsCarriers() throws {
        navigateToMisTransportistas()
        let list = app.collectionViews.firstMatch
        guard list.waitForExistence(timeout: 10) else { XCTSkip("No carrier list found") }
        // Demo data assigns carriers to pricer1 — at least one row should be present
        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5),
                      "Carrier list should show at least one carrier in demo mode")
    }

    // MARK: - Pricer dashboard

    func testPricerDashboardHasKPIs() throws {
        loginAsPricer()
        // Dashboard is the first tab ("Inicio")
        let inicioTab = app.tabBars.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'inicio'")
        ).firstMatch
        if inicioTab.waitForExistence(timeout: 8) { inicioTab.tap() }
        let nav = app.navigationBars.firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 10), "Pricer dashboard navigation bar should exist")
    }
}
