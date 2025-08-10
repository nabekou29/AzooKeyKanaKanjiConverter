import Algorithms
import Foundation
import SwiftUtils

extension Kana2Kanji {
    // Compute matched bytes with constraint and total candidate bytes for (prev-chain + currentWord)
    private func computeMatchedAndTotalLength(prev: RegisteredNode?, currentWord: String, constraintBytes: [UInt8]) -> (matched: Int, total: Int) {
        // collect words from prev chain in forward order
        var words: [String] = []
        var p = prev
        while let node = p {
            if !node.data.word.isEmpty {
                words.append(node.data.word)
            }
            p = node.prev
        }
        words.reverse()
        words.append(currentWord)

        // total = sum of utf8 counts (cheap per word)
        let total = words.reduce(0) { $0 + $1.utf8.count }

        // matched = compare up to first mismatch or until constraint end
        var ci = 0
        if !constraintBytes.isEmpty {
            outer: for w in words {
                if ci >= constraintBytes.count {
                    break
                }
                for b in w.utf8 {
                    if ci >= constraintBytes.count {
                        break outer
                    }
                    if b != constraintBytes[ci] {
                        break outer
                    }
                    ci += 1
                }
            }
        }
        // このprevのutf8カウントはtotalで、そのうちconstraintBytesと一致する部分がci
        return (matched: ci, total: total)
    }

    // Extend match with next word starting from current matched index
    private func extendMatched(matched: Int, nextWord: String, constraintBytes: [UInt8]) -> (matched: Int, mismatch: Bool) {
        var ci = matched
        if ci >= constraintBytes.count {
            return (ci, false)
        }
        for b in nextWord.utf8 {
            if ci >= constraintBytes.count {
                return (ci, false)
            }
            if b != constraintBytes[ci] {
                return (ci, true)
            }
            ci += 1
        }
        return (ci, false)
    }

