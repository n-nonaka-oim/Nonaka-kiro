# Implementation Plan: dispatch-monitoring-consolidation

## Overview

本実装計画は design.md「実装の最小単位（tasks 分割の指針）」の9単位に従い、MaterialModule 内で発注承認まわりの「印刷ジョブ投入の共通キュー化（PDF生成→保存→`pdf_path`付与→`t_print_queue`投入）」「FAX一本化（`t_order_reports.fax_status` 非書込）」「旧監視画面（Material_SmtpMonitor / Material_PrintMonitor）の廃止・導線更新」を、最小の検証可能な単位で段階的に実装する。

各タスクは前タスクの成果物の上に積み上がる（entity/DDL → パス解決サービス → PrintJobService 改修 → 旧画面削除/導線 → テスト → カットオーバー協調）。実装言語は C#（.NET 8 / Razor Pages）。テスト基盤は `MaterialModule.Tests`（xUnit + FsCheck.Xunit）。

なお、既存タスク 3.2 で実装済みの `PrintJobService` 投入処理は、`print-platform` の投入契約改定（`IPrintQueueService.EnqueueAsync` から `outputType` 引数を削除・キューへ出力区分を持ち込まない）と投入側ゲート化（印刷キュー投入を `OutputType ∈ {1,3}` に限定・`0`/`2` は投入しない・`2` は FAX 経路が PDF 生成を担うため二重生成回避）に追随するため、新規タスク群 10 で是正する（既存タスク 3.2 の成果物は保持し、差分のみを 10 で補正）。

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

- [x] 5. 旧監視画面の廃止・参照コード撤去
  - [x] 5.1 `Material_SmtpMonitor` 削除 + FAX 参照コード撤去
    - `MaterialModule/Areas/Material/Pages/SmtpMonitor/Index.cshtml(.cs)` を削除（旧名残 `FaxMonitor/` があれば併せて整理）
    - 廃止に伴い不要になった `t_order_reports.fax_status`／`fax_at`／`fax_error_message` 参照コードを MaterialModule から除去
    - _Requirements: 3.1, 3.3, 2.1_

  - [x] 5.2 `Material_PrintMonitor` 削除 + 印刷監視参照コード撤去
    - `MaterialModule/Areas/Material/Pages/PrintMonitor/Index.cshtml(.cs)` を削除
    - 廃止に伴い不要になった `t_order_reports.print_status`／`PrintPayload`／`PrintAgentControls` 参照コードを MaterialModule から除去
    - _Requirements: 5.1, 5.3_

- [x] 6. 導線（ナビゲーション）解除 SQL
  - [x] 6.1 `dbAuthTest` の `m_content`/`r_content_auth` 解除 SQL を作成
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

- [x] 9. カットオーバー協調（③投入先切替）
  - [x] 9.1 カットオーバー協調ノートの反映（doc/spec-sync）
    - `print-platform` R11 の「③投入先切替」への追随として、残ジョブ（旧 `t_order_reports.print_status ∈ {1,2}`）分の `pdf_path` 生成手順（`IOrderPdfService`＋`IPrintOutputPathService` 資産で PDF 生成・保存）を design.md「カットオーバー協調」章に整合させ、切替順序（③投入側＝本 spec と ④読取先＝print-platform の近接実施）・可逆性（旧構成へ戻せる）を明記
    - 実行手順詳細・DDL・移行は `print-platform` 所有（ユーザー実施）。本タスクはドキュメント整合のみ（コード変更なし）
    - _Requirements: 4.7_

- [ ] 10. 新Print仕様追随（OutputType 投入側ゲート・EnqueueAsync outputType 除去・二重生成回避）
  - [x] 10.1 `PrintJobService.CreateOrderApprovalJobsAsync` を OutputType ゲートに是正
    - 印刷キュー投入を代表 `OutputType ∈ {1,3}` のグループに限定する（`OutputType = 0`・`2` は印刷キューへ投入しない）。既存実装（3.2）は全グループを投入していたため、投入側ゲート判定を追加して是正する
    - `IPrintQueueService.EnqueueAsync` 呼び出しから `outputType` 引数を削除し、`print-platform` の改定シグネチャ `EnqueueAsync(module, reportType, referenceCode, pdfPath, printerName, copies, ct)` に一致させる（キューへ出力区分を持ち込まない）
    - PDF 生成・保存は `OutputType ∈ {0,1,3}` のグループで行い、`OutputType = 2`（FAXのみ）は FAX 経路（`DispatchEnqueueService`）が生成・保存・投入を担うため PrintJobService は PDF 生成も印刷投入も行わない（二重生成回避）
    - `IPrintJobService` の公開シグネチャは維持（呼び出し元 `ApprovalService` を変更しない）
    - _Requirements: 4.2, 4.3, 8.2_

  - [x] 10.2 二重生成回避の整合確認（PrintJobService と DispatchEnqueueService の PDF 生成・保存責務分担）
    - `OutputType = 3`（両方）のグループで同一グループ PDF が二重生成・二重保存されないよう、両経路（`PrintJobService`／`DispatchEnqueueService`）の生成条件を突き合わせて整合させる（保存の一元化＝印刷経路が保存し FAX 経路は保存済み PDF を参照）
    - design「二重生成の回避（PDF生成責務の分担）」の不変条件（いかなるグループの PDF も二重生成されない）に一致させる
    - _Requirements: 8.2_

  - [ ]* 10.3 Property 2 プロパティテストを OutputType ゲートに追随更新
    - **Property 2: 印刷対象グループのみ契約準拠の投入が1回行われる（OutputType ゲート）**
    - **Validates: Requirements 4.2, 4.5, 8.1**
    - 代表 `OutputType ∈ {1,3}` のグループのみ `IPrintQueueService.EnqueueAsync` をちょうど1回・`{0,2}` は 0 回であることを検証。呼び出し引数に `outputType` を含まない（`module`/`reportType`/`referenceCode`/`pdfPath`/`copies` を検証）
    - タグ: `Feature: dispatch-monitoring-consolidation, Property 2`・最低 100 回反復
    - _Requirements: 4.2, 4.5, 8.1_

