import XCTest
@testable import KanaKanjiConverterModule

final class TimeExpressionTests: XCTestCase {
    func testConvertToTimeExpression() {
        let converter = KanaKanjiConverter()

        // Test 3-digit numbers
        XCTAssertEqual(converter.convertToTimeExpression(123).first?.text, "1:23")
        XCTAssertEqual(converter.convertToTimeExpression(945).first?.text, "9:45")
        XCTAssertEqual(converter.convertToTimeExpression(760).first?.text, "7:60")
        XCTAssertTrue(converter.convertToTimeExpression(761).isEmpty) // Invalid minute

        // Test 4-digit numbers
        XCTAssertEqual(converter.convertToTimeExpression(1234).first?.text, "12:34")
        XCTAssertEqual(converter.convertToTimeExpression(9450).first?.text, "09:45")
        XCTAssertEqual(converter.convertToTimeExpression(7600).first?.text, "07:60")
        XCTAssertTrue(converter.convertToTimeExpression(1360).isEmpty) // Invalid hour
        XCTAssertTrue(converter.convertToTimeExpression(1261).isEmpty) // Invalid minute
    }

    func testToTimeExpressionCandidates() async throws {
        let converter = KanaKanjiConverter()
        var c = ComposingText()
        
        // Test 3-digit numbers
        c.insertAtCursorPosition("123", inputStyle: .direct)
        var results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "1:23"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("945", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "9:45"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("760", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "7:60"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("761", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertFalse(results.mainResults.contains(where: {$0.text == "7:61"})) // Invalid minute
        
        // Test 4-digit numbers
        c = ComposingText()
        c.insertAtCursorPosition("1234", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "12:34"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("9450", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "09:45"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("7600", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertTrue(results.mainResults.contains(where: {$0.text == "07:60"}))
        
        c = ComposingText()
        c.insertAtCursorPosition("1360", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertFalse(results.mainResults.contains(where: {$0.text == "13:60"})) // Invalid hour
        
        c = ComposingText()
        c.insertAtCursorPosition("1261", inputStyle: .direct)
        results = await converter.requestCandidates(c, options: ConvertRequestOptions())
        XCTAssertFalse(results.mainResults.contains(where: {$0.text == "12:61"})) // Invalid minute
    }
}
