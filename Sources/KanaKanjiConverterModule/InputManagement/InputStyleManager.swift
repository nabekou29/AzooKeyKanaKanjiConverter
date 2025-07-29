import Foundation
import SwiftUtils

final class InputStyleManager {
    nonisolated(unsafe) static let shared = InputStyleManager()

    private var tables: [InputTableID: InputTable] = [:]

    private init() {
        // デフォルトのテーブルは最初から追加しておく
        let defaultRomanToKana = InputTable(pieceHiraganaChanges: Roman2KanaMaps.defaultRomanToKanaPieceMap)
        let defaultAZIK = InputTable(pieceHiraganaChanges: Roman2KanaMaps.defaultAzikPieceMap)
        self.tables = [
            .empty: .empty,
            .defaultRomanToKana: defaultRomanToKana,
            .defaultAZIK: defaultAZIK
        ]
    }

    func table(for id: InputTableID) -> InputTable {
        switch id {
        case .defaultRomanToKana, .defaultAZIK, .empty:
            return self.tables[id]!
        case .custom(let url):
            if let table = self.tables[id] {
                return table
            } else if let table = try? Self.loadTable(from: url) {
                self.tables[id] = table
                return table
            } else {
                return .empty
            }
        }
    }

    private static func loadTable(from url: URL) throws -> InputTable {
        let content = try String(contentsOf: url, encoding: .utf8)
        var map: [[InputTable.KeyElement]: [InputTable.ValueElement]] = [:]
        for line in content.components(separatedBy: .newlines) {
            // 空行は無視
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            // `# `で始まる行はコメントとして明示的に無視
            guard !line.hasPrefix("# ") else { continue }
            let cols = line.split(separator: "\t")
            // 要素の無い行は無視
            guard cols.count >= 2 else { continue }
            let key = cols[0].map(InputPiece.character).map(InputTable.KeyElement.piece)
            let value = cols[1].map(InputTable.ValueElement.character)
            map[key] = value
        }
        return InputTable(pieceHiraganaChanges: map)
    }
}
