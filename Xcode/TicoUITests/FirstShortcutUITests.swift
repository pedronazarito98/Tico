import XCTest

final class FirstShortcutUITests: XCTestCase {
    private var app: XCUIApplication!
    private var dataDirectory: URL!
    private var defaultsSuite: String!

    override func setUpWithError() throws {
        continueAfterFailure = false

        let identifier = UUID().uuidString
        dataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TicoUITests-\(identifier)", isDirectory: true)
        defaultsSuite = "com.pedronazarito.Tico.ui-tests.\(identifier)"
        try FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )

        app = configuredApplication()
        app.launch()
        ensureMainWindowIsOpen()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        if let dataDirectory,
           FileManager.default.fileExists(atPath: dataDirectory.path) {
            try FileManager.default.removeItem(at: dataDirectory)
        }
    }

    func testFirstShortcutIsCreatedDisabledAndPersistsAfterRelaunch() {
        assertSidebarStatusContains("0 de 2 regras ativas")

        let newRuleButton = app.buttons["tico.toolbar.new-rule"]
        XCTAssertTrue(newRuleButton.waitForExistence(timeout: 5))
        newRuleButton.click()

        let nameField = app.textFields["tico.rule.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))

        let enabledToggle = app.switches["tico.rule.enabled"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        assertSwitchIsOff(enabledToggle)

        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Minha regra E2E")

        let saveButton = app.buttons["tico.rule.save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()
        XCTAssertFalse(saveButton.isEnabled)
        assertSidebarStatusContains("0 de 3 regras ativas")

        app.terminate()
        app = configuredApplication()
        app.launch()
        ensureMainWindowIsOpen()

        assertSidebarStatusContains("0 de 3 regras ativas")
        let rulesSection = app.buttons["tico.section.rules"]
        XCTAssertTrue(rulesSection.waitForExistence(timeout: 5))
        rulesSection.click()

        let persistedRule = app.buttons["Minha regra E2E"]
        XCTAssertTrue(
            persistedRule.waitForExistence(timeout: 5),
            app.debugDescription
        )
        persistedRule.click()

        let persistedToggle = app.switches["tico.rule.enabled"]
        XCTAssertTrue(persistedToggle.waitForExistence(timeout: 5))
        assertSwitchIsOff(persistedToggle)
    }

    private func configuredApplication() -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            "--ui-testing",
            "-ApplePersistenceIgnoreState",
            "YES"
        ]
        application.launchEnvironment = [
            "CFFIXED_USER_HOME": dataDirectory.path,
            "TICO_UI_TEST_DATA_DIRECTORY": dataDirectory.path,
            "TICO_UI_TEST_DEFAULTS_SUITE": defaultsSuite
        ]
        return application
    }

    private func ensureMainWindowIsOpen(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let mainWindow = app.windows.firstMatch
        if mainWindow.waitForExistence(timeout: 2) {
            return
        }

        let fileMenu = app.menuBars.menuBarItems["File"].firstMatch
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 5), file: file, line: line)
        fileMenu.click()

        let newWindowItem = app.menuItems["New Tico Window"].firstMatch
        XCTAssertTrue(newWindowItem.waitForExistence(timeout: 5), file: file, line: line)
        newWindowItem.click()

        XCTAssertTrue(
            mainWindow.waitForExistence(timeout: 10),
            app.debugDescription,
            file: file,
            line: line
        )
    }

    private func assertSidebarStatusContains(
        _ expectedText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let status = app.descendants(matching: .any)["tico.sidebar.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), file: file, line: line)
        let accessibleText = [status.label, status.value as? String]
            .compactMap { $0 }
            .joined(separator: " ")
        XCTAssertTrue(
            accessibleText.contains(expectedText),
            "Status atual: \(accessibleText)",
            file: file,
            line: line
        )
    }

    private func assertSwitchIsOff(
        _ toggle: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let number = toggle.value as? NSNumber {
            XCTAssertFalse(number.boolValue, file: file, line: line)
            return
        }

        if let text = toggle.value as? String {
            XCTAssertEqual(text, "0", file: file, line: line)
            return
        }

        XCTFail("Valor inesperado para o switch: \(String(describing: toggle.value))", file: file, line: line)
    }
}
