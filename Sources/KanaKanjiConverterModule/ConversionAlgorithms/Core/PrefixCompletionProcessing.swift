//
//  afterPartlyCompleted.swift
//  Keyboard
//
//  Created by ensan on 2020/09/14.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation
import SwiftUtils

extension Kana2Kanji {
    /// カナを漢字に変換する関数, 部分的に確定した後の場合。
    /// ### 実装方法
    /// (1)まず、計算済みnodeの確定分以降を取り出し、registeredにcompletedDataの値を反映したBOSにする。
    ///
    /// (2)次に、再度計算して良い候補を得る。
    func kana2lattice_afterComplete(_ inputData: ComposingText, completedData: Candidate, N_best: Int, previousResult: (inputData: ComposingText, lattice: Lattice), needTypoCorrection: Bool) -> (result: LatticeNode, lattice: Lattice) {
        debug("確定直後の変換、前は：", previousResult.inputData, "後は：", inputData)
        let count = inputData.input.count
        // (1)
        let start = RegisteredNode.fromLastCandidate(completedData)
        let lattice = Lattice(nodes: previousResult.lattice.nodes.suffix(count))
        for (i, nodeArray) in lattice.nodes.enumerated() {
            if i == .zero {
                for node in nodeArray {
                    node.prevs = [start]
                    // inputRangeを確定した部分のカウント分ずらす
                    node.inputRange = node.inputRange.startIndex - completedData.correspondingCount ..< node.inputRange.endIndex - completedData.correspondingCount
                }
            } else {
                for node in nodeArray {
                    node.prevs = []
                    // inputRangeを確定した部分のカウント分ずらす
                    node.inputRange = node.inputRange.startIndex - completedData.correspondingCount ..< node.inputRange.endIndex - completedData.correspondingCount
                }
            }
        }
        // (2)
        let result = LatticeNode.EOSNode

        for (i, nodeArray) in lattice.nodes.enumerated() {
            for node in nodeArray {
                if node.prevs.isEmpty {
                    continue
                }
                if self.dicdataStore.shouldBeRemoved(data: node.data) {
                    continue
                }
                // 生起確率を取得する。
                let wValue = node.data.value()
                if i == 0 {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue + self.dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                } else {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue}
                }
                // 変換した文字数
                let nextIndex = node.inputRange.endIndex
                // 文字数がcountと等しくない場合は先に進む
                if nextIndex != count {
                    self.updateNextNodes(with: node, nextNodes: lattice.nodes[nextIndex], nBest: N_best)
                } else {
                    // countと等しければ変換が完成したので終了する
                    for index in node.prevs.indices {
                        let newnode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                }
            }

        }
        return (result: result, lattice: lattice)
    }
}
