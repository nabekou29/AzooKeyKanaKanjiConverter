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

        // n<any> -> ん<any>
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .character("。")), Array("ん。"))
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .character("+")), Array("ん+"))
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .character("N")), Array("んN"))
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .compositionSeparator), Array("ん"))

        // nyu
        XCTAssertEqual(table.toHiragana(currentText: Array("ny"), added: .character("u")), Array("にゅ"))
    }

    func testAny1Cases() throws {
        let table = InputTable(pieceHiraganaChanges: [
            [.any1, .any1]: [.character("😄")],
            [.piece(.character("s")), .piece(.character("s"))]: [.character("ß")],
            [.piece(.character("a")), .piece(.character("z")), .piece(.character("z"))]: [.character("Q")],
            [.any1, .any1, .any1]: [.character("["), .any1, .character("]")],
            [.piece(.character("n")), .any1]: [.character("ん"), .any1]
        ])
        XCTAssertEqual(table.toHiragana(currentText: Array("a"), added: .character("b")), Array("ab"))
        XCTAssertEqual(table.toHiragana(currentText: Array("abc"), added: .character("d")), Array("abcd"))
        XCTAssertEqual(table.toHiragana(currentText: Array(""), added: .character("z")), Array("z"))
        XCTAssertEqual(table.toHiragana(currentText: Array("z"), added: .character("z")), Array("😄"))
        XCTAssertEqual(table.toHiragana(currentText: Array("z"), added: .character("s")), Array("zs"))
        XCTAssertEqual(table.toHiragana(currentText: Array("s"), added: .character("s")), Array("ß"))
        XCTAssertEqual(table.toHiragana(currentText: Array("az"), added: .character("z")), Array("Q"))
        XCTAssertEqual(table.toHiragana(currentText: Array("ss"), added: .character("s")), Array("[s]"))
        XCTAssertEqual(table.toHiragana(currentText: Array("sr"), added: .character("s")), Array("srs"))
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .character("t")), Array("んt"))
        XCTAssertEqual(table.toHiragana(currentText: Array("n"), added: .character("n")), Array("んn"))
    }
}
