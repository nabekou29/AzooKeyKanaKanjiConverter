# 学習データについて

AzooKeyKanaKanjiConverter では、ユーザが変換候補を選択した結果を学習して、次回以降の変換候補の並び替えに利用します。学習結果は `memoryDirectoryURL` で指定したディレクトリに保存されます。

## 保存されるファイル

学習データは内部的に辞書形式のファイルとして保持されます。主なファイルは以下の通りです。

- `memory.louds`
- `memory.loudschars2`
- `memory.loudstxt3`

更新時には一時的に `.2` の拡張子が付いたファイルを作成し、安全に置き換える仕組みになっています。更新処理の詳細は [conversion_algorithms.md](./conversion_algorithms.md) を参照してください。

## ディレクトリの指定

`ConvertRequestOptions` の `memoryDirectoryURL` に書き込み可能なディレクトリを指定してください。通常はアプリの書類フォルダなどを指定します。英語用と日本語用など、キーボードのターゲットごとに学習データを分けたい場合は、言語ごとに別のディレクトリを指定してください。

```swift
let documents = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
let options = ConvertRequestOptions.withDefaultDictionary(
    requireJapanesePrediction: true,
    requireEnglishPrediction: true,
    keyboardLanguage: .ja_JP,
    learningType: .inputAndOutput,
    memoryDirectoryURL: documents,
    sharedContainerURL: documents
)
```

## 学習データのリセット

変換候補の長押しから個別に学習をリセットできます。ディレクトリを削除することで全ての学習内容を消去することも可能です。

プログラムから一括で学習データを初期化したい場合は、`shouldResetMemory` オプションを
`true` にして `ConvertRequestOptions` を生成します。初期化後1回だけ
`LearningMemory` が自動的にファイルを削除します。

```swift
let options = ConvertRequestOptions.withDefaultDictionary(
    requireJapanesePrediction: true,
    requireEnglishPrediction: true,
    keyboardLanguage: .ja_JP,
    learningType: .inputAndOutput,
    shouldResetMemory: true,
    memoryDirectoryURL: documents,
    sharedContainerURL: documents
)
```

ファイルの完全削除のみを実行したい場合は
`LongTermLearningMemory.reset(directoryURL:)` を直接呼び出してください。
