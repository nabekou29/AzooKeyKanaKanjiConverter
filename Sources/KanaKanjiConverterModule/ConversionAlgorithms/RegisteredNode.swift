import Foundation

/// `indirect enum`を用いて再帰的なノード構造を実現
indirect enum RegisteredNode {
    case node(data: DicdataElement, prev: RegisteredNode?, totalValue: PValue, range: Lattice.LatticeRange)

    /// このノードが保持する辞書データ
    var data: DicdataElement {
        _read {
            switch self {
            case .node(let data, _, _, _):
                yield data
            }
        }
    }

    /// 1つ前のノードのデータ
    var prev: RegisteredNode? {
        _read {
            switch self {
            case .node(_, let prev, _, _):
                yield prev
            }
        }
    }

    /// 始点からこのノードまでのコスト
    var totalValue: PValue {
        switch self {
        case .node(_, _, let totalValue, _):
            return totalValue
        }
    }

    /// `composingText`の`input`で対応する範囲
    var range: Lattice.LatticeRange {
        switch self {
        case .node(_, _, _, let range):
            return range
        }
    }

    init(data: DicdataElement, registered: RegisteredNode?, totalValue: PValue, range: Lattice.LatticeRange) {
        self = .node(data: data, prev: registered, totalValue: totalValue, range: range)
    }

    /// 始点ノードを生成する関数
    /// - Returns: 始点ノードのデータ
    static func BOSNode() -> RegisteredNode {
        RegisteredNode(data: DicdataElement.BOSData, registered: nil, totalValue: 0, range: .zero)
    }

    /// 入力中、確定した部分を考慮した始点ノードを生成する関数
    /// - Returns: 始点ノードのデータ
    static func fromLastCandidate(_ candidate: Candidate) -> RegisteredNode {
        RegisteredNode(
            data: DicdataElement(word: "", ruby: "", lcid: CIDData.BOS.cid, rcid: candidate.data.last?.rcid ?? CIDData.BOS.cid, mid: candidate.lastMid, value: 0),
            registered: nil,
            totalValue: 0,
            range: .zero
        )
    }
}

extension RegisteredNode {
    /// 再帰的にノードを遡り、`CandidateData`を構築する関数
    /// - Returns: 文節単位の区切り情報を持った変換候補データ
    func getCandidateData() -> CandidateData {
        guard let prev else {
            let unit = ClauseDataUnit()
            unit.mid = self.data.mid
            unit.ranges = [self.range]
            return CandidateData(clauses: [(clause: unit, value: .zero)], data: [])
        }
        var lastcandidate = prev.getCandidateData()    // 自分に至るregisterdそれぞれのデータに処理

        if self.data.word.isEmpty {
            return lastcandidate
        }

        guard let lastClause = lastcandidate.lastClause else {
            return lastcandidate
        }

        if lastClause.text.isEmpty || !DicdataStore.isClause(prev.data.rcid, self.data.lcid) {
            // 文節ではないので、最後に追加する。
            lastClause.text.append(self.data.word)
            lastClause.ranges.append(self.range)
            // 最初だった場合を想定している
            if (lastClause.mid == 500 && self.data.mid != 500) || DicdataStore.includeMMValueCalculation(self.data) {
                lastClause.mid = self.data.mid
            }
            lastcandidate.clauses[lastcandidate.clauses.count - 1].value = self.totalValue
            lastcandidate.data.append(self.data)
            return lastcandidate
        }
        // 文節の区切りだった場合
        else {
            let unit = ClauseDataUnit()
            unit.text = self.data.word
            unit.ranges.append(self.range)
            if DicdataStore.includeMMValueCalculation(self.data) {
                unit.mid = self.data.mid
            }
            // 前の文節の処理
            lastClause.nextLcid = self.data.lcid
            lastcandidate.clauses.append((clause: unit, value: self.totalValue))
            lastcandidate.data.append(self.data)
            return lastcandidate
        }
    }
}
