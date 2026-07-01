---
inclusion: always
---

# プロジェクトルール

## モジュール改変の原則（最重要・厳守）

- **MainWeb・SharedCore・AuthModule は変更不可**（修正・追記禁止。読み取り参照のみ可）。機能開発は担当モジュール（MaterialModule 等）内で完結させること。
  - `clnCoCore`（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）のソース・設定は変更しない。やむを得ず必要と判断した場合は**実施前に必ずユーザーへ確認**し、理由・影響範囲を提示すること。
- **MaterialModule 固有の設定・DI・リソースを MainWeb に置かない**:
  - 設定値は MaterialModule 側（`FaxDispatchOptions` 等の Options 既定値）で完結させる。MainWeb の `appsettings.json`/`appsettings.Development.json` に機能固有セクションを足さない。
  - DI 登録は `MaterialModule.Extensions.AddMaterialModule` 内で完結させる。
  - CSS/JS も MaterialModule 内で完結（`site.css` 等 MainWeb 資産は変更しない）。
- **唯一の例外**: プラットフォーム系モジュール（Auth/SharedInfrastructure/CommonModule 等）のホスト登録は MainWeb の `ModuleRegistration` が担う。ただしこれは**当該プラットフォームモジュール側の spec が所有**する変更であり、機能 spec（MaterialModule の各機能）から MainWeb に手を入れてはならない。
- やむを得ず MainWeb/AuthModule への変更が必要と判断した場合は、**実施前に必ずユーザーへ確認**し、理由・影響範囲を提示すること。
- 各セッションで MainWeb/AuthModule に差分が無いか確認し、機能 spec 由来の混入があれば撤去する。

## 作業は最小単位で進める（重要）

- タスク/ジョブは**最小の検証可能な単位**に分割し、**1単位ずつ**実施する（大きな一括変更をしない）。
- 1単位完了ごとに内容を提示し、ユーザー確認・ビルド/テスト確認の機会を挟んでから次へ進む。
- Spec の tasks も小さく分割し、1タスク＝1つの明確な成果物（1ファイル/1機能/1テーブル等）を原則とする。
- 大きな機能は複数 spec／複数フェーズに分け、依存関係を明示して順に進める。
- 影響範囲が広い変更（DB移行・カットオーバー・複数モジュール横断）は特に小刻みにし、各ステップで停止して確認する。

## 大きな作業の進め方（最小単位・記録・確実実行）

requirements / design / tasks や実装が大きくなる場合は、必ず**最小単位に分割して段階的に**進め、各段階を記録して確実に実行する。

- **spec分割**: 機能・ソリューション境界で独立した小さな spec に分ける（例: 共通基盤と各モジュール固有を別 spec にし、依存関係を明記）。1 spec を肥大化させない。
- **フェーズ分割**: requirements → design → tasks を一気に進めない。各フェーズ完了ごとにユーザー合意を取り、`session-memo` に記録してから次へ。
- **タスク最小化**: tasks は「1タスク＝単独で検証可能な小さな変更」に分解。原則1つずつ実行し、完了ごとに記録する。まとめて多数を一括実行しない。
- **記録の徹底**: 各段階・各タスクの完了時に `session-memo-YYYYMMDD.md` と spec（2箇所）を更新。中断しても次セッションで確実に再開できる状態を保つ。
- **依存・順序の明示**: カットオーバーや複数 spec/ソリューションをまたぐ変更は、切替順序・依存・ロールバック観点を design に明記してから着手する。
- **リスク逓減**: 影響が大きい変更（DB移行・基盤切替・別ソリューション改修）は、可逆な小ステップに区切り、各ステップでユーザー確認する。
- **コンテキスト逼迫時のハンドオフ**: 会話コンテキストが目安 80% に近づいたら、その時点で `session-memo-YYYYMMDD.md` に**チェックポイント**（現在地・次に行う1アクション・未完了項目・参照ファイル）を記録し、「再開します、session-memoを確認」で新セッションから続行できる状態にして区切る。長い作業でも取りこぼしなく再開できるようにする。

## セッション開始時の確認事項

1. 最新の `.kiro/session-memo/session-memo-YYYYMMDD.md` を読んで前回の状態を把握する
2. 本ルール（`project-rules.md`）の「Spec管理ルール」で spec 配置（単一正本）を確認する

## セッション終了時の必須作業

1. `.kiro/session-memo/session-memo-YYYYMMDD.md` を作成・更新する（本日の完了作業・未完了タスク・参照ファイル一覧）
2. 変更したページの Spec（単一正本）を更新する:
   - `.kiro/specs/{Module}/{feature-name}/requirements.md`
   - `.kiro/specs/{Module}/{feature-name}/design.md`
   - `.kiro/specs/{Module}/{feature-name}/tasks.md`
3. 全体Spec（`.kiro/specs/MaterialModule/material-module/`）にも該当する変更があれば反映する

