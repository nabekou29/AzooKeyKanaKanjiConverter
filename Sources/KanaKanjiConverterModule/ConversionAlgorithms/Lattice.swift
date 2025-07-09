import Algorithms
import SwiftUtils

struct Lattice: Sequence {
    typealias Element = [LatticeNode]

    init() {
        self.inputIndexedNodes = []
        self.surfaceIndexedNodes = []
    }

    init(inputCount: Int, surfaceCount: Int, rawNodes: [[LatticeNode]]) {
        self.inputIndexedNodes = .init(repeating: [], count: inputCount)
        self.surfaceIndexedNodes = .init(repeating: [], count: surfaceCount)

        for nodes in rawNodes {
            guard let first = nodes.first else { continue }
            switch first.range.startIndex {
            case .surface(let i):
                self.surfaceIndexedNodes[i] = nodes
            case .input(let i):
                self.inputIndexedNodes[i] = nodes
            }
        }
    }

    private init(inputIndexedNodes: [[LatticeNode]], surfaceIndexedNodes: [[LatticeNode]]) {
        self.inputIndexedNodes = inputIndexedNodes
        self.surfaceIndexedNodes = surfaceIndexedNodes
    }

    private var inputIndexedNodes: [[LatticeNode]]
    private var surfaceIndexedNodes: [[LatticeNode]]

    func prefix(inputCount: Int, surfaceCount: Int) -> Lattice {
        let filterClosure: (LatticeNode) -> Bool = { (node: LatticeNode) -> Bool in
            switch node.range.endIndex {
            case .input(let value):
                value <= inputCount
            case .surface(let value):
                value <= surfaceCount
            }
        }
        let newInputIndexedNodes = Array(self.inputIndexedNodes.prefix(inputCount).map {(nodes: [LatticeNode]) in
            nodes.filter(filterClosure)
        }.drop(while: \.isEmpty))
        let newSurfaceIndexedNodes = Array(self.surfaceIndexedNodes.prefix(surfaceCount).map {(nodes: [LatticeNode]) in
            nodes.filter(filterClosure)
        }.drop(while: \.isEmpty))

        return Lattice(inputIndexedNodes: newInputIndexedNodes, surfaceIndexedNodes: newSurfaceIndexedNodes)
    }

    func suffix(inputCount: Int, surfaceCount: Int) -> Lattice {
        Lattice(
            inputIndexedNodes: self.inputIndexedNodes.suffix(inputCount),
            surfaceIndexedNodes: self.surfaceIndexedNodes.suffix(surfaceCount)
        )
    }

    mutating func merge(_ lattice: Lattice) {
        for (index, nodeArray) in lattice.inputIndexedNodes.enumerated() where index < self.inputIndexedNodes.endIndex {
            self.inputIndexedNodes[index].append(contentsOf: nodeArray)
        }
        if self.inputIndexedNodes.endIndex < lattice.inputIndexedNodes.endIndex {
            for nodeArray in lattice.inputIndexedNodes[self.inputIndexedNodes.endIndex...] {
                self.inputIndexedNodes.append(nodeArray)
            }
        }
        for (index, nodeArray) in lattice.surfaceIndexedNodes.enumerated() where index < self.surfaceIndexedNodes.endIndex {
            self.surfaceIndexedNodes[index].append(contentsOf: nodeArray)
        }
        if self.surfaceIndexedNodes.endIndex < lattice.surfaceIndexedNodes.endIndex {
            for nodeArray in lattice.surfaceIndexedNodes[self.surfaceIndexedNodes.endIndex...] {
                self.surfaceIndexedNodes.append(nodeArray)
            }
        }
    }

    subscript(inputIndex i: Int) -> [LatticeNode] {
        get {
            self.inputIndexedNodes[i]
        }
    }

    subscript(index index: LatticeIndex) -> [LatticeNode] {
        get {
            switch index {
            case .input(let i): self.inputIndexedNodes[i]
            case .surface(let i): self.surfaceIndexedNodes[i]
            }
        }
    }

    func indexedNodes() -> some Sequence<(index: LatticeIndex, nodes: [LatticeNode])> {
        self.inputIndexedNodes.enumerated().lazy.map { (.input($0.offset), $0.element) }
            .chained(self.surfaceIndexedNodes.enumerated().lazy.map { (.surface($0.offset), $0.element) })
    }

    func makeIterator() -> Chain2Sequence<[[LatticeNode]], [[LatticeNode]]>.Iterator {
        self.inputIndexedNodes.chained(self.surfaceIndexedNodes).makeIterator()
    }

    var isEmpty: Bool {
        self.inputIndexedNodes.isEmpty && self.surfaceIndexedNodes.isEmpty
    }

    enum LatticeIndex: Sendable, Equatable {
        case surface(Int)
        case input(Int)

        var isZero: Bool {
            self == .surface(0) || self == .input(0)
        }
    }

    enum LatticeRange: Sendable, Equatable {
        static var zero: Self {
            .input(from: 0, to: 0)
        }
        case surface(from: Int, to: Int)
        case input(from: Int, to: Int)

        var count: ComposingCount {
            switch self {
            case .surface(let from, let to):
                .surfaceCount(to - from)
            case .input(let from, let to):
                .inputCount(to - from)
            }
        }

        var startIndex: LatticeIndex {
            switch self {
            case .surface(let from, _):
                .surface(from)
            case .input(let from, _):
                .input(from)
            }
        }

        var endIndex: LatticeIndex {
            switch self {
            case .surface(_, let to):
                .surface(to)
            case .input(_, let to):
                .input(to)
            }
        }

        func merged(with other: Self) -> Self? {
            switch (self, other) {
            case (let .surface(l, ml), let .surface(mr, r)):
                if ml == mr {
                    .surface(from: l, to: r)
                } else {
                    nil
                }
            case (let .input(l, ml), let .input(mr, r)):
                if ml == mr {
                    .input(from: l, to: r)
                } else {
                    nil
                }
            case (.surface, .input), (.input, .surface):
                nil
            }
        }

        func offseted(inputOffset: Int, surfaceOffset: Int) -> Self {
            switch self {
            case .surface(from: let from, to: let to):
                .surface(from: from + surfaceOffset, to: to + surfaceOffset)
            case .input(from: let from, to: let to):
                .input(from: from + inputOffset, to: to + inputOffset)
            }
        }

    }
}
