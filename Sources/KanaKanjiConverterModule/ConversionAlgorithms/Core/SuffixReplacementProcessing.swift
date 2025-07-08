//
//  changed_last_n_character.swift
//  Keyboard
//
//  Created by ensan on 2020/10/14.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation
import SwiftUtils

extension Kana2Kanji {
    /// カナを漢字に変換する関数, 最後の一文字が変わった場合。
    /// ### 実装状況
    /// (0)多用する変数の宣言。
    ///
    /// (1)まず、変更前の一文字につながるノードを全て削除する。
    ///
    /// (2)次に、変更後の一文字につながるノードを全て列挙する。
    ///
    /// (3)(1)を解析して(2)にregisterしていく。
    ///
    /// (4)registerされた結果をresultノードに追加していく。
    ///
    /// (5)ノードをアップデートした上で返却する。

    func kana2lattice_changed(_ inputData: ComposingText, N_best: Int, counts: (deleted: Int, added: Int), previousResult: (inputData: ComposingText, lattice: Lattice), needTypoCorrection: Bool) -> (result: LatticeNode, lattice: Lattice) {
        // (0)
        let count = inputData.input.count
        let commonCount = previousResult.inputData.input.count - counts.deleted
        debug("kana2lattice_changed", inputData, counts, previousResult.inputData, count, commonCount)

        // (1)
        var lattice = previousResult.lattice.prefix(commonCount)

        let terminalNodes: Lattice
        if counts.added == 0 {
            terminalNodes = Lattice(nodes: lattice.nodes.map {
                $0.filter {
                    $0.inputRange.endIndex == count
                }
            })
        } else {
            // (2)
            let addedNodes: Lattice = Lattice(nodes: (0..<count).map {(i: Int) in
                self.dicdataStore.getLOUDSDataInRange(inputData: inputData, from: i, toIndexRange: max(commonCount, i) ..< count, needTypoCorrection: needTypoCorrection)
            })

            // (3)
            for nodeArray in lattice.nodes {
                for node in nodeArray {
                    if node.prevs.isEmpty {
                        continue
                    }
                    if self.dicdataStore.shouldBeRemoved(data: node.data) {
                        continue
                    }
                    // 変換した文字数
                    let nextIndex = node.inputRange.endIndex
                    self.updateNextNodes(with: node, nextNodes: addedNodes[inputIndex: nextIndex], nBest: N_best)
                }
            }
            lattice.merge(addedNodes)
            terminalNodes = addedNodes
        }

        // (3)
        // terminalNodesの各要素を結果ノードに接続する
        let result = LatticeNode.EOSNode

        for (i, nodes) in terminalNodes.nodes.enumerated() {
            for node in nodes {
                if node.prevs.isEmpty {
                    continue
                }
                // この関数はこの時点で呼び出して、後のnode.registered.isEmptyで最終的に弾くのが良い。
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
                let nextIndex = node.inputRange.endIndex
                if count == nextIndex {
                    self.updateResultNode(with: node, resultNode: result)
                } else {
                    self.updateNextNodes(with: node, nextNodes: terminalNodes[inputIndex: nextIndex], nBest: N_best)
                }
            }
        }
        return (result: result, lattice: lattice)
    }

}
