@testable import KanaKanjiConverterModule
import XCTest

final class Roman2KanaTests: XCTestCase {
    func testToHiragana() throws {
        let table = InputStyleManager.shared.table(for: .defaultRomanToKana)
        // xtsu -> っ
        XCTAssertEqual(table.toHiragana(currentText: Array(""), added: .character("x")), Array("x"))
        XCTAssertEqual(table.toHiragana(currentText: Array("x"), added: .character("t")), Array("xt"))
        XCTAssertEqual(table.toHiragana(currentText: Array("xt"), added: .character("s")), Array("xts"))
        XCTAssertEqual(table.toHiragana(currentText: Array("xts"), added: .character("u")), Array("っ"))

        // kanto -> かんと
        XCTAssertEqual(table.toHiragana(currentText: Array(""), added: .character("k")), Array("k"))
        XCTAssertEqual(table.toHiragana(currentText: Array("k"), added: .character("a")), Array("か"))
        XCTAssertEqual(table.toHiragana(currentText: Array("か"), added: .character("n")), Array("かn"))
        XCTAssertEqual(table.toHiragana(currentText: Array("かn"), added: .character("t")), Array("かんt"))
        XCTAssertEqual(table.toHiragana(currentText: Array("かんt"), added: .character("o")), Array("かんと"))

        // zl -> →
        XCTAssertEqual(table.toHiragana(currentText: Array(""), added: .character("z")), Array("z"))
        XCTAssertEqual(table.toHiragana(currentText: Array("z"), added: .character("l")), Array("→"))

        // TT -> TT
        XCTAssertEqual(table.toHiragana(currentText: Array("T"), added: .character("T")), Array("TT"))
    }
}
