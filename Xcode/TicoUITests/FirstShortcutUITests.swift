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

        // O mesmo contrato de criação e persistência passa agora pelas três
        // etapas visuais. O teste continua isolado e não executa ações reais.
        let action = app.buttons["Centralizar janela"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.click()
        app.buttons["tico.composer.continue"].click()

        let recordButton = app.buttons["tico.composer.record"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.click()
        app.typeKey("s", modifierFlags: [.command, .option])
        recordButton.click()
        let continueButton = app.buttons["tico.composer.continue"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.click()

        let nameField = app.textFields["tico.composer.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        revealReviewControl(nameField)
        nameField.click()
        nameField.typeKey("a", modifierFlags: .command)
        nameField.typeText("Minha regra E2E")

        let enabledToggle = app.descendants(matching: .any)["tico.composer.enabled"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        revealReviewControl(enabledToggle)
        enabledToggle.click()
        assertSwitchIsOff(enabledToggle)

        let saveButton = app.buttons["tico.composer.save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()
        XCTAssertTrue(saveButton.waitForNonExistence(timeout: 5))
        assertSidebarStatusContains("0 de 3 regras ativas")

        app.terminate()
        app = configuredApplication()
        app.launch()
        ensureMainWindowIsOpen()

        assertSidebarStatusContains("0 de 3 regras ativas")
        let rulesSection = app.buttons["tico.section.rules"]
        XCTAssertTrue(rulesSection.waitForExistence(timeout: 5))
        rulesSection.click()

        let persistedRule = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Minha regra E2E")
        ).firstMatch
        XCTAssertTrue(
            persistedRule.waitForExistence(timeout: 5),
            app.debugDescription
        )
        persistedRule.click()

        let persistedToggle = app.switches["tico.rule.enabled"]
        XCTAssertTrue(persistedToggle.waitForExistence(timeout: 5))
        assertSwitchIsOff(persistedToggle)
    }

    /// A janela pode restaurar um tamanho compacto mesmo no processo isolado.
    /// Navega pela rolagem real, sem forçar uma janela ampla ou pular assertions.
    private func revealReviewControl(
        _ control: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let content = app.sheets.scrollViews.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), file: file, line: line)
        for _ in 0..<8 {
            let visible = content.frame.insetBy(dx: 0, dy: 8)
            if visible.contains(control.frame), control.isHittable { return }
            let delta: CGFloat = control.frame.maxY > visible.maxY ? -160 : 160
            content.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(content.frame.contains(control.frame) && control.isHittable,
                      "O controle da revisão precisa estar visível após rolar.", file: file, line: line)
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