    /// カナを漢字に変換する関数, 前提はなくかな列が与えられた場合。
    /// - Parameters:
    ///   - inputData: 入力データ。
    ///   - N_best: N_best。
    /// - Returns:
    ///   変換候補。
    /// ### 実装状況
    /// (0)多用する変数の宣言。
    ///
    /// (1)まず、追加された一文字に繋がるノードを列挙する。
    ///
    /// (2)次に、計算済みノードから、(1)で求めたノードにつながるようにregisterして、N_bestを求めていく。
    ///
    /// (3)(1)のregisterされた結果をresultノードに追加していく。この際EOSとの連接計算を行っておく。
    ///
    /// (4)ノードをアップデートした上で返却する。
    func kana2lattice_all_with_prefix_constraint(_ inputData: ComposingText, N_best: Int, constraint: PrefixConstraint) -> (result: LatticeNode, lattice: Lattice) {
        debug("新規に計算を行います。inputされた文字列は\(inputData.input.count)文字分の\(inputData.convertTarget)。制約は\(constraint)")
        let result: LatticeNode = LatticeNode.EOSNode
        let inputCount: Int = inputData.input.count
        let surfaceCount = inputData.convertTarget.count
        let indexMap = LatticeDualIndexMap(inputData)
        let latticeIndices = indexMap.indices(inputCount: inputCount, surfaceCount: surfaceCount)
        let rawNodes = latticeIndices.map { index in
            let inputRange: (startIndex: Int, endIndexRange: Range<Int>?)? = if let iIndex = index.inputIndex {
                (iIndex, nil)
            } else {
                nil
            }
            let surfaceRange: (startIndex: Int, endIndexRange: Range<Int>?)? = if let sIndex = index.surfaceIndex {
                (sIndex, nil)
            } else {
                nil
            }
            return dicdataStore.lookupDicdata(
                composingText: inputData,
                inputRange: inputRange,
                surfaceRange: surfaceRange,
                needTypoCorrection: false
            )
        }
        let lattice: Lattice = Lattice(
            inputCount: inputCount,
            surfaceCount: surfaceCount,
            rawNodes: rawNodes
        )
        // 「i文字目から始まるnodes」に対して
        for (isHead, nodeArray) in lattice.indexedNodes(indices: latticeIndices) {
            // それぞれのnodeに対して
            for node in nodeArray {
                if node.prevs.isEmpty {
                    continue
                }
                // 生起確率を取得する。
                let wValue: PValue = node.data.value()
                if isHead {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue + self.dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                } else {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue}
                }
                // 変換した文字数
                let nextIndex = indexMap.dualIndex(for: node.range.endIndex)
                // 文字数がcountと等しい場合登録する
                let constraintBytes = constraint.constraint
                if nextIndex.surfaceIndex == surfaceCount {
                    // Precompute matched/total lengths per prev for (prev + current word)
                    let mtPerPrev: [(matched: Int, total: Int)] = node.prevs.indices.map { idx in
                        self.computeMatchedAndTotalLength(prev: node.prevs[idx], currentWord: node.data.word, constraintBytes: constraintBytes)
                    }
                    let cLen = constraintBytes.count
                    for index in node.prevs.indices {
                        // 学習データやユーザ辞書由来の場合は素通しする
                        if node.data.metadata.isDisjoint(with: [.isLearned, .isFromUserDictionary]) {
                            let (matched, total) = mtPerPrev[index]
                            // 最終チェック（EOS時の条件に合わせる）
                            let condition = if constraint.hasEOS {
                                matched == cLen && total == cLen
                            } else {
                                matched == cLen
                            }
                            guard condition else {
                                continue
                            }
                        }
                        let newnode: RegisteredNode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                } else {
                    // Precompute matched/total lengths per prev for (prev + current word)
                    let mtPerPrev: [(matched: Int, total: Int)] = node.prevs.indices.map { idx in
                        self.computeMatchedAndTotalLength(prev: node.prevs[idx], currentWord: node.data.word, constraintBytes: constraintBytes)
                    }
                    let cLen = constraintBytes.count
                    // nodeの繋がる次にあり得る全てのnextnodeに対して
                    for nextnode in lattice[index: nextIndex] {
                        // クラスの連続確率を計算する。
                        let ccValue: PValue = self.dicdataStore.getCCValue(node.data.rcid, nextnode.data.lcid)
                        // nodeの持っている全てのprevnodeに対して
                        for (index, value) in node.values.enumerated() {
                            let newValue: PValue = ccValue + value
                            // 追加すべきindexを取得する
                            let lastindex: Int = (nextnode.prevs.lastIndex(where: {$0.totalValue >= newValue}) ?? -1) + 1
                            if lastindex == N_best {
                                continue
                            }
                            // 制約チェックは重いので、必要なものに対してのみ行う
                            // common prefixが単語か制約のどちらかに一致している必要
                            // 制約 AB 単語 ABC (OK)
                            // 制約 AB 単語 A   (OK)
                            // 制約 AB 単語 AC  (NG)
                            // ただし、学習データやユーザ辞書由来の場合は素通しする
                            if nextnode.data.metadata.isDisjoint(with: [.isLearned, .isFromUserDictionary]) {
                                let (matchedPrev, totalPrev) = mtPerPrev[index]
                                // ensure no prior mismatch
                                guard matchedPrev == min(totalPrev, cLen) else {
                                    continue
                                }
                                let nextLen = nextnode.data.word.utf8.count
                                // matchedPrevまではconstraintBytesと一致しているので、その先をチェックする
                                let (matchedExt, mismatch) = self.extendMatched(matched: matchedPrev, nextWord: nextnode.data.word, constraintBytes: constraintBytes)
                                if mismatch {
                                    continue
                                }
                                let newTotal = totalPrev + nextLen
                                let ok: Bool = if constraint.hasEOS {
                                    // require strict prefix of constraint
                                    matchedExt == newTotal && newTotal < cLen
                                } else {
                                    // accept either: constraint is prefix of candidate, or candidate is prefix of constraint
                                    (matchedExt == cLen) || (newTotal <= cLen && matchedExt == newTotal)
                                }
                                guard ok else {
                                    continue
                                }
                            }
                            // カウントがオーバーしている場合は除去する
                            if nextnode.prevs.count >= N_best {
                                nextnode.prevs.removeLast()
                            }
                            let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                            // removeしてからinsertした方が速い (insertはO(N)なので)
                            nextnode.prevs.insert(newnode, at: lastindex)
                        }
                    }
                }
            }
        }
        return (result: result, lattice: lattice)
    }

}
