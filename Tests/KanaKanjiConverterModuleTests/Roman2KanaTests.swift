@testable import KanaKanjiConverterModule
import XCTest

final class Roman2KanaTests: XCTestCase {
    func testToHiragana() throws {
        // xtsu -> っ
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array(""), added: "x"), Array("x"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("x"), added: "t"), Array("xt"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("xt"), added: "s"), Array("xts"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("xts"), added: "u"), Array("っ"))

        // kanto -> かんと
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array(""), added: "k"), Array("k"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("k"), added: "a"), Array("か"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("か"), added: "n"), Array("かn"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("かn"), added: "t"), Array("かんt"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("かんt"), added: "o"), Array("かんと"))

        // zl -> →
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array(""), added: "z"), Array("z"))
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("z"), added: "l"), Array("→"))

        // TT -> TT
        XCTAssertEqual(Roman2Kana.toHiragana(currentText: Array("T"), added: "T"), Array("TT"))
    }
}
