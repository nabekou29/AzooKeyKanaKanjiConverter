import Foundation
import SwiftUtils

final class InputStyleManager {
    nonisolated(unsafe) static let shared = InputStyleManager()

    struct Table {
        init(pieceHiraganaChanges: [[InputPiece]: [Character]]) {
            self.hiraganaChanges = pieceHiraganaChanges
            self.unstableSuffixes = pieceHiraganaChanges.keys.flatMapSet { pieces in
                pieces.indices.map { i in
                    pieces[...i].compactMap { piece in
                        if case let .character(c) = piece { c } else { nil }
                    }
                }
            }
            let katakanaChanges: [String: String] = Dictionary(uniqueKeysWithValues: pieceHiraganaChanges.compactMap { key, value -> (String, String)? in
                let chars = key.compactMap { piece -> Character? in
                    if case let .character(c) = piece { c } else { nil }
                }
                guard chars.count == key.count else { return nil }
                return (String(chars), String(value).toKatakana())
            })
            self.maxKeyCount = pieceHiraganaChanges.keys.map { $0.count }.max() ?? 0
            self.possibleNexts = {
                var results: [String: [String]] = [:]
                for (key, value) in katakanaChanges {
                    for prefixCount in 0 ..< key.count where 0 < prefixCount {
                        let prefix = String(key.prefix(prefixCount))
                        results[prefix, default: []].append(value)
                    }
                }
                return results
            }()
        }

        let unstableSuffixes: Set<[Character]>
        let hiraganaChanges: [[InputPiece]: [Character]]
        let maxKeyCount: Int
        let possibleNexts: [String: [String]]

        static let empty = Table(pieceHiraganaChanges: [:])

        func toHiragana(currentText: [Character], added: InputPiece) -> [Character] {
            let limit = max(0, min(self.maxKeyCount - 1, currentText.count))
            for n in (0 ... limit).reversed() {
                var key = Array(currentText.suffix(n).map { InputPiece.character($0) })
                key.append(added)
                if let kana = self.hiraganaChanges[key] {
                    return Array(currentText.dropLast(n)) + kana
                }
            }
            switch added {
            case .character(let ch):
                return currentText + [ch]
            case .endOfText:
                return currentText
            }
        }
    }

    private var tables: [InputTableID: Table] = [:]

    private init() {
        // デフォルトのテーブルは最初から追加しておく
        let defaultRomanToKana = Table(pieceHiraganaChanges: Roman2KanaMaps.defaultRomanToKanaPieceMap)
        let defaultAZIK = Table(pieceHiraganaChanges: Roman2KanaMaps.defaultAzikPieceMap)
        self.tables = [
            .empty: .empty,
            .defaultRomanToKana: defaultRomanToKana,
            .defaultAZIK: defaultAZIK
        ]
    }

    func table(for id: InputTableID) -> Table {
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

    private static func loadTable(from url: URL) throws -> Table {
        let content = try String(contentsOf: url, encoding: .utf8)
        var map: [[InputPiece]: [Character]] = [:]
        for line in content.components(separatedBy: .newlines) {
            // 空行は無視
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            // `# `で始まる行はコメントとして明示的に無視
            guard !line.hasPrefix("# ") else { continue }
            let cols = line.split(separator: "\t")
            // 要素の無い行は無視
            guard cols.count >= 2 else { continue }
            let key = String(cols[0]).map(InputPiece.character)
            let value = Array(String(cols[1]))
            map[key] = value
        }
        return Table(pieceHiraganaChanges: map)
    }
}
