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
        let converter = KanaKanjiConverter()

        let input1 = makeDirectInput(direct: "123")
        let input2 = makeDirectInput(direct: "1234")
        let input3 = makeDirectInput(direct: "999")
        let input4 = makeDirectInput(direct: "1260")
        let input5 = makeDirectInput(direct: "1360")

        let candidates1 = await converter.convertToTimeExpression(input1)
        let candidates2 = await converter.convertToTimeExpression(input2)
        let candidates3 = await converter.convertToTimeExpression(input3)
        let candidates4 = await converter.convertToTimeExpression(input4)
        let candidates5 = await converter.convertToTimeExpression(input5)

        XCTAssertEqual(candidates1.count, 1)
        XCTAssertEqual(candidates1.first?.text, "1:23")

        XCTAssertEqual(candidates2.count, 1)
        XCTAssertEqual(candidates2.first?.text, "12:34")

        XCTAssertEqual(candidates3.count, 1)
        XCTAssertEqual(candidates3.first?.text, "9:99")

        XCTAssertEqual(candidates4.count, 1)
        XCTAssertEqual(candidates4.first?.text, "12:60")

        XCTAssertEqual(candidates5.count, 0)
    }
}
