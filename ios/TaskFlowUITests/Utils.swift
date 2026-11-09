//
//  Utils.swift
//  TaskFlow
//
//  Created by Natasha on 14.09.2026.
//
import XCTest

extension XCUIElement {
    func deleteText() {
        tap()
        if let value = value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            typeText(deleteString)
        }
    }

    /// On recent iOS versions SwiftUI list rows are exposed as Cells whose
    /// inner Button is not hittable, so rows are tapped by center coordinate.
    /// The first tap may land while the screen is still settling, so retry
    /// until the expected marker of the destination screen appears.
    func tapUntilShows(_ marker: XCUIElement, attempts: Int = 3) {
        for _ in 1...attempts {
            if marker.waitForExistence(timeout: 3) { return }
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}

extension XCUIApplication {
    /// The "Projects" tab button, locale-independent (identified by its SF Symbol).
    var projectsTab: XCUIElement { tabBars.buttons["folder"] }
    /// The "Profile" tab button, locale-independent (identified by its SF Symbol).
    var profileTab: XCUIElement { tabBars.buttons["person.circle"] }
}

extension XCUIApplication {
    /// Dismisses the iOS "Save Password" system prompt if it appears after login.
    func dismissSavePasswordPromptIfPresent() {
        let labels = ["Not Now", "Never", "Don’t Save", "Don't Save"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            for label in labels {
                for button in [springboard.buttons[label], buttons[label], alerts.buttons[label]] {
                    if button.exists {
                        button.tap()
                        return
                    }
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }
}
