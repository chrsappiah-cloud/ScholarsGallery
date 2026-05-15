import XCTest

final class AIFinanceTradingLabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func tabBar(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.firstMatch
    }

    private enum MainTab: Int {
        case dashboard = 0
        case watchlist = 1
        case onChain = 2
        case portfolio = 3
        case hub = 4
    }

    private func tapTab(_ app: XCUIApplication, _ tab: MainTab) {
        let bar = tabBar(app)
        let btn = bar.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        btn.tap()
    }

    /// Lab lives under **Hub → Lab journal** so the tab bar stays at five items (iOS otherwise overflows tabs 5–6 into an unreliable “More” list).
    private func tapLabJournal(_ app: XCUIApplication) {
        tapTab(app, .hub)
        let link = app.descendants(matching: .any)["hub_lab_journal_link"]
        XCTAssertTrue(link.waitForExistence(timeout: 8))
        link.tap()
    }

    /// SwiftUI `NavigationStack` back buttons often use the **previous** screen title (e.g. “Dashboard”) instead of the literal “Back”.
    private func tapNavigationBack(_ app: XCUIApplication) {
        let dashboardBack = app.buttons["Dashboard"].firstMatch
        if dashboardBack.waitForExistence(timeout: 2), dashboardBack.isHittable {
            dashboardBack.tap()
            return
        }

        let nav = app.navigationBars.firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 5))
        let labels = ["Dashboard", "Hub", "Back", "All holdings", "Lab"]
        for label in labels {
            let btn = nav.buttons[label]
            if btn.waitForExistence(timeout: 1), btn.isHittable {
                btn.tap()
                return
            }
        }

        if nav.buttons.element(boundBy: 0).waitForExistence(timeout: 2), nav.buttons.element(boundBy: 0).isHittable {
            nav.buttons.element(boundBy: 0).tap()
            return
        }

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testMainTabsAppear() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        let bar = tabBar(app)
        XCTAssertTrue(bar.waitForExistence(timeout: 8))
        XCTAssertEqual(bar.buttons.count, 5)
        XCTAssertTrue(bar.buttons.element(boundBy: MainTab.dashboard.rawValue).exists)
        XCTAssertTrue(bar.buttons.element(boundBy: MainTab.hub.rawValue).exists)
    }

    func testLabJournalSaveShowsNote() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        tapLabJournal(app)

        let root = app.descendants(matching: .any)["lab_journal_root"]
        XCTAssertTrue(root.waitForExistence(timeout: 8))

        let field = app.textFields["labNoteTitleField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("UI persistence check")

        app.buttons["labSaveNoteButton"].tap()

        let saved = app.staticTexts["UI persistence check"]
        XCTAssertTrue(saved.waitForExistence(timeout: 8))
    }

    func testDashboardHeroPanelsSignalsHoldingsAndMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        XCTAssertTrue(tabBar(app).waitForExistence(timeout: 8))
        tapTab(app, .dashboard)

        let hero = app.scrollViews["dashboard_hero_root"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8))

        func dash(_ id: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: id).element
        }

        let panelTitles = ["Market Regime", "Portfolio Health", "On-Chain Signals", "Research Atelier"]
        for index in 0 ..< 4 {
            let link = dash("dashboard_panel_\(index)")
            XCTAssertTrue(link.waitForExistence(timeout: 5), "Missing panel control \(index)")
            link.tap()
            XCTAssertTrue(app.navigationBars[panelTitles[index]].waitForExistence(timeout: 5), "Panel \(index) detail did not open")
            tapNavigationBack(app)
        }

        let firstSignal = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard_signal_"))
            .element(boundBy: 0)
        XCTAssertTrue(firstSignal.waitForExistence(timeout: 5))
        firstSignal.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        tapNavigationBack(app)

        dash("dashboard_holdings_see_all").tap()
        XCTAssertTrue(app.navigationBars["All holdings"].waitForExistence(timeout: 5))
        tapNavigationBack(app)

        let firstHolding = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "dashboard_holding_row_"))
            .element(boundBy: 0)
        XCTAssertTrue(firstHolding.waitForExistence(timeout: 5))
        firstHolding.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        tapNavigationBack(app)

        app.buttons["dashboard_mode_picker"].tap()
        if app.buttons["Paper"].waitForExistence(timeout: 2) {
            app.buttons["Paper"].tap()
        } else {
            let paperMenu = app.menuItems["Paper"]
            XCTAssertTrue(paperMenu.waitForExistence(timeout: 3))
            paperMenu.tap()
        }
        XCTAssertTrue(app.buttons["dashboard_mode_picker"].waitForExistence(timeout: 3))
    }

    func testAllMainTabsSelectable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        let bar = tabBar(app)
        XCTAssertTrue(bar.waitForExistence(timeout: 8))
        XCTAssertEqual(bar.buttons.count, 5)

        tapTab(app, .dashboard)
        tapTab(app, .watchlist)
        tapTab(app, .onChain)
        tapTab(app, .portfolio)
        tapTab(app, .hub)
    }
}