- [ ] 11. FAX送信の config_key 選定と承認画面テスト送信（R10）
  > **【改訂 2026/07/08：現行実装＝recipient 上書き方式】** 本タスク群の記述（config_key を `fax`/`test-fax` から選定・`TestConfigKey`・宛先を上書きしない）は取り下げ。**現行（実装 `ab31934`）は config_key 常に `fax`＋テスト時 recipient を `m_send_config.test_fax_number` に上書き・From=`m_send_config.from_address`（`ISendConfigService`）**。`FaxDispatchOptions.TestConfigKey` は廃止。11.1〜11.4 の `[x]` は履歴として維持（実装は本ノートが正）。テスト宛先/From の管理は spec `send-config-master` 所有。
  - [x] 11.1 `FaxDispatchOptions` を改修（config_key 選定・テスト設定廃止）
    - `MaterialModule/Configuration/FaxDispatchOptions.cs` から `TestSendEnabled`・`TestFaxNumber`・`ConfigKey`（`"Material"` 固定）を削除
    - `NormalConfigKey`（既定 `"fax"`）・`TestConfigKey`（既定 `"test-fax"`）を追加。`FromAddress` は継続保持
    - _Requirements: 10.1, 10.5_

  - [x] 11.2 `IDispatchEnqueueService`/`DispatchEnqueueService` に testSend を追加し config_key を選定
    - `EnqueueOrderApprovalFaxAsync` に `bool testSend` 引数を追加（`EnqueueOrderApprovalFaxAsync(List<TOrder> orders, bool testSend, CancellationToken ct = default)`）
    - config_key = `testSend ? _options.TestConfigKey : _options.NormalConfigKey` を `ISmtpQueueService.EnqueueAsync` の `configKey` へ渡す（従来の固定 `_options.ConfigKey` を廃止）
    - `ResolveRecipientForSend`（`TestSendEnabled` 時に `TestFaxNumber` へ上書き）を削除し、宛先は `ResolveFaxRecipient` の実FAX番号をそのまま渡す（test-fax は SmtpAgent が宛先を無視するため）
    - `t_order_dispatch_log.IsTestSend` に `testSend`、`ConfigKey` に選定値を記録
    - _Requirements: 10.1, 10.3, 10.4, 10.6_

  - [x] 11.3 `IApprovalService`/`ApprovalService` に faxTestSend を追加し受け渡し
    - `ApproveOrdersAsync`/`ApproveOrderAsync` に `bool faxTestSend = false` を追加し、`_dispatchEnqueueService.EnqueueOrderApprovalFaxAsync(orders, faxTestSend, ct)` へ渡す
    - 印刷投入（`PrintJobService`）はテスト送信の影響を受けない（既存呼び出しのまま）
    - _Requirements: 10.2, 10.3, 10.4_

  - [x] 11.4 承認画面（Approvals）に「FAXテスト送信」チェックボックスを追加
    - `MaterialModule/Areas/Material/Pages/Approvals/Index.cshtml(.cs)` の承認操作近傍にチェックボックスを配置（既定 OFF）。`_MaterialStyles`・`material-page` 規約準拠
    - 承認 POST ハンドラでチェック値をバインドし `ApprovalService` の承認メソッドへ `faxTestSend` として渡す。永続化・全体共有しない（当該 POST でのみ有効）
    - このフラグは Common_SmtpMonitor には設けない
    - _Requirements: 10.2, 10.5, 10.7_

  - [ ]* 11.5 Property 4 プロパティテスト（config_key 選定・宛先非上書き）
    > **【改訂 2026/07/08：Property 反転】** 現行は「configKey は常に `fax`、testSend 時は recipient=`m_send_config.test_fax_number` に**上書きあり**（未設定はスキップ）、From=`m_send_config.from_address`」を検証する（旧「test-fax/fax 選定・宛先上書きなし」は無効）。design「Property 4」改訂ノート参照。
    - **Property 4: FAX投入の config_key はテスト送信指定に一致し宛先は上書きされない**
    - **Validates: Requirements 10.1, 10.3, 10.4, 10.6**
    - `testSend`（true/false）＋FAX対象を含む発注集合を生成し、`ISmtpQueueService.EnqueueAsync` の `configKey` が `test-fax`/`fax` に一致・宛先が実FAX番号のまま（上書きなし）を検証。`ISmtpQueueService` はモック。タグ: `Feature: dispatch-monitoring-consolidation, Property 4`・最低 100 回反復
    - _Requirements: 10.1, 10.3, 10.4, 10.6_

  - [ ] 11.6 チェックポイント - FAX config_key 選定・承認画面テスト送信のビルド/テストを通す
    - ビルド／テスト実行はユーザー側。承認画面チェック→config_key 選定→投入の一連が整合していることを確認する。
    - ※ SmtpAgent 側の宛先解決3モード（`fax`/`test-fax` の実挙動）は別 spec `smtp-sender` タスク15 が担う。

