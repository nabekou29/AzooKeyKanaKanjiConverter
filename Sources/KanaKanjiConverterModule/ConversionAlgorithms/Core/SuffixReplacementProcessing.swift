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
        var lattice = Lattice(nodes: previousResult.lattice.nodes.prefix(commonCount).map {(nodes: [LatticeNode]) in
            nodes.filter {$0.inputRange.endIndex <= commonCount}
        })
        while lattice.nodes.last?.isEmpty ?? false {
            lattice.nodes.removeLast()
        }

        let terminalNodes: Nodes
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
                    for nextnode in addedNodes.nodes[nextIndex] {
                        if self.dicdataStore.shouldBeRemoved(data: nextnode.data) {
                            continue
                        }
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
                            let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                            // カウントがオーバーしている場合は除去する
                            if nextnode.prevs.count >= N_best {
                                nextnode.prevs.removeLast()
                            }
                            // removeしてからinsertした方が速い (insertはO(N)なので)
                            nextnode.prevs.insert(newnode, at: lastindex)
                        }
                    }
                }

            }
            for (index, nodeArray) in addedNodes.nodes.enumerated() where index < lattice.nodes.endIndex {
                lattice.nodes[index].append(contentsOf: nodeArray)
            }
            for nodeArray in addedNodes.nodes.suffix(counts.added) {
                lattice.nodes.append(nodeArray)
            }
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
                    // 最後に至るので
                    for index in node.prevs.indices {
                        let newnode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                } else {
                    for nextnode in terminalNodes.nodes[nextIndex] {
                        // この関数はこの時点で呼び出して、後のnode.registered.isEmptyで最終的に弾くのが良い。
                        if self.dicdataStore.shouldBeRemoved(data: nextnode.data) {
                            continue
                        }
                        // クラスの連続確率を計算する。
                        let ccValue = self.dicdataStore.getCCValue(node.data.rcid, nextnode.data.lcid)
                        // nodeの持っている全てのprevnodeに対して
                        for (index, value) in node.values.enumerated() {
                            let newValue = ccValue + value
                            // 追加すべきindexを取得する
                            let lastindex: Int = (nextnode.prevs.lastIndex(where: {$0.totalValue >= newValue}) ?? -1) + 1
                            if lastindex == N_best {
                                continue
                            }
                            let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                            // カウントがオーバーしている場合は除去する
                            if nextnode.prevs.count >= N_best {
                                nextnode.prevs.removeLast()
                            }
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
