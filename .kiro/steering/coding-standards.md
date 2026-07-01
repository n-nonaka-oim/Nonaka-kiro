# 開発標準規約

別プロジェクトを含むソリューション全体で適用される共通規約。

> 優先順位: 本書は CoCore/Auth ソリューション基準の一般規約。各モジュール固有規約（`project-rules.md`・`material-module.md` 等）が競合する場合は**モジュール固有規約が優先**する（例: MaterialModule は監査列 `created_by`/`updated_by` を持たず `row_version`＋`created_at`/`updated_at` を用いる、フロントは Bootstrap5＋vanilla JS 等）。

## アーキテクチャ原則

- モジュラモノリス構成を厳守。モジュール間の直接参照は禁止し、インターフェース経由で通信
- 依存方向: SharedCore（ドメイン層）は他プロジェクトを参照しない。モジュールはSharedCoreのみ参照し、SharedInfrastructureを直接参照しない
- DI登録は各プロジェクトの`DependencyInjection.cs`に`Add{ModuleName}()`拡張メソッドとして定義し、MainWebのProgram.csから呼び出す
- リポジトリパターン: データアクセスはSharedInfrastructure/Repositories/に実装。読み取り専用クエリには`AsNoTracking()`を使用

## SDDフロー（Spec Driven Development）

IMPORTANT: AIにいきなりコードを生成させない。必ず以下の順序で進めること:
1. requirements.md で日本語の要件を定義し、人間の承認を得る
2. design.md で設計を定義し、既存システムとの境界を明確にする
3. tasks.md で実装手順を分解してからコーディングを開始

複雑なビジネスロジックの場合、まずUnit Testを書き、テストをクリアするコードを実装する（テスト駆動）。

## C# 実装ルール

- Primary Constructorを使用（サービス、リポジトリ、ミドルウェア、ハンドラー）
- I/Oを伴う処理はすべて`async/await`。デッドロック注意、必要に応じて`ConfigureAwait`使用
- `var`は右辺から型が明らかな場合のみ。明示的な型指定でも可
- 引数のnullチェックは`ArgumentNullException.ThrowIfNull()`
- 適切に処理できる例外のみキャッチ。一般的な例外をキャッチしない。catch内でログ出力後に`throw;`で再スロー
- LINQでコレクション操作。unsigned型ではなくintを使用
- 文字列連結は文字列補間、ループ内はStringBuilder
- 静的フィールドの先頭は`s_`、ThreadStaticは`t_`

## 画面デザイン
- Bootstrap@5.3.3を優先して使用
- 定義済みのクラスを優先し、その他の色を使用する場合は定義済みCSS変数(wwwroot/css/variables.css)を使用

## DB・モデル規約

- DBカラムは`[Column("snake_case", TypeName = "型")]`で明示的にマッピング
- 監査列は全テーブル共通: `created_at`(default: DateTime.UtcNow), `created_by`(default: "system"), `updated_at`, `updated_by`
- 中間テーブルには接頭辞`r_`を付与（例: `r_UserRole`）
- 必須の外部キーには`required`修飾子。ナビゲーションプロパティはnullable

## ログ規約

- XMLドキュメントコメント・ログメッセージは日本語で記述
- 構造化ログの`{Placeholder}`を使用
- ログレベル: 正常系=Information、想定外だが継続可能=Warning、例外=Error

## テスト規約

- xUnit + Moq + FsCheck 2.16.6（`Prop.ForAll`は最大3つの`Arbitrary`パラメータ）
- テストクラス名: `{対象クラス名}Tests`、プロパティベースは`{対象クラス名}PropertyTests`
- テストメソッド名: `{メソッド名}_{条件}_{期待結果}`（英語）
- Moq: 単純なモックは`Mock.Of<T>()`、振る舞い定義が必要な場合は`new Mock<T>()`
- InMemoryDB使用時: `Guid.NewGuid().ToString()`でDB名を一意にし、`IDisposable`で破棄
- Arrange/Act/Assertパターン、コメントで各セクションを明示

## ミドルウェア規約

- Primary Constructorで`RequestDelegate next`とロガーを受け取る
- スコープ付きサービスは`InvokeAsync`のパラメータで受け取る（コンストラクタではない）
- 早期リターンパターン: 条件を満たさない場合は`await next(context)`で次へ委譲
- PathBaseを考慮したリダイレクト: `context.Request.PathBase.Value`を使用

## AI統制

- 古いコードを参照してコード生成する場合、「新システムではこうあるべき」というTo-Beを常にプロンプト最上部に置く
- コード内の命名は「意図が明確で、かつ発音しやすいもの」を選択
