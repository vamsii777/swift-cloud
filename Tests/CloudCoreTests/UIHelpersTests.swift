import Testing

@testable import CloudCore

@Suite("UI Helpers Tests")
struct UIHelpersTests {
    @Test("Spinner line limit clamps to zero")
    func spinnerLineLimitClampsToZero() {
        #expect(UI.Spinner.spinnerLineLimit(terminalWidth: 0) == 0)
        #expect(UI.Spinner.spinnerLineLimit(terminalWidth: 9) == 0)
    }

    @Test("Spinner line truncation is safe for narrow terminals")
    func spinnerLineTruncationIsSafeForNarrowTerminals() {
        #expect(UI.Spinner.spinnerLine("hello world", terminalWidth: 9) == "")
        #expect(UI.Spinner.spinnerLine("hello world", terminalWidth: 15) == "hello")
    }
}
