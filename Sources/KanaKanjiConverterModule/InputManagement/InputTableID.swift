public import struct Foundation.URL

public enum InputTableID: Sendable, Equatable, Hashable {
    case defaultRomanToKana
    case defaultDesktopRomanToKana
    case defaultDesktopAZIK
    case defaultDesktopKanaJIS
    case defaultDesktopKanaUS
    case empty
    case custom(URL)
    case tableName(String)
}
