//
//  LearningMemoryTests.swift
//  KanaKanjiConverterModuleTests
//
//  Created by Codex on 2025/05/25.
//

@testable import KanaKanjiConverterModule
import XCTest

final class LearningMemoryTests: XCTestCase {
    static let resourceURL = Bundle.module.resourceURL!.appendingPathComponent("DictionaryMock", isDirectory: true)

    func testPauseFileIsClearedOnInit() throws {
        let dir = ConvertRequestOptions.default.memoryDirectoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pauseURL = dir.appendingPathComponent(".pause", isDirectory: false)
        FileManager.default.createFile(atPath: pauseURL.path, contents: Data())
        XCTAssertTrue(LongTermLearningMemory.memoryCollapsed(directoryURL: dir))

        // `init`に副作用がある
        _ = LearningManager()
        // 学習の破壊状態が回復されていることを確認
        XCTAssertFalse(LongTermLearningMemory.memoryCollapsed(directoryURL: dir))
        try? FileManager.default.removeItem(at: pauseURL)
    }

    func testMemoryFilesCreateAndRemove() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LearningMemoryTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = LearningManager()
        var options = ConvertRequestOptions.default
        options.dictionaryResourceURL = Self.resourceURL
        options.memoryDirectoryURL = dir
        options.learningType = .inputAndOutput
        options.maxMemoryCount = 32
        _ = manager.setRequestOptions(options: options)

        let element = DicdataElement(word: "テスト", ruby: "テスト", cid: CIDData.一般名詞.cid, mid: MIDData.一般.mid, value: -10)
        manager.update(data: [element])
        manager.save()

        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.contains { $0.lastPathComponent == "memory.louds" })
        XCTAssertTrue(files.contains { $0.lastPathComponent == "memory.loudschars2" })
        XCTAssertTrue(files.contains { $0.lastPathComponent == "memory.memorymetadata" })
        XCTAssertTrue(files.contains { $0.lastPathComponent.hasSuffix(".loudstxt3") })

        manager.reset()
        let filesAfter = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        XCTAssertTrue(filesAfter.isEmpty)
    }
}

