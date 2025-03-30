import XCTest
@testable import KanaKanjiConverterModule

final class TimeExpressionTests: XCTestCase {
    func makeDirectInput(direct input: String) -> ComposingText {
        ComposingText(
            convertTargetCursorPosition: input.count,
            input: input.map {.init(character: $0, inputStyle: .direct)},
            convertTarget: input
        )
    }

    func testConvertToTimeExpression() async throws {
        let converter = await KanaKanjiConverter()

        // Test 3-digit numbers
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "123")).first?.text, "1:23")
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "945")).first?.text, "9:45")
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "760")).first?.text, "7:60")
        XCTAssertTrue(await converter.convertToTimeExpression(makeDirectInput(direct: "761")).isEmpty) // Invalid minute

        // Test 4-digit numbers
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "1234")).first?.text, "12:34")
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "9450")).first?.text, "09:45")
        XCTAssertEqual(await converter.convertToTimeExpression(makeDirectInput(direct: "7600")).first?.text, "07:60")
        XCTAssertTrue(await converter.convertToTimeExpression(makeDirectInput(direct: "1360")).isEmpty) // Invalid hour
        XCTAssertTrue(await converter.convertToTimeExpression(makeDirectInput(direct: "1261")).isEmpty) // Invalid minute
    }
}
