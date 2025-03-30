import Foundation

extension KanaKanjiConverter {
    func convertToTimeExpression(_ inputData: ComposingText) -> [Candidate] {
        var candidates: [Candidate] = []
        let numberString = inputData.convertTarget
        let firstPart = Int(numberString.prefix(2))!
        let secondPart = Int(numberString.suffix(2))!

        if numberString.count == 3 {
            let firstDigit = Int(numberString.prefix(1))!
            let lastTwoDigits = Int(numberString.suffix(2))!
            if (0...9).contains(firstDigit) && (0...59).contains(lastTwoDigits) {
                let timeExpression = "\(firstDigit):\(String(format: "%02d", lastTwoDigits))"
                let candidate = Candidate(
                    text: timeExpression,
                    value: -10,
                    correspondingCount: numberString.count,
                    lastMid: MIDData.一般.mid,
                    data: [DicdataElement(word: timeExpression, ruby: numberString, cid: CIDData.固有名詞.cid, mid: MIDData.一般.mid, value: -10)]
                )
                candidates.append(candidate)
            }
        } else if numberString.count == 4 {
            if (0...24).contains(firstPart) && (0...59).contains(secondPart) {
                let timeExpression = "\(String(format: "%02d", firstPart)):\(String(format: "%02d", secondPart))"
                let candidate = Candidate(
                    text: timeExpression,
                    value: -10,
                    correspondingCount: numberString.count,
                    lastMid: MIDData.一般.mid,
                    data: [DicdataElement(word: timeExpression, ruby: numberString, cid: CIDData.固有名詞.cid, mid: MIDData.一般.mid, value: -10)]
                )
                candidates.append(candidate)
            }
        }
        return candidates
    }
}
