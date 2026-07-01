# Suggest Input Specification
ASP.NET Core Razor Pages環境において、テキスト入力項目に対する「マスタデータ参照型のサジェスト（インクリメンタルサーチ）機能」を実装してください。
# 前提技術
- バックエンド: .NET 8以降, C#, ASP.NET Core Razor Pages, Entity Framework Core
- フロントエンド: Vanilla JavaScript（外部ライブラリ非依存の標準Fetch APIを使用）
- アーキテクチャ: モジュラモノリス構成（画面とDIが分離されたクリーンな設計）を意識すること

# 実装要件
## 1. バックエンド（PageModel側）
- 「名前付きハンドラー（Named Handler）」（例: `OnGetSearchSuggestAsync`）を作成し、非同期で検索結果を返すAPIとして機能させること。
- 引数として `keyword` (string) を受け取ること。
- Entity Framework Core を使用し、対象マスタに対して `.Contains()` で部分一致検索を行うこと。
- 【重要】サーバー負荷対策のため、検索結果には必ず `.Take(20)` などを付与し、上限件数を制限すること。
- 戻り値は `JsonResult` を使用してJSON形式で返却すること。

## 2. フロントエンド（Razor View & JavaScript側）
- テキストボックスに対するキーボード入力イベントを検知すること。
- 【重要】Debounce処理を実装し、300ms停止したタイミングで1回だけFetchリクエストを送信すること。
- 入力欄が空の場合は、リクエストを送信せず、サジェスト結果をクリアすること。
- 取得したJSONデータを元に、テキストボックスの下に動的にリスト（ul/li）を生成・表示すること。
