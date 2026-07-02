# Implementation Plan: dispatch-monitoring-consolidation

## Overview

本実装計画は design.md「実装の最小単位（tasks 分割の指針）」の9単位に従い、MaterialModule 内で発注承認まわりの「印刷ジョブ投入の共通キュー化（PDF生成→保存→`pdf_path`付与→`t_print_queue`投入）」「FAX一本化（`t_order_reports.fax_status` 非書込）」「旧監視画面（Material_SmtpMonitor / Material_PrintMonitor）の廃止・導線更新」を、最小の検証可能な単位で段階的に実装する。

各タスクは前タスクの成果物の上に積み上がる（entity/DDL → パス解決サービス → PrintJobService 改修 → 旧画面削除/導線 → テスト → カットオーバー協調）。実装言語は C#（.NET 8 / Razor Pages）。テスト基盤は `MaterialModule.Tests`（xUnit + FsCheck.Xunit）。

### 制約（全タスク共通・厳守）

- **MaterialModule 配下のみ変更**（＋既存 `CommonModule` の `ProjectReference` 利用）。MainWeb・AuthModule・SharedCore・SharedInfrastructure・PrintAgent のソース／設定は変更しない（_Requirements: 4.8, 7.1, 7.2_）。
- DI 変更は `MaterialModuleExtensions.AddMaterialModule` 内で完結させる。MainWeb `appsettings.json` に機能固有セクションを追加しない。
- 新規エンティティ `MPrintOutputPath` は `row_version`（`[Timestamp]`）を持つ（排他制御・同時接続対応）。
- 投入は必ず `IPrintQueueService.EnqueueAsync` 経由（`t_print_queue` 直接アクセス禁止）。`t_order_reports` へは生成しない。`print_payload` は用いない。
- `IPrintJobService` の公開シグネチャは維持（呼び出し元 `ApprovalService` を変更しない）。
- DDL 適用・ビルド・テスト実行・実送信・実印刷はユーザー側で実施。
- 成果物は `.kiro/specs/MaterialModule/dispatch-monitoring-consolidation/` に単一正本として配置（モジュール別コピーを持たない）（_Requirements: 7.3_）。
- パスのホスト名は小文字 `ojiadm23120073` を使用。

## Tasks

- [x] 1. 印刷出力パスマスタのデータ基盤（エンティティ・DDL・ドキュメント）
  - [x] 1.1 `MPrintOutputPath` エンティティ追加 + `MaterialDbContext` に `DbSet` 追加
    - `MaterialModule/Data/Entities/MPrintOutputPath.cs` を新規作成（`[Table("m_print_output_path")]`、`Id`/`BasePath`/`Description`/`IsActive`/`RowVersion`/`CreatedAt`/`UpdatedAt` を design.md「エンティティ `MPrintOutputPath`」の列対応どおりにマッピング）
    - `[Key]`＋`[DatabaseGenerated(DatabaseGeneratedOption.Identity)]`、`base_path` は `[Required]`＋`[MaxLength(500)]`、`row_version` は `[Timestamp]`（`byte[]`）
    - `MaterialDbContext` に `DbSet<MPrintOutputPath> PrintOutputPaths` を追加（1行の小改修）
    - _Requirements: 9.1, 9.5_

  - [x] 1.2 `m_print_output_path` DDL＋シード SQL を作成
    - `MaterialModule/docs/sql/` に DDL＋シード SQL を新規作成（対象 DB: db_material_dev）
    - 列: `id`(int IDENTITY PK)、`base_path`(nvarchar(500) NOT NULL)、`description`(nvarchar(200) NULL)、`is_active`(bit NOT NULL default 1)、`row_version`(rowversion)、`created_at`/`updated_at`(datetime2 NOT NULL)
    - シード: `base_path = '\\ojiadm23120073\app_share\PrintAgent'`, `is_active = 1`（`FaxDispatchOptions.PdfShareRoot` 既定値と一致）
    - 実適用はユーザー側（実行手順コメントを SQL 冒頭に付記）
    - _Requirements: 9.1, 9.3, 9.4_

  - [x] 1.3 DBドキュメントを更新
    - `.kiro/docs/db/テーブル定義書.md` に `m_print_output_path`（列名・日本語名・型・備考）を追記
    - `.kiro/docs/db/ER図.md` に `m_print_output_path` を追記（単独マスタ・他テーブルとの直接リレーションなし）
    - _Requirements: 9.1_

- [ ] 2. 印刷出力パス解決サービス（`IPrintOutputPathService`）
  - [x] 2.1 `IPrintOutputPathService`/`PrintOutputPathService` 実装 + DI 登録
    - `MaterialModule/Services/IPrintOutputPathService.cs`（public interface）＋ `PrintOutputPathService.cs`（internal 実装、DemoModule パターン）を作成
    - `GetBasePathAsync`: `MaterialDbContext` から `m_print_output_path` の有効行（`is_active = true`）を1件取得。実行時に毎回取得（キャッシュしない＝R9.2）。有効行なしは既定値 `\\ojiadm23120073\app_share\PrintAgent` へフォールバックし `LogWarning`
    - 純関数 `BuildFullPath(basePath, fileName)`（`internal static`、`Path.Combine`）を切り出す
    - `MaterialModuleExtensions.AddMaterialModule` に Scoped 登録を追加（`AddMaterialModule` 内で完結）
    - _Requirements: 9.1, 9.2_

  - [ ]* 2.2 `BuildFullPath` 例示テスト
    - `MaterialModule.Tests` に例示テスト（フルパスが `Path.Combine(basePath, fileName)` と一致・非空・`.pdf` 終端）
    - _Requirements: 9.1, 9.2_