## Notes

- `*` 付きサブタスク（テスト）は任意で、MVP を急ぐ場合はスキップ可能。ただし本 spec は Correctness Properties（Property 1〜3）の検証を推奨する。
- コア実装タスク（`*` なし）は必ず実装する。チェックポイント（タスク4・8）は非任意の検証ゲートで、ユーザーのビルド／テスト確認を挟む。
- 各タスクは design.md「実装の最小単位（9単位）」に1対1で対応する（1=タスク1、2=タスク6、3=タスク2、4=タスク3、5=タスク5.1、6=タスク5.2、7=タスク6、8=タスク7、9=タスク9）。
- Property テストは `MaterialModule.Tests`（xUnit + FsCheck.Xunit）で各100回以上反復。`IPrintQueueService` の投入時挙動（`print_status=1` 初期化・必須空白 `ArgumentException`）自体は `print-platform` が検証済みで、本 spec は「契約を満たす引数で必ず経由する」ことを検証する。
- DDL 適用・ビルド・テスト実行・実送信・実印刷・`m_content` SQL 実行はいずれもユーザー側で実施する。
- 本 spec 由来の変更は MainWeb・AuthModule・SharedCore・PrintAgent に差分を出さない（毎セッション確認）。
- タスク群 10 は、投入側 OutputType ゲート化（印刷キュー投入を `OutputType ∈ {1,3}` に限定）と `EnqueueAsync` からの `outputType` 引数除去への追随（新Print仕様）である。既存タスク 3.2 は投入契約改定前に実装・コミット済み（全グループ投入・`outputType` 受け渡し）であり、タスク群 10 がこれを是正する。既存の完了タスク（`[x]`）は変更しない。
- タスク群 11 は FAX送信の config_key 選定（本番 `fax`／テスト `test-fax`・旧 `Material` 廃止）と承認画面「FAXテスト送信」チェック（ジョブ単位・非共有・競合回避）への対応（R10）。`FaxDispatchOptions` の `TestSendEnabled`/`TestFaxNumber`/`ConfigKey` を廃止し、`DispatchEnqueueService`/`ApprovalService` に testSend/faxTestSend を通す。SmtpAgent の宛先解決3モードの実挙動は別 spec `smtp-sender` タスク15 が所有する。`IDispatchEnqueueService`/`IApprovalService` の内部シグネチャ変更を伴う（MaterialModule 内で完結）。
  - **【改訂 2026/07/08：現行実装に追随】** 上記「config_key を `fax`/`test-fax` から選定・`TestConfigKey`」は取り下げ。現行実装（`ab31934`）は **config_key 常に `fax`＋テスト時 recipient を `m_send_config.test_fax_number` に上書き・From=`m_send_config.from_address`（`ISendConfigService` 取得）**。テスト宛先値・From の管理は spec `send-config-master` が所有。`smtp-sender` の固定宛先(test-fax)モードには依存しない（2モード＝`fax`/`mail`）。

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
    { "id": 6, "tasks": ["9.1"] },
    { "id": 7, "tasks": ["10.1"] },
    { "id": 8, "tasks": ["10.2"] },
    { "id": 9, "tasks": ["10.3"] },
    { "id": 10, "tasks": ["11.1"] },
    { "id": 11, "tasks": ["11.2", "11.4"] },
    { "id": 12, "tasks": ["11.3"] },
    { "id": 13, "tasks": ["11.5", "11.6"] }
  ]
}
```
