import SwiftUtils

struct TypoCorrectionGenerator {
    init(inputs: [ComposingText.InputElement], leftIndex left: Int, rightIndexRange: Range<Int>) {
        self.inputs = inputs
        self.left = left
        self.rightIndexRange = rightIndexRange

        let count = rightIndexRange.endIndex - left
        self.count = count
        self.nodes = (0..<count).map {(i: Int) in
            TypoCorrection.lengths.flatMap {(k: Int) -> [TypoCorrection.TypoCandidate] in
                let j = i + k
                if count <= j {
                    return []
                }
                return TypoCorrection.getTypo(inputs[left + i ... left + j])
            }
        }
        // 深さ優先で列挙する
        self.stack = nodes[0].compactMap { typoCandidate in
            guard let firstElement = typoCandidate.inputElements.first else {
                return nil
            }
            if ComposingText.isLeftSideValid(first: firstElement, of: inputs, from: left) {
                var convertTargetElements = [ComposingText.ConvertTargetElement]()
                for element in typoCandidate.inputElements {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                return (convertTargetElements, typoCandidate.inputElements.last!, typoCandidate.inputElements.count, typoCandidate.weight)
            }
            return nil
        }
    }

    let maxPenalty: PValue = 3.5 * 3
    let inputs: [ComposingText.InputElement]
    let left: Int
    let rightIndexRange: Range<Int>
    let nodes: [[TypoCorrection.TypoCandidate]]
    let count: Int

    var stack: [(convertTargetElements: [ComposingText.ConvertTargetElement], lastElement: ComposingText.InputElement, count: Int, penalty: PValue)]

    /// `target`で始まる場合は到達不可能であることを知らせる
    mutating func setUnreachablePath(target: some Collection<Character>) {
        self.stack = self.stack.filter { (convertTargetElements, lastElement, count, penalty) in
            var stablePrefix: [Character] = []
            loop: for item in convertTargetElements {
                switch item.inputStyle {
                case .direct:
                    stablePrefix.append(contentsOf: item.string)
                case .roman2kana:
                    // TODO: impl
                    var stableIndex = item.string.endIndex
                    for suffix in Roman2Kana.unstableSuffixes {
                        if item.string.hasSuffix(suffix) {
                            stableIndex = min(stableIndex, item.string.endIndex - suffix.count)
                        }
                    }
                    if stableIndex == item.string.endIndex {
                        stablePrefix.append(contentsOf: item.string)
                    } else {
                        // 全体が安定でない場合は、そこでbreakする
                        stablePrefix.append(contentsOf: item.string[0 ..< stableIndex])
                        break loop
                    }
                }
                // 安定なprefixがtargetをprefixに持つ場合、このstack内のアイテムについてもunreachableであることが分かるので、除去する
                if stablePrefix.hasPrefix(target) {
                    return false
                }
            }
            return true
        }
    }

    mutating func next() -> ([Character], (endIndex: Int, penalty: PValue))? {
        while let (convertTargetElements, lastElement, count, penalty) = self.stack.popLast() {
            var result: ([Character], (endIndex: Int, penalty: PValue))? = nil
            if rightIndexRange.contains(count + left - 1) {
                if let convertTarget = ComposingText.getConvertTargetIfRightSideIsValid(lastElement: lastElement, of: inputs, to: count + left, convertTargetElements: convertTargetElements)?.map({$0.toKatakana()}) {
                    result = (convertTarget, (count + left - 1, penalty))
                }
            }
            // エスケープ
            if self.nodes.endIndex <= count {
                if let result {
                    return result
                } else {
                    continue
                }
            }
            // 訂正数上限(3個)
            if penalty >= maxPenalty {
                var convertTargetElements = convertTargetElements
                let correct = [inputs[left + count]].map {ComposingText.InputElement(character: $0.character.toKatakana(), inputStyle: $0.inputStyle)}
                if count + correct.count > self.nodes.endIndex {
                    if let result {
                        return result
                    } else {
                        continue
                    }
                }
                for element in correct {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                stack.append((convertTargetElements, correct.last!, count + correct.count, penalty))
            } else {
                stack.append(contentsOf: self.nodes[count].compactMap {
                    if count + $0.inputElements.count > self.nodes.endIndex {
                        return nil
                    }
                    var convertTargetElements = convertTargetElements
                    for element in $0.inputElements {
                        ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                    }
                    if TypoCorrection.shouldBeRemovedForDicdataStore(components: convertTargetElements) {
                        return nil
                    }
                    return (
                        convertTargetElements: convertTargetElements,
                        lastElement: $0.inputElements.last!,
                        count: count + $0.inputElements.count,
                        penalty: penalty + $0.weight
                    )
                })
            }
            // このループで出力すべきものがある場合は出力する（yield）
            if let result {
                return result
            }
        }
        return nil
    }
}

// MARK: 誤り訂正用のAPI
enum TypoCorrection {
    fileprivate static func shouldBeRemovedForDicdataStore(components: [ComposingText.ConvertTargetElement]) -> Bool {
        // 判定に使うのは最初の1エレメントの最初の文字で十分
        guard let first = components.first?.string.first?.toKatakana() else {
            return false
        }
        return !CharacterUtils.isRomanLetter(first) && !DicdataStore.existLOUDS(for: first)
    }

    /// closedRangeでもらう
    /// 例えば`left=4, rightIndexRange=6..<10`の場合、`4...6, 4...7, 4...8, 4...9`の範囲で計算する
    /// `left <= rightIndexRange.startIndex`が常に成り立つ
    static func getRangesWithoutTypos(inputs: [ComposingText.InputElement], leftIndex left: Int, rightIndexRange: Range<Int>) -> [[Character]: Int] {
        let count = rightIndexRange.endIndex - left
        debug(#function, left, rightIndexRange, count)
        let nodes = (0..<count).map {(i: Int) in
            Self.lengths.flatMap {(k: Int) -> [TypoCandidate] in
                let j = i + k
                if count <= j {
                    return []
                }
                // frozen: trueとしているため、typo候補は含まれない
                return Self.getTypo(inputs[left + i ... left + j], frozen: true)
            }
        }

        // Performance Tuning Note：直接Dictionaryを作るのではなく、一度Arrayを作ってから最後にDictionaryに変換する方が、高速である
        var stringToInfo: [([Character], Int)] = []

        // 深さ優先で列挙する
        var stack: [(convertTargetElements: [ComposingText.ConvertTargetElement], lastElement: ComposingText.InputElement, count: Int)] = nodes[0].compactMap { typoCandidate in
            guard let firstElement = typoCandidate.inputElements.first else {
                return nil
            }
            if ComposingText.isLeftSideValid(first: firstElement, of: inputs, from: left) {
                var convertTargetElements = [ComposingText.ConvertTargetElement]()
                for element in typoCandidate.inputElements {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                return (convertTargetElements, typoCandidate.inputElements.last!, typoCandidate.inputElements.count)
            }
            return nil
        }
        while case .some((var convertTargetElements, let lastElement, let count)) = stack.popLast() {
            if rightIndexRange.contains(count + left - 1) {
                if let convertTarget = ComposingText.getConvertTargetIfRightSideIsValid(lastElement: lastElement, of: inputs, to: count + left, convertTargetElements: convertTargetElements)?.map({$0.toKatakana()}) {
                    stringToInfo.append((convertTarget, (count + left - 1)))
                }
            }
            // エスケープ
            if nodes.endIndex <= count {
                continue
            }
            stack.append(contentsOf: nodes[count].compactMap {
                if count + $0.inputElements.count > nodes.endIndex {
                    return nil
                }
                for element in $0.inputElements {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                if Self.shouldBeRemovedForDicdataStore(components: convertTargetElements) {
                    return nil
                }
                return (
                    convertTargetElements: convertTargetElements,
                    lastElement: $0.inputElements.last!,
                    count: count + $0.inputElements.count
                )
            })
        }
        return Dictionary(stringToInfo, uniquingKeysWith: {$0 < $1 ? $1 : $0})
    }


    static func getRangeWithTypos(inputs: [ComposingText.InputElement], leftIndex left: Int, rightIndex right: Int) -> [[Character]: PValue] {
        // 各iから始まる候補を列挙する
        // 例えばinput = [d(あ), r(s), r(i), r(t), r(s), d(は), d(は), d(れ)]の場合
        // nodes =      [[d(あ)], [r(s)], [r(i)], [r(t), [r(t), r(a)]], [r(s)], [d(は), d(ば), d(ぱ)], [d(れ)]]
        // となる
        let count = right - left + 1
        let nodes = (0..<count).map {(i: Int) in
            Self.lengths.flatMap {(k: Int) -> [TypoCandidate] in
                let j = i + k
                if count <= j {
                    return []
                }
                return Self.getTypo(inputs[left + i ... left + j])
            }
        }

        let maxPenalty: PValue = 3.5 * 3

        // 深さ優先で列挙する
        var stack: [(convertTargetElements: [ComposingText.ConvertTargetElement], lastElement: ComposingText.InputElement, count: Int, penalty: PValue)] = nodes[0].compactMap { typoCandidate in
            guard let firstElement = typoCandidate.inputElements.first else {
                return nil
            }
            if ComposingText.isLeftSideValid(first: firstElement, of: inputs, from: left) {
                var convertTargetElements = [ComposingText.ConvertTargetElement]()
                for element in typoCandidate.inputElements {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                return (convertTargetElements, typoCandidate.inputElements.last!, typoCandidate.inputElements.count, typoCandidate.weight)
            }
            return nil
        }

        var stringToPenalty: [([Character], PValue)] = []

        while let (convertTargetElements, lastElement, count, penalty) = stack.popLast() {
            if count + left - 1 == right {
                if let convertTarget = ComposingText.getConvertTargetIfRightSideIsValid(lastElement: lastElement, of: inputs, to: count + left, convertTargetElements: convertTargetElements)?.map({$0.toKatakana()}) {
                    stringToPenalty.append((convertTarget, penalty))
                }
                continue
            }
            // エスケープ
            if nodes.endIndex <= count {
                continue
            }
            // 訂正数上限(3個)
            if penalty >= maxPenalty {
                var convertTargetElements = convertTargetElements
                let correct = [inputs[left + count]].map {ComposingText.InputElement(character: $0.character.toKatakana(), inputStyle: $0.inputStyle)}
                if count + correct.count > nodes.endIndex {
                    continue
                }
                for element in correct {
                    ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                }
                stack.append((convertTargetElements, correct.last!, count + correct.count, penalty))
            } else {
                stack.append(contentsOf: nodes[count].compactMap {
                    if count + $0.inputElements.count > nodes.endIndex {
                        return nil
                    }
                    var convertTargetElements = convertTargetElements
                    for element in $0.inputElements {
                        ComposingText.updateConvertTargetElements(currentElements: &convertTargetElements, newElement: element)
                    }
                    if Self.shouldBeRemovedForDicdataStore(components: convertTargetElements) {
                        return nil
                    }
                    return (
                        convertTargetElements: convertTargetElements,
                        lastElement: $0.inputElements.last!,
                        count: count + $0.inputElements.count,
                        penalty: penalty + $0.weight
                    )
                })
            }
        }
        return Dictionary(stringToPenalty, uniquingKeysWith: max)
    }

    fileprivate static func getTypo(_ elements: some Collection<ComposingText.InputElement>, frozen: Bool = false) -> [TypoCandidate] {
        let key = elements.reduce(into: "") {$0.append($1.character)}.toKatakana()

        if (elements.allSatisfy {$0.inputStyle == .direct}) {
            let dictionary: [String: [TypoUnit]] = frozen ? [:] : Self.directPossibleTypo
            if key.count > 1 {
                return dictionary[key, default: []].map {
                    TypoCandidate(
                        inputElements: $0.value.map {ComposingText.InputElement(character: $0, inputStyle: .direct)},
                        weight: $0.weight
                    )
                }
            } else if key.count == 1 {
                var result = dictionary[key, default: []].map {
                    TypoCandidate(
                        inputElements: $0.value.map {ComposingText.InputElement(character: $0, inputStyle: .direct)},
                        weight: $0.weight
                    )
                }
                // そのまま
                result.append(TypoCandidate(inputElements: key.map {ComposingText.InputElement(character: $0, inputStyle: .direct)}, weight: 0))
                return result
            }
        }
        if (elements.allSatisfy {$0.inputStyle == .roman2kana}) {
            let dictionary: [String: [String]] = frozen ? [:] : Self.roman2KanaPossibleTypo
            if key.count > 1 {
                return dictionary[key, default: []].map {
                    TypoCandidate(
                        inputElements: $0.map {ComposingText.InputElement(character: $0, inputStyle: .roman2kana)},
                        weight: 3.5
                    )
                }
            } else if key.count == 1 {
                var result = dictionary[key, default: []].map {
                    TypoCandidate(
                        inputElements: $0.map {ComposingText.InputElement(character: $0, inputStyle: .roman2kana)},
                        weight: 3.5
                    )
                }
                // そのまま
                result.append(
                    TypoCandidate(inputElements: key.map {ComposingText.InputElement(character: $0, inputStyle: .roman2kana)}, weight: 0)
                )
                return result
            }
        }
        return []
    }

    fileprivate static let lengths = [0, 1]

    private struct TypoUnit: Equatable {
        var value: String
        var weight: PValue

        init(_ value: String, weight: PValue = 3.5) {
            self.value = value
            self.weight = weight
        }
    }

    struct TypoCandidate: Equatable {
        var inputElements: [ComposingText.InputElement]
        var weight: PValue
    }

    /// ダイレクト入力用
    private static let directPossibleTypo: [String: [TypoUnit]] = [
        "カ": [TypoUnit("ガ", weight: 7.0)],
        "キ": [TypoUnit("ギ")],
        "ク": [TypoUnit("グ")],
        "ケ": [TypoUnit("ゲ")],
        "コ": [TypoUnit("ゴ")],
        "サ": [TypoUnit("ザ")],
        "シ": [TypoUnit("ジ")],
        "ス": [TypoUnit("ズ")],
        "セ": [TypoUnit("ゼ")],
        "ソ": [TypoUnit("ゾ")],
        "タ": [TypoUnit("ダ", weight: 6.0)],
        "チ": [TypoUnit("ヂ")],
        "ツ": [TypoUnit("ッ", weight: 6.0), TypoUnit("ヅ", weight: 4.5)],
        "テ": [TypoUnit("デ", weight: 6.0)],
        "ト": [TypoUnit("ド", weight: 4.5)],
        "ハ": [TypoUnit("バ", weight: 4.5), TypoUnit("パ", weight: 6.0)],
        "ヒ": [TypoUnit("ビ"), TypoUnit("ピ", weight: 4.5)],
        "フ": [TypoUnit("ブ"), TypoUnit("プ", weight: 4.5)],
        "ヘ": [TypoUnit("ベ"), TypoUnit("ペ", weight: 4.5)],
        "ホ": [TypoUnit("ボ"), TypoUnit("ポ", weight: 4.5)],
        "バ": [TypoUnit("パ")],
        "ビ": [TypoUnit("ピ")],
        "ブ": [TypoUnit("プ")],
        "ベ": [TypoUnit("ペ")],
        "ボ": [TypoUnit("ポ")],
        "ヤ": [TypoUnit("ャ")],
        "ユ": [TypoUnit("ュ")],
        "ヨ": [TypoUnit("ョ")]
    ]

    private static let roman2KanaPossibleTypo: [String: [String]] = [
        "bs": ["ba"],
        "no": ["bo"],
        "li": ["ki"],
        "lo": ["ko"],
        "lu": ["ku"],
        "my": ["mu"],
        "tp": ["to"],
        "ts": ["ta"],
        "wi": ["wo"],
        "pu": ["ou"]
    ]
}