- [x] 3. `PrintJobService` 改修（PDF生成→保存→pdf_path付与→`t_print_queue`投入）
  - [x] 3.1 純関数 `ExtractGroupKey`/`BuildPdfFileName` を切り出し
    - `PrintJobService` 内に `ExtractGroupKey`（発注番号の先頭3セグメント抽出、`DispatchEnqueueService` と同一規則）と `BuildPdfFileName`（`{reportType}_{referenceCode}_{yyyyMMddHHmmssfff}.pdf`）を `internal static` 純関数として実装／切り出し（テスト容易性確保）
    - _Requirements: 4.2, 8.3_

  - [x] 3.2 `CreateOrderApprovalJobsAsync` を投入先変更に改修
    - 依存注入に `IOrderPdfService`（再利用）・`IPrintQueueService`（CommonModule・新規）・`IPrintOutputPathService`（新規）・`ILogger` を追加
    - 手順: `OrderNo` 採番済みのみ対象 → グループ化 → グループ単位 try/catch → `GenerateGroupOrderPdfAsync(groupKey)` で PDF 生成（再利用）→ `GetBasePathAsync`＋`BuildFullPath` で保存先確定・`Directory.CreateDirectory`＋`File.WriteAllBytesAsync` → `EnqueueAsync("material","order_approval",groupKey,outputType,fullPath,printerName:null,copies:1)`
    - 禁止事項の遵守: `OrderReports.Add(...)` を行わない（R4.4）、`FaxStatus` を設定しない（R1.1）、`PrintPayload`(JSON) を組み立てない・投入しない（R4.5）
    - `IPrintJobService` の公開シグネチャは維持（戻り値の意味を「投入した `t_print_queue` ジョブ件数」に読み替え、XMLコメント刷新）
    - _Requirements: 1.1, 4.1, 4.2, 4.3, 4.4, 4.5, 8.1, 8.3_

- [ ] 4. チェックポイント - MaterialModule のビルド/テストを通す
  - Ensure all tests pass, ask the user if questions arise.
  - ビルド／テスト実行はユーザー側。ここまでで entity・パス解決サービス・PrintJobService 改修が整合していることを確認する。

- [ ] 5. 旧監視画面の廃止・参照コード撤去
  - [ ] 5.1 `Material_SmtpMonitor` 削除 + FAX 参照コード撤去
    - `MaterialModule/Areas/Material/Pages/SmtpMonitor/Index.cshtml(.cs)` を削除（旧名残 `FaxMonitor/` があれば併せて整理）
    - 廃止に伴い不要になった `t_order_reports.fax_status`／`fax_at`／`fax_error_message` 参照コードを MaterialModule から除去
    - _Requirements: 3.1, 3.3, 2.1_

  - [ ] 5.2 `Material_PrintMonitor` 削除 + 印刷監視参照コード撤去
    - `MaterialModule/Areas/Material/Pages/PrintMonitor/Index.cshtml(.cs)` を削除
    - 廃止に伴い不要になった `t_order_reports.print_status`／`PrintPayload`／`PrintAgentControls` 参照コードを MaterialModule から除去
    - _Requirements: 5.1, 5.3_

- [ ] 6. 導線（ナビゲーション）解除 SQL
  - [ ] 6.1 `dbAuthTest` の `m_content`/`r_content_auth` 解除 SQL を作成
    - `MaterialModule/docs/sql/` に `register_smtp_monitor_content.sql` と対の「解除 SQL」を新規作成（対象 DB: dbAuthTest）
    - `area='Material' AND page='SmtpMonitor/Index'` および `area='Material' AND page='PrintMonitor/Index'` の `m_content` 行と関連 `r_content_auth` を除去（FAX 監視→`/Common/SmtpMonitor`、印刷監視→`/Common/PrintMonitor` へ集約）
    - 実行はユーザー側（`/Common/*` の登録は CommonModule 側 spec 所有）。MainWeb・AuthModule ソースは変更しない
    - _Requirements: 3.2, 5.2_

