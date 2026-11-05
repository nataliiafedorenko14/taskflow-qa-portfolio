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
