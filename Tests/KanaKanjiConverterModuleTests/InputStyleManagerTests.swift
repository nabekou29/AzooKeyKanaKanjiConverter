@testable import KanaKanjiConverterModule
import XCTest

final class InputStyleManagerTests: XCTestCase {
    func testCustomTableLoading() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("custom.tsv")
        try "a\tあ\nka\tか\n".write(to: url, atomically: true, encoding: .utf8)
        let table = InputStyleManager.shared.table(for: .custom(url))
        XCTAssertEqual(table.toHiragana(currentText: [], added: .character("a")), Array("あ"))
        XCTAssertEqual(table.toHiragana(currentText: ["k"], added: .character("a")), Array("か"))
    }

    func testCustomTableLoadingWithBlankLines() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("custom.tsv")
        try "a\tあ\n\n\nka\tか\n".write(to: url, atomically: true, encoding: .utf8)
        let table = InputStyleManager.shared.table(for: .custom(url))
        XCTAssertEqual(table.toHiragana(currentText: [], added: .character("a")), Array("あ"))
        XCTAssertEqual(table.toHiragana(currentText: ["k"], added: .character("a")), Array("か"))
    }

    func testCustomTableLoadingWithCommentLines() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("custom.tsv")
        try "a\tあ\n# here is comment\nka\tか\n".write(to: url, atomically: true, encoding: .utf8)
        let table = InputStyleManager.shared.table(for: .custom(url))
        XCTAssertEqual(table.toHiragana(currentText: [], added: .character("a")), Array("あ"))
        XCTAssertEqual(table.toHiragana(currentText: ["k"], added: .character("a")), Array("か"))
    }

    func testCustomTableLoadingWithSpecialTokens() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("custom_special.tsv")
        let lines = [
            "n{any character}\tん{any character}",
            "n{composition-separator}\tん",
            "{lbracket}{rbracket}\t{}"
        ].joined(separator: "\n")
        try lines.write(to: url, atomically: true, encoding: .utf8)
        let table = InputStyleManager.shared.table(for: .custom(url))
        // n<any> -> ん<any>
        XCTAssertEqual(table.toHiragana(currentText: ["n"], added: .character("a")), Array("んa"))
        // n followed by end-of-text -> ん
        XCTAssertEqual(table.toHiragana(currentText: ["n"], added: .compositionSeparator), Array("ん"))
        // "{" then "}" -> "{}"
        XCTAssertEqual(table.toHiragana(currentText: ["{"], added: .character("}")), Array("{}"))
    }
}
