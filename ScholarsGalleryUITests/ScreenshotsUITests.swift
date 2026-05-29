import XCTest

final class ScreenshotsUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_EXHIBITIONS_JSON"] = #"""
        [{"id":"550E8400-E29B-41D4-A716-446655440001","slug":"light-forms","title":"Light Forms","subtitle":"Radiance and Shadow","openingDate":1735689600,"manifestURL":null}]
        """#
        app.launchEnvironment["UITEST_ESSAYS_JSON"] = #"""
        [{"id":"essay-001","title":"The Grammar of Light","author":"Dr. Elara Voss"}]
        """#
        app.launchEnvironment["UITEST_GENERATE_MODE"] = "success"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureExhibitionsTab() throws {
        app.launch()
        XCTAssertTrue(app.buttons.matching(identifier: "tab.exhibitions").firstMatch.waitForExistence(timeout: 8))
        capture("01-ExhibitionsTab")
    }

    @MainActor
    func testCaptureStudioTab() throws {
        app.launch()
        let studioTab = app.buttons.matching(identifier: "tab.studio").firstMatch
        XCTAssertTrue(studioTab.waitForExistence(timeout: 8))
        studioTab.tap()
        capture("02-StudioTab")
    }

    @MainActor
    func testCaptureScholarshipTab() throws {
        app.launch()
        let scholarshipTab = app.buttons.matching(identifier: "tab.scholarship").firstMatch
        XCTAssertTrue(scholarshipTab.waitForExistence(timeout: 8))
        scholarshipTab.tap()
        capture("03-ScholarshipTab")
    }

    @MainActor
    func testCaptureCollectionTab() throws {
        app.launch()
        let collectionTab = app.buttons.matching(identifier: "tab.collection").firstMatch
        XCTAssertTrue(collectionTab.waitForExistence(timeout: 8))
        collectionTab.tap()
        capture("04-CollectionTab")
    }

    @MainActor
    func testCaptureExhibitionDetail() throws {
        app.launch()
        let card = el("home.exhibitionCard.550E8400-E29B-41D4-A716-446655440001")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        capture("05-ExhibitionDetail")
    }

    @MainActor
    func testCaptureArtworkGeneration() throws {
        app.launch()
        let studioTab = app.buttons.matching(identifier: "tab.studio").firstMatch
        XCTAssertTrue(studioTab.waitForExistence(timeout: 8))
        studioTab.tap()
        let generateButton = el("studio.generateButton")
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))
        generateButton.tap()
        let resultProvider = el("studio.resultProvider")
        XCTAssertTrue(resultProvider.waitForExistence(timeout: 12))
        capture("06-ArtworkGenerationResult")
    }
}
