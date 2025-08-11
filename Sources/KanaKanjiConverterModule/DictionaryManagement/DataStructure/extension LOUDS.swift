//
//  extension Data.swift
//  Keyboard
//
//  Created by ensan on 2020/09/30.
//  Copyright © 2020 ensan. All rights reserved.
//

package import Foundation
import SwiftUtils

extension LOUDS {
    // MARK: - Unaligned-safe little-endian readers
    @inline(__always)
    private static func byte(_ data: borrowing Data, _ offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }

    @inline(__always)
    private static func readUInt16LE(_ data: borrowing Data, _ offset: Int) -> UInt16 {
        let b0 = UInt16(byte(data, offset))
        let b1 = UInt16(byte(data, offset + 1))
        return b0 | (b1 << 8)
    }

    @inline(__always)
    private static func readUInt32LE(_ data: borrowing Data, _ offset: Int) -> UInt32 {
        let b0 = UInt32(byte(data, offset))
        let b1 = UInt32(byte(data, offset + 1))
        let b2 = UInt32(byte(data, offset + 2))
        let b3 = UInt32(byte(data, offset + 3))
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    @inline(__always)
    private static func readFloat32LE(_ data: borrowing Data, _ offset: Int) -> Float32 {
        Float32(bitPattern: readUInt32LE(data, offset))
    }
    private static func loadLOUDSBinary(from url: URL) -> [UInt64]? {
        do {
            let binaryData = try Data(contentsOf: url, options: [.uncached]) // 2度読み込むことはないのでキャッシュ不要
            let ui64array = binaryData.toArray(of: UInt64.self)
            return ui64array
        } catch {
            debug(error)
            return nil
        }
    }

    private static func getLOUDSURL(_ identifier: String, option: ConvertRequestOptions) -> (chars: URL, louds: URL) {

        if identifier == "user" {
            return (
                option.sharedContainerURL.appendingPathComponent("user.loudschars2", isDirectory: false),
                option.sharedContainerURL.appendingPathComponent("user.louds", isDirectory: false)
            )
        }
        if identifier == "memory" {
            return (
                option.memoryDirectoryURL.appendingPathComponent("memory.loudschars2", isDirectory: false),
                option.memoryDirectoryURL.appendingPathComponent("memory.louds", isDirectory: false)
            )
        }
        return (
            option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).loudschars2", isDirectory: false),
            option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).louds", isDirectory: false)
        )
    }

    private static func getLoudstxt3URL(_ identifier: String, option: ConvertRequestOptions) -> URL {
        if identifier.hasPrefix("user") {
            return option.sharedContainerURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
        }
        if identifier.hasPrefix("memory") {
            return option.memoryDirectoryURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
        }
        return option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).loudstxt3", isDirectory: false)
    }

    /// LOUDSをファイルから読み込む関数
    /// - Parameter identifier: ファイル名
    /// - Returns: 存在すればLOUDSデータを返し、存在しなければ`nil`を返す。
    package static func load(_ identifier: String, option: ConvertRequestOptions) -> LOUDS? {
        let (charsURL, loudsURL) = getLOUDSURL(identifier, option: option)
        let nodeIndex2ID: [UInt8]
        do {
            nodeIndex2ID = try Array(Data(contentsOf: charsURL, options: [.uncached]))   // 2度読み込むことはないのでキャッシュ不要
        } catch {
            debug("Error: \(identifier)に対するLOUDSファイルが存在しません。このエラーは無視できる可能性があります。 Description: \(error)")
            return nil
        }

        if let bytes = LOUDS.loadLOUDSBinary(from: loudsURL) {
            let louds = LOUDS(bytes: bytes.map {$0.littleEndian}, nodeIndex2ID: nodeIndex2ID)
            return louds
        }
        return nil
    }

    @inlinable
    static func parseBinary(binary: Data) -> [DicdataElement] {
        // Fast parse without intermediate toArray allocations
        let count = Int(readUInt16LE(binary, 0))
        var offset = 2
        var dicdata: [DicdataElement] = []
        dicdata.reserveCapacity(count)
        if count > 0 {
            // Each entry: 2B*3 (UInt16) + 4B (Float32) = 10B
            for _ in 0 ..< count {
                let lcid = Int(readUInt16LE(binary, offset + 0))
                let rcid = Int(readUInt16LE(binary, offset + 2))
                let mid = Int(readUInt16LE(binary, offset + 4))
                let value = PValue(readFloat32LE(binary, offset + 6))
                dicdata.append(DicdataElement(word: "", ruby: "", lcid: lcid, rcid: rcid, mid: mid, value: value))
                offset += 10
            }
        }

        let strStart = binary.index(binary.startIndex, offsetBy: offset)
        let substrings = binary[strStart...].split(separator: UInt8(ascii: "\t"), omittingEmptySubsequences: false)
        guard let ruby = String(data: substrings.first ?? Data(), encoding: .utf8) else {
            debug("getDataForLoudstxt3: failed to parse", dicdata)
            return []
        }
        var i = dicdata.startIndex
        // Skip the first (ruby) field
        for substring in substrings.dropFirst() {
            if i == dicdata.endIndex { break }
            guard let word = String(data: substring, encoding: .utf8) else {
                debug("getDataForLoudstxt3: failed to parse", ruby)
                i = dicdata.index(after: i)
                continue
            }
            withMutableValue(&dicdata[i]) {
                $0.ruby = ruby
                $0.word = word.isEmpty ? ruby : word
            }
            i = dicdata.index(after: i)
        }
        return dicdata
    }

    static func getDataForLoudstxt3(_ identifier: String, indices: [Int], cache: Data? = nil, option: ConvertRequestOptions) -> [DicdataElement] {
        let binary: Data

        if let cache {
            binary = cache
        } else {
            do {
                let url = getLoudstxt3URL(identifier, option: option)
                binary = try Data(contentsOf: url)
            } catch {
                debug("getDataForLoudstxt3: \(error)")
                return []
            }
        }

        let lc: Int = Int(readUInt16LE(binary, 0))
        // Header table of UInt32 offsets starts at byte 2
        var out: [DicdataElement] = []
        out.reserveCapacity(indices.count * 2) // rough guess
        for idx in indices {
            let start = Int(readUInt32LE(binary, 2 + idx * 4))
            let end: Int = if idx == (lc - 1) {
                binary.endIndex
            } else {
                Int(readUInt32LE(binary, 2 + (idx + 1) * 4))
            }
            out.append(contentsOf: parseBinary(binary: binary[start ..< end]))
        }
        return out
    }

    /// indexとの対応を維持したバージョン
    static func getDataForLoudstxt3(_ identifier: String, indices: [(trueIndex: Int, keyIndex: Int)], cache: Data? = nil, option: ConvertRequestOptions) -> [(loudsNodeIndex: Int, dicdata: [DicdataElement])] {
        let binary: Data

        if let cache {
            binary = cache
        } else {
            do {
                let url = getLoudstxt3URL(identifier, option: option)
                binary = try Data(contentsOf: url)
            } catch {
                debug("getDataForLoudstxt3: \(error)")
                return []
            }
        }

        let lc: Int = Int(readUInt16LE(binary, 0))
        var result: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = []
        result.reserveCapacity(indices.count)
        for (trueIndex, keyIndex) in indices {
            let start = Int(readUInt32LE(binary, 2 + keyIndex * 4))
            let end: Int = if keyIndex == (lc - 1) {
                binary.endIndex
            } else {
                Int(readUInt32LE(binary, 2 + (keyIndex + 1) * 4))
            }
            result.append((trueIndex, parseBinary(binary: binary[start ..< end])))
        }
        return result
    }
}