## ドキュメント配置ルール（モジュール単位管理）

ドキュメントは**プロジェクトモジュール単位**で各リポジトリ内 `docs/` に置くことを基本とする。横断的な進捗ログ・共通参照はワークスペース共通領域に集約する。

- **進捗ログ（session-memo）**: `.kiro/session-memo/session-memo-YYYYMMDD.md`（ワークスペース共通・steering/specs と同じ `.kiro/` 配下）。
- **横断DB参照**: `.kiro/docs/db/`（`テーブル定義書.md`・`ER図.*`・`common-db-design.md` 等。複数DB/モジュールにまたがるため1本に集約）。
- **横断設計・方針**: `.kiro/docs/`（例: `concurrency-control-design.md`）。
- **各モジュール固有**: 当該モジュールの `docs/`（例: `MaterialModule/docs/`＝資材固有、`CommonModule/docs/`＝共通基盤、`PrintAgent/docs/`・`SmtpAgent/docs/`＝各エージェント）。
- **spec 正本（単一）**: `.kiro/specs/{Module}/{feature-name}/`（Kiro 参照・**単一正本**。モジュール名フォルダで入れ子管理し、モジュール別コピーは持たない）。

## Spec管理ルール

- Spec は **`.kiro/specs/{Module}/{feature-name}/` に単一正本**として配置する（モジュール名フォルダで入れ子管理）。
  - 資材機能 → `.kiro/specs/MaterialModule/{feature}/`
  - 共通基盤（print-platform / smtp-sender 等）→ `.kiro/specs/CommonModule/{feature}/`
- **モジュール別のコピー（`<module>/docs/specs/`）は持たない**（旧「2箇所配置」ルールは廃止。ドリフト防止・単一真実）。
- `.kiro` はワークスペース・メタリポジトリ（Nonaka ルート）で版管理する。

## ビルド・テスト

- ビルドはユーザー側で実施する（Kiroからは実行しない）
- コード変更後にビルド確認を促す必要はない

## 準拠する基準ドキュメント（必読）

- **基幹システム構築基準**: `\\OJIADM23120073\Labs\sdoc\基幹システム構築基準.md` — 設計・実装は本基準に準拠すること（毎回参照）
- DB命名規則: `\\OJIADM23120073\Labs\sdoc\命名規則(db).xlsx`
- DemoModule の構成・作法に倣う: `\\OJIADM23120073\Labs\web\asp\CoCore\DemoModule`

## コーディング規約

- ASP.NET Core Razor Pages パターン
- DbContext直接注入（サービス層は必要に応じて）
- 認可: `[Authorize(Policy = "DbPermissionCheck")]`
- DB: SQL Server（OJIADM23120073\DEVELOPMENT, db_material_dev）
- フロントエンド: Bootstrap 5 + vanilla JavaScript

## フォントサイズ統一ルール

新規ページ作成時は以下を必ず適用すること:
- ページ先頭に `<partial name="_MaterialStyles" />` を追加
- コンテナに `class="container-fluid mt-3 px-4 material-page" style="font-size: 0.8rem;"` を設定
- タイトルは `<h5 class="mb-2">@ViewData["Title"]</h5>` で統一
- テーブル（リスト）には `style="font-size: 0.75rem;"` を設定（コンテナの0.8remを上書き）
- StockLedgerのみ `0.7rem`（例外）
- MainWeb側のCSS（site.css）は変更しない — MaterialModule内で完結させる（→「モジュール改変の原則」参照）

## 用語統一

- `lead_time_days` = `default_delivery_days`（同値管理、画面表示は「納期(日)」）
- 安全在庫 = `safety_stock_qty`（現在の発注判定基準）
- 発注点 = `stock_minimum_qty`（将来自動計算で設定予定）

## DB スキーマ変更時の必須作業

エンティティ（マスタ・トランザクションテーブル）を追加・変更・削除した場合、以下を必ず実施すること:

1. `.kiro/docs/db/テーブル定義書.md` を更新する（列名・日本語名・型・備考の一覧）
2. `.kiro/docs/db/ER図.md` を更新する（テーブル間リレーション）

## 排他制御・同時接続対応

本プロジェクトは多人数からの同時接続・データ操作が想定されるため、以下を遵守すること:

- **マスタ更新**: 楽観的ロック（RowVersion）を使用。`[Timestamp]` 属性 + `DbUpdateConcurrencyException` キャッチ
- **トランザクション更新**: `BeginTransactionAsync` でデータ整合性を保証
- **新規エンティティ作成時**: 必ず `row_version` カラム（`[Timestamp]`）を含めること
- **AJAX保存時**: RowVersion をクライアントに返却し、次回保存時に送信して競合検出
- **競合検出時のメッセージ**: 「他のユーザーが先に更新しました。画面を再読み込みしてください。」
