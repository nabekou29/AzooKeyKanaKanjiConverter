struct Lattice: Sequence {
    typealias Element = [LatticeNode]
    typealias Iterator = IndexingIterator<[[LatticeNode]]>

    init(nodes: [[LatticeNode]] = []) {
        self.nodes = nodes
    }

    private var nodes: [[LatticeNode]]

    func prefix(_ k: Int) -> Lattice {
        var lattice = Lattice(nodes: self.nodes.prefix(k).map {(nodes: [LatticeNode]) in
            nodes.filter {$0.inputRange.endIndex <= k}
        })
        while lattice.nodes.last?.isEmpty ?? false {
            lattice.nodes.removeLast()
        }
        return lattice
    }

    func suffix(_ count: Int) -> Lattice {
        Lattice(nodes: self.nodes.suffix(count))
    }

    mutating func merge(_ lattice: Lattice) {
        for (index, nodeArray) in lattice.nodes.enumerated() where index < self.nodes.endIndex {
            self.nodes[index].append(contentsOf: nodeArray)
        }
        if self.nodes.endIndex < lattice.nodes.endIndex {
            for nodeArray in lattice.nodes[self.nodes.endIndex...] {
                self.nodes.append(nodeArray)
            }
        }
    }

    subscript(inputIndex i: Int) -> [LatticeNode] {
        get {
            self.nodes[i]
        }
    }

    func makeIterator() -> IndexingIterator<[[LatticeNode]]> {
        self.nodes.makeIterator()
    }

    var isEmpty: Bool {
        self.nodes.isEmpty
    }
}
