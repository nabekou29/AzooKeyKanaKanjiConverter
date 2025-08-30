import Foundation
import OrderedCollections

extension InputTables {
    static let defaultHankakuToZenkaku = InputTables.Helper.constructPieceMap([
        "!": "！",
        "\"": "”",
        "#": "＃",
        "$": "＄",
        "%": "％",
        "&": "＆",
        "'": "’",
        "(": "（",
        ")": "）",
        "=": "＝",
        "~": "〜",
        "|": "｜",
        "`": "｀",
        "{": "『",
        "+": "＋",
        "*": "＊",
        "}": "』",
        "<": "＜",
        ">": "＞",
        "?": "？",
        "_": "＿",
        "-": "ー",
        "^": "＾",
        "\\": "＼",
        "¥": "￥",
        "@": "＠",
        "[": "「",
        ";": "；",
        ":": "：",
        "]": "」",
        ",": "、",
        ".": "。",
        "/": "・"
    ])
}
