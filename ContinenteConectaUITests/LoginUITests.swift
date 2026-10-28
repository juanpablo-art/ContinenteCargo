import XCTest

final class LoginUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Login screen elements

    func testLoginScreenShowsCredentialFields() throws {
        let email = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'correo' OR placeholderValue CONTAINS[c] 'email'")
        ).firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Email/correo field should be visible on login screen")

        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 3), "Password field should be visible")
    }

    func testLoginButtonExists() throws {
        let loginBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'entrar' OR label CONTAINS[c] 'iniciar' OR label CONTAINS[c] 'login'")
        ).firstMatch
        XCTAssertTrue(loginBtn.waitForExistence(timeout: 5), "Login button should exist")
    }

    // MARK: - Demo mode shortcuts

    func testDemoCarrierButtonExists() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'transportista' OR label CONTAINS[c] 'carrier'")
        ).firstMatch
        // Demo buttons might be in a scrollable section; just verify one exists
        XCTAssertTrue(btn.waitForExistence(timeout: 5), "Demo carrier shortcut should be on login screen")
    }

    func testDemoAdminButtonExists() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'admin'")
        ).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 5), "Demo admin shortcut should be on login screen")
    }

    func testDemoPricerButtonExists() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'pricer'")
        ).firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 5), "Demo pricer shortcut should be on login screen")
    }

    // MARK: - Navigation after demo login

    func testDemoCarrierLoginNavigatesToTabBar() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'transportista' OR label CONTAINS[c] 'carrier'")
        ).firstMatch
        guard btn.waitForExistence(timeout: 5) else {
            XCTSkip("Demo carrier button not found — login screen layout may have changed")
        }
        btn.tap()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear after demo carrier login")
    }

    func testDemoPricerLoginNavigatesToTabBar() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'pricer'")
        ).firstMatch
        guard btn.waitForExistence(timeout: 5) else {
            XCTSkip("Demo pricer button not found")
        }
        btn.tap()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear after demo pricer login")
    }

    func testDemoAdminLoginNavigatesToTabBar() throws {
        let btn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'admin'")
        ).firstMatch
        guard btn.waitForExistence(timeout: 5) else {
            XCTSkip("Demo admin button not found")
        }
        btn.tap()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear after demo admin login")
    }
}
