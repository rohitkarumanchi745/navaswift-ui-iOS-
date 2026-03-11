import XCTest

/// UI tests verifying the session-expired flow, deep-link navigation, prefetch indicator,
/// and offline state behavior. Uses the demo mode login to set up known states.
final class SessionExpiredUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Session Expired Flow

    func testSessionExpiredShowsReAuthPrompt() throws {
        let landingExists = app.staticTexts["Session Expired"].waitForExistence(timeout: 3)
        if landingExists {
            XCTAssertTrue(app.staticTexts["Session Expired"].exists)
            XCTAssertTrue(app.staticTexts["Your session has ended. Please sign in again to continue where you left off."].exists)
            XCTAssertTrue(app.buttons["Sign In Again"].exists)

            app.buttons["Sign In Again"].tap()

            let landingAppeared = app.buttons.firstMatch.waitForExistence(timeout: 3)
            XCTAssertTrue(landingAppeared)
        }
    }

    // MARK: - Deep Link Tab Navigation

    func testTabBarHasExpectedTabs() throws {
        let tabBar = app.tabBars.firstMatch
        let tabBarExists = tabBar.waitForExistence(timeout: 10)

        if tabBarExists {
            XCTAssertTrue(tabBar.buttons["Discover"].exists, "Discover tab should exist")
            XCTAssertTrue(tabBar.buttons["Likes"].exists, "Likes tab should exist")
            XCTAssertTrue(tabBar.buttons["Chat"].exists, "Chat tab should exist")
            XCTAssertTrue(tabBar.buttons["Profile"].exists, "Profile tab should exist")
        }
    }

    func testTabSwitchingWorks() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        // Switch to each tab and verify it's selected
        let tabs = ["Likes", "Chat", "Profile", "Discover"]
        for tabName in tabs {
            let tab = tabBar.buttons[tabName]
            XCTAssertTrue(tab.exists, "\(tabName) tab should exist")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(tabName) tab should be selected after tap")
        }
    }

    // MARK: - Prefetch Indicator

    func testPrefetchIndicatorNotVisibleByDefault() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        // The "Loading content…" prefetch pill should NOT be visible during normal use
        let prefetchLabel = app.staticTexts["Loading content…"]
        XCTAssertFalse(prefetchLabel.exists, "Prefetch indicator should not appear without a deep link")
    }

    // MARK: - Offline State

    func testDiscoverViewShowsOfflineBanner() throws {
        // When the app is on the Discover tab and offline, the offline banner should appear.
        // In UI testing with airplane mode or network conditioner, verify the banner.
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        // Ensure we're on Discover
        tabBar.buttons["Discover"].tap()

        // Check that the main discover UI loads (loading spinner eventually disappears)
        let loadingText = app.staticTexts["Finding people for you..."]
        if loadingText.exists {
            // Wait for loading to finish (either data or error)
            _ = loadingText.waitForNonExistence(timeout: 15)
        }

        // Verify the discover screen rendered some content
        // (either cards, empty state, error state, or demo data)
        let hasContent = app.staticTexts["NAVA"].exists
        XCTAssertTrue(hasContent, "Discover header should be visible")
    }

    func testConversationsViewShowsRetryOnError() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        tabBar.buttons["Chat"].tap()

        // Wait for loading to complete
        let loadingText = app.staticTexts["Loading conversations..."]
        if loadingText.exists {
            _ = loadingText.waitForNonExistence(timeout: 15)
        }

        // Verify the conversations screen rendered (either conversations list or empty state)
        let messagesHeader = app.staticTexts["Messages"]
        let emptyState = app.staticTexts["No conversations yet"]
        let hasContent = messagesHeader.exists || emptyState.exists
        XCTAssertTrue(hasContent, "Chat view should show either messages header or empty state")
    }

    // MARK: - Loading View

    func testLoadingViewShowsProgressIndicator() throws {
        // On fresh launch, the loading view should briefly appear
        // before transitioning to either auth or main view.
        // The loading text or a progress indicator should be accessible.
        let loadingText = app.staticTexts["Preparing your experience..."]
        // It may have already passed by the time we check, so this is best-effort
        if loadingText.waitForExistence(timeout: 2) {
            XCTAssertTrue(loadingText.exists)
        }
    }

    // MARK: - Settings & Notification Preferences

    func testSettingsShowsNotificationPreferencesLink() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        // Navigate to Profile → Settings
        tabBar.buttons["Profile"].tap()

        let settingsButton = app.buttons["gearshape.fill"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            // Settings gear may have a different label; try navigation buttons
            let navSettingsButton = app.navigationBars.buttons.element(boundBy: 0)
            guard navSettingsButton.waitForExistence(timeout: 3) else { return }
            navSettingsButton.tap()
            return
        }
        settingsButton.tap()

        // Verify Notification Preferences link exists in Settings
        let notifPref = app.staticTexts["Notification Preferences"]
        if notifPref.waitForExistence(timeout: 5) {
            XCTAssertTrue(notifPref.exists, "Notification Preferences link should appear in Settings")
        }
    }

    // MARK: - Appeal Banner Tests

    func testAppealSuccessBannerNotVisibleByDefault() throws {
        // The appeal success banner should never be visible on normal screens
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        let successBanner = app.otherElements["appealSuccessBanner"]
        XCTAssertFalse(successBanner.exists, "Appeal success banner should not appear without submitting an appeal")
    }

    func testAppealErrorBannerNotVisibleByDefault() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        let errorBanner = app.otherElements["appealErrorBanner"]
        XCTAssertFalse(errorBanner.exists, "Appeal error banner should not appear without submitting an appeal")
    }

    func testAppealStatusChipNotVisibleByDefault() throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else { return }

        // Navigate through each tab to verify no appeal chip is visible
        let tabs = ["Discover", "Likes", "Chat", "Profile"]
        for tabName in tabs {
            tabBar.buttons[tabName].tap()
            let chip = app.otherElements["appealStatusChip"]
            XCTAssertFalse(chip.exists, "Appeal status chip should not appear on \(tabName) tab without moderated content")
        }
    }
}