- [ ] 7. テスト（`MaterialModule.Tests`, xUnit + FsCheck.Xunit, 各プロパティ≥100 反復）
  - [ ]* 7.1 Property 1 プロパティテスト（`t_order_reports` 非変更・FAX非書込）
    - **Property 1: 投入経路は t_order_reports を一切変更しない（FAX非書込・印刷レコード非生成）**
    - **Validates: Requirements 1.1, 4.4**
    - `IPrintQueueService` をスパイ、`IOrderPdfService`／`IPrintOutputPathService` をフェイク、`MaterialDbContext` は InMemory（DB名を `Guid.NewGuid()` で一意化・`IDisposable` 破棄）。副作用が PDF生成・保存と `EnqueueAsync` に限られ、`t_order_reports` 行の追加・更新が発生しないことを検証
    - タグ: `Feature: dispatch-monitoring-consolidation, Property 1`

  - [ ]* 7.2 Property 2 プロパティテスト（採番済みグループごとに契約準拠の投入1回）
    - **Property 2: 採番済み発注グループごとに契約準拠の投入が1回行われる**
    - **Validates: Requirements 4.1, 4.5, 8.1**
    - 採番済み（非空 `OrderNo`）のみ対象・グループ1つにつき `EnqueueAsync` ちょうど1回・引数が契約準拠（`module=="material"`, `reportType=="order_approval"`, `referenceCode==ExtractGroupKey` かつ非空, `pdfPath` 非空, `copies>=1`）、未採番は投入を発生させないことを検証
    - タグ: `Feature: dispatch-monitoring-consolidation, Property 2`

  - [ ]* 7.3 Property 3 プロパティテスト（pdf_path 解決・非空・参照コード埋め込み）
    - **Property 3: pdf_path はマスタ由来ベースパスと参照コード埋め込みファイル名から解決され非空である**
    - **Validates: Requirements 4.2, 8.3, 9.1, 9.2**
    - 任意の非空 `base_path`・任意グループ・生成時刻に対し `pdfPath == BuildFullPath(base_path, fileName)` かつ非空、`fileName` が参照コードを含み `.pdf` 終端、マスタ値変更に追随することを検証
    - タグ: `Feature: dispatch-monitoring-consolidation, Property 3`

  - [ ]* 7.4 例示テスト（純関数・境界・シード値・PDF生成）
    - `ExtractGroupKey`（枝番／セグメント3未満）、`BuildPdfFileName` 形式、シード `base_path` 値＝`\\ojiadm23120073\app_share\PrintAgent`（R9.3）、`GenerateGroupOrderPdfAsync` が非空 byte[] を返す例（R8.1）
    - _Requirements: 8.1, 8.2, 9.3_

  - [ ]* 7.5 統合テスト（実ファイル保存＋投入・楽観ロック競合）
    - 実ファイル保存＋実 `t_print_queue` 投入を1〜3例（実 DB／ローカル共有）、`m_print_output_path` 更新時の `DbUpdateConcurrencyException` を1例
    - _Requirements: 4.1, 4.2, 9.2_

- [ ] 8. チェックポイント - MaterialModule のテストを通す
  - Ensure all tests pass, ask the user if questions arise.
  - 旧画面削除・参照撤去後もビルドが通り、Property 1〜3 と例示／統合テストが成立していることを確認する。

- [ ] 9. カットオーバー協調（③投入先切替）
  - [ ] 9.1 カットオーバー協調ノートの反映（doc/spec-sync）
    - `print-platform` R11 の「③投入先切替」への追随として、残ジョブ（旧 `t_order_reports.print_status ∈ {1,2}`）分の `pdf_path` 生成手順（`IOrderPdfService`＋`IPrintOutputPathService` 資産で PDF 生成・保存）を design.md「カットオーバー協調」章に整合させ、切替順序（③投入側＝本 spec と ④読取先＝print-platform の近接実施）・可逆性（旧構成へ戻せる）を明記
    - 実行手順詳細・DDL・移行は `print-platform` 所有（ユーザー実施）。本タスクはドキュメント整合のみ（コード変更なし）
    - _Requirements: 4.7_

## Notes

- `*` 付きサブタスク（テスト）は任意で、MVP を急ぐ場合はスキップ可能。ただし本 spec は Correctness Properties（Property 1〜3）の検証を推奨する。
- コア実装タスク（`*` なし）は必ず実装する。チェックポイント（タスク4・8）は非任意の検証ゲートで、ユーザーのビルド／テスト確認を挟む。
- 各タスクは design.md「実装の最小単位（9単位）」に1対1で対応する（1=タスク1、2=タスク6、3=タスク2、4=タスク3、5=タスク5.1、6=タスク5.2、7=タスク6、8=タスク7、9=タスク9）。
- Property テストは `MaterialModule.Tests`（xUnit + FsCheck.Xunit）で各100回以上反復。`IPrintQueueService` の投入時挙動（`print_status=1` 初期化・必須空白 `ArgumentException`）自体は `print-platform` が検証済みで、本 spec は「契約を満たす引数で必ず経由する」ことを検証する。
- DDL 適用・ビルド・テスト実行・実送信・実印刷・`m_content` SQL 実行はいずれもユーザー側で実施する。
- 本 spec 由来の変更は MainWeb・AuthModule・SharedCore・PrintAgent に差分を出さない（毎セッション確認）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1"] },
    { "id": 3, "tasks": ["3.2"] },
    { "id": 4, "tasks": ["5.1", "5.2", "6.1"] },
    { "id": 5, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5"] },
    { "id": 6, "tasks": ["9.1"] }
  ]
}
```
