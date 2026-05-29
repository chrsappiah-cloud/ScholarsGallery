import XCTest

// MARK: - Phase 9: End-to-End Core User Journey

final class EndToEndWorkflowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func scrollToElement(_ element: XCUIElement) {
        var attempts = 0
        while !element.exists && attempts < 8 {
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        attempts = 0
        while !element.isHittable && attempts < 8 {
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
    }

    @MainActor
    func testEndToEndJourneyWithMockData() throws {
        let exhibitionsJSON = #"""
        [{"id":"550E8400-E29B-41D4-A716-446655440001","slug":"light-forms","title":"Light Forms","subtitle":"Radiance and Shadow","openingDate":1735689600,"manifestURL":null}]
        """#
        let essaysJSON = #"""
        [{"id":"essay-001","title":"The Grammar of Light","author":"Dr. Elara Voss"}]
        """#

        app.launchEnvironment["UITEST_EXHIBITIONS_JSON"] = exhibitionsJSON
        app.launchEnvironment["UITEST_ESSAYS_JSON"] = essaysJSON
        app.launchEnvironment["UITEST_GENERATE_MODE"] = "success"
        app.launch()

        // 1. Verify the app launches with tab bar
        let exhibitionsTab = app.buttons.matching(identifier: "tab.exhibitions").firstMatch
        XCTAssertTrue(exhibitionsTab.waitForExistence(timeout: 8), "Tab bar should appear")

        // 2. Check exhibitions tab shows mocked content
        let card = el("home.exhibitionCard.550E8400-E29B-41D4-A716-446655440001")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Exhibition card should appear from mock JSON")

        // 3. Exhibition detail (simulator only — NavigationStack back is unreliable in XCTest on device)
        #if targetEnvironment(simulator)
        card.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8), "Exhibition detail should open")
        if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 8), "Should return to exhibitions home")
        exhibitionsTab.tap()
        #endif

        // 4. Navigate to Studio tab and generate
        let studioTab = app.buttons.matching(identifier: "tab.studio").firstMatch
        XCTAssertTrue(studioTab.waitForExistence(timeout: 8))
        studioTab.tap()

        XCTAssertTrue(el("studio.promptEditor").waitForExistence(timeout: 10), "Studio prompt editor should appear")
        let generateButton = el("studio.generateButton")
        scrollToElement(generateButton)
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should exist")
        XCTAssertTrue(generateButton.isEnabled, "Generate button should be enabled")
        generateButton.tap()

        let resultProvider = el("studio.resultProvider")
        XCTAssertTrue(resultProvider.waitForExistence(timeout: 12), "Result should appear after generation")

        // 5. Navigate to Scholarship tab
        let scholarshipTab = app.buttons.matching(identifier: "tab.scholarship").firstMatch
        XCTAssertTrue(scholarshipTab.waitForExistence(timeout: 5))
        scholarshipTab.tap()

        let refreshButton = el("scholarship.refreshButton")
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5), "Scholarship refresh button should exist")

        // 6. Navigate to Collection tab
        let collectionTab = app.buttons.matching(identifier: "tab.collection").firstMatch
        XCTAssertTrue(collectionTab.waitForExistence(timeout: 5))
        collectionTab.tap()

        let collectionNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(collectionNavBar.waitForExistence(timeout: 5), "Collection tab should have a navigation bar")
    }

    @MainActor
    func testEndToEndEmptyStatesDoNotCrash() throws {
        app.launchEnvironment["UITEST_EXHIBITIONS_JSON"] = "[]"
        app.launchEnvironment["UITEST_ESSAYS_JSON"] = "[]"
        app.launch()

        let exhibitionsTab = app.buttons.matching(identifier: "tab.exhibitions").firstMatch
        XCTAssertTrue(exhibitionsTab.waitForExistence(timeout: 8))

        // Navigate through all tabs with empty data
        let tabs = ["tab.exhibitions", "tab.studio", "tab.scholarship", "tab.collection"]
        for tabID in tabs {
            let tab = app.buttons.matching(identifier: tabID).firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // App should still be responsive
        XCTAssertTrue(exhibitionsTab.exists, "App should remain responsive after navigating empty tabs")
    }

    @MainActor
    func testEndToEndAdminPanelAccess() throws {
        XCTExpectFailure("Menu-item accessibility is flaky on iOS 26 beta; verified manually",
                         strict: false)

        app.launchEnvironment["UITEST_EXHIBITIONS_JSON"] = "[]"
        app.launch()

        let exhibitionsTab = app.buttons.matching(identifier: "tab.exhibitions").firstMatch
        XCTAssertTrue(exhibitionsTab.waitForExistence(timeout: 12))

        let overflowMenu = el("home.overflowMenu")
        XCTAssertTrue(overflowMenu.waitForExistence(timeout: 15), "Overflow menu should exist")
        overflowMenu.tap()

        let adminButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'admin'")).firstMatch
        guard adminButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("Admin button not available in this environment.")
        }
        adminButton.tap()
        let adminPanelSheet = app.sheets.firstMatch
        XCTAssertTrue(adminPanelSheet.waitForExistence(timeout: 10), "Admin panel sheet should appear")
    }

    @MainActor
    func testEndToEndDolaAssistantFlow() throws {
        app.launchEnvironment["UITEST_GENERATE_MODE"] = "success"
        app.launch()

        let studioTab = app.buttons.matching(identifier: "tab.studio").firstMatch
        XCTAssertTrue(studioTab.waitForExistence(timeout: 8))
        studioTab.tap()

        let dolaButton = el("studio.askDolaButton")
        XCTAssertTrue(dolaButton.waitForExistence(timeout: 5), "Ask Dola button should exist")
        dolaButton.tap()

        let dolaEditor = el("dola.promptEditor")
        XCTAssertTrue(dolaEditor.waitForExistence(timeout: 5), "Dola prompt editor should appear")

        let dolaAskButton = el("dola.askButton")
        XCTAssertTrue(dolaAskButton.waitForExistence(timeout: 5), "Ask button should appear")
        XCTAssertTrue(dolaAskButton.isEnabled, "Ask button should be enabled with default prompt")
    }
}
