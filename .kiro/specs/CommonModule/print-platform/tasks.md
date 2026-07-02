# Implementation Plan: print-platform（共通プリント基盤）

## Overview

design.md に基づき、共通プリント基盤を段階的に実装する。SMTP送信基盤（smtp-sender）と一対一で対応する構成であり、実装順は「DBスキーマ(DDL)＋ドキュメント → CommonModule 共通エンティティ・DbContext → 投入サービス `IPrintQueueService` → 共通監視画面 `Common_PrintMonitor` → PrintAgent（別ソリューション）読取先変更＋印刷専用化（pdf_path サイレント印刷） → カットオーバー（移行・切替）」とする。各段階で動作確認できる最小単位に分割する。

実装の中心は次の2つ。
- 既存 `CommonModule` プロジェクト（Area `Common`）: 共通エンティティ `TPrintQueue`／`MPrintAgentControl`、`CommonDbContext` への DbSet 追加、`IPrintQueueService`／`PrintQueueService`、共通監視画面 `Common_PrintMonitor`（`/Common/PrintMonitor`）。
- 既存 `PrintAgent`（`\\ojiadm23120073\Labs\WindowsService\PrintAgent`、別ソリューションの .NET Worker）の改修: `t_order_reports` 依存を `t_print_queue` へ置換、接続先を `db_common_dev` へ変更、`pdf_path` の生成済み PDF をサイレント印刷する印刷専用化（PDF 生成は行わない）、`row_version` 追加による楽観ロック実効化。

前提・運用ルール:
- DBスキーマの作成・実行はユーザー側で行う。タスクでは DDL SQL ファイル（`CommonModule/docs/sql/`）を作成するところまでを行い、実行はユーザーに依頼する。
- ビルド・テスト実行・実印刷はユーザー側で行う（タスク内でビルド・実行・実印刷はしない）。
- MainWeb・AuthModule のソース・設定は変更しない（参照のみ）。成果物は CommonModule 内で完結させる（R12.1・R12.2）。
- Correctness Property 1〜7 は CommonModule.Tests の PBT（FsCheck/CsCheck 等、最低100イテレーション）で実装し、各テストに `// Feature: print-platform, Property {n}` タグを付す。Property 9 は並行統合テスト（1〜2例）で実装する。
- エラー列の物理名は `error_message` に統一（requirements 追随更新済み）。`m_print_agent_control` は 1行運用・単一Writer のため `row_version` を付与しない（`m_smtp_agent_control` とのパリティ＝ルールの明示的例外）。
- Spec は `.kiro/specs/CommonModule/print-platform/` に単一正本として管理する（モジュール別コピーは持たない）。

## Tasks

- [ ] 1. DBスキーマDDLとドキュメントの整備（共通DB `db_common_dev`）
  - [x] 1.1 `t_print_queue`・`m_print_agent_control` の CREATE TABLE DDL を作成
    - `CommonModule/docs/sql/` に 2 テーブルの CREATE TABLE スクリプトを作成
    - `t_print_queue`: id(IDENTITY,PK)/module(NOT NULL)/report_type(NOT NULL)/reference_code(NOT NULL)/output_type(NOT NULL)/print_status(NOT NULL,既定1)/pdf_path(nvarchar(500),NOT NULL)/printer_name(nvarchar(200))/copies(NOT NULL,既定1)/picked_at/printed_at/error_message(nvarchar(500))/created_at(NOT NULL)/updated_at(NOT NULL)/row_version(rowversion)。fax_status 列も print_payload 列も持たせない
    - インデックス `IX_t_print_queue_status_created (print_status, created_at)`・`IX_t_print_queue_reference_code (reference_code)`・`IX_t_print_queue_module (module)` を含める
    - `m_print_agent_control`: id(IDENTITY,PK)/last_heartbeat_at/machine_name(nvarchar(100))/updated_at(NOT NULL)。row_version は持たせない
    - スクリプト冒頭に「実行はユーザーが `db_common_dev` に対して行う」旨をコメントで明記
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 3.1, 3.3, 6.1_

  - [x] 1.2 テーブル定義書・ER図を更新
    - `.kiro/docs/db/テーブル定義書.md` に `t_print_queue`・`m_print_agent_control` の列名・日本語名・型・備考を追記
    - `.kiro/docs/db/ER図.md` に 2 テーブルと `t_smtp_queue`／`m_smtp_agent_control` との対（共通DB配置）を追記
    - _Requirements: 1.1, 6.1_

- [x] 2. CommonModule 共通エンティティと DbContext
  - [x] 2.1 エンティティ `TPrintQueue` を実装
    - `CommonModule/Data/Entities/TPrintQueue.cs` を `TSmtpQueue` と同じ DataAnnotations 作法で実装（`[Table("t_print_queue")]`/`[Column]`/`[Key]`/`[DatabaseGenerated(Identity)]`/`[MaxLength]`）
    - design「Data Models」章の 16 列に一致（`module`・`pdf_path`・`printer_name` を含む）。`RowVersion` に `[Timestamp]`（`row_version`）
    - _Requirements: 1.2, 1.5, 1.6, 2.1_

  - [x] 2.2 エンティティ `MPrintAgentControl` を実装
    - `CommonModule/Data/Entities/MPrintAgentControl.cs` を `MSmtpAgentControl` と対の 1行運用で実装（`last_heartbeat_at`(UTC)・`machine_name`・`updated_at`）
    - `row_version` は付与しない（パリティ＝ルールの明示的例外）
    - _Requirements: 6.1, 6.2, 6.4_

  - [x] 2.3 `CommonDbContext` に DbSet を追加
    - `CommonModule/Data/CommonDbContext.cs` に `DbSet<TPrintQueue> PrintQueue` と `DbSet<MPrintAgentControl> PrintAgentControls` を追加
    - OnModelCreating は実装せずマッピングはエンティティ側 DataAnnotations に委ねる（既存作法どおり）
    - _Requirements: 1.1, 8.2, 8.3_

- [x] 3. 投入サービス `IPrintQueueService` とDI登録
  - [x] 3.1 `IPrintQueueService` / `PrintQueueService` を実装
    - `CommonModule/Services/` に `IPrintQueueService`（`EnqueueAsync`）と `internal` 実装 `PrintQueueService` を作成（`ISmtpQueueService`/`SmtpQueueService` と同作法）
    - `print_status=1` で 1 件 INSERT。`created_at == updated_at = DateTime.UtcNow`。`t_print_queue` のみ操作し `t_order_reports` にアクセスしない
    - 必須項目（`module`/`reportType`/`referenceCode`/`pdfPath`）が空白のみなら `ArgumentException`。`pdf_path` は必須（非空）で `printPayload` 引数は持たない。`copies` は 1 未満なら 1 に正規化
    - _Requirements: 1.5, 4.1, 4.2, 4.3, 4.4_

  - [ ]* 3.2 投入不変条件のプロパティテスト
    - **Property 1: 投入は t_print_queue に待機ジョブを1件追加し入力を保持する**
    - **Validates: Requirements 1.5, 4.1, 4.2, 4.3**
    - EF Core InMemory で `EnqueueAsync` を検証（1件追加・print_status=1・入力一致・copies正規化・created_at==updated_at・他テーブル不操作）。`// Feature: print-platform, Property 1` タグ、100イテレーション以上

  - [ ]* 3.3 投入拒否のプロパティテスト
    - **Property 2: 必須項目欠落（pdf_path 含む）の投入は拒否される**
    - **Validates: Requirements 4.2, 4.3**
    - 必須項目（module/reportType/referenceCode/pdfPath）のいずれかが空白のみの入力で `ArgumentException`・テーブル不変を検証。`// Feature: print-platform, Property 2` タグ、100イテレーション以上

  - [x] 3.4 `AddCommonModule` に DI 登録を追加
    - `CommonModule/Extensions/CommonModuleExtensions.cs`（`AddCommonModule`）に `services.AddScoped<IPrintQueueService, PrintQueueService>()` を追加（`ISmtpQueueService` と対・Scoped）
    - `CommonDbContext` 登録・接続文字列 "CommonDb" は既存のまま（MainWeb は変更しない）
    - _Requirements: 4.1, 12.1, 12.2_

- [x] 4. 共通監視画面 `Common_PrintMonitor`（`/Common/PrintMonitor`）
  - [x] 4.1 一覧・フィルタ・サマリの PageModel を実装
    - `CommonModule/Areas/Common/Pages/PrintMonitor/Index.cshtml.cs` に `[Authorize(Policy = "DbPermissionCheck")]` を付与し `CommonDbContext` を直接注入
    - 一覧: module/report_type/reference_code/print_status/copies/picked_at/printed_at/error_message/created_at/updated_at（pdf_path 有無アイコン）。`Id` 降順・ページング（既定30件、選択肢 10/20/30/50/100）
    - フィルタ: print_status・report_type・キーワード（reference_code 部分一致）・作成日付範囲（JST入力→UTC境界変換、SmtpMonitor と同方式）。サマリ: print_status 別件数（待機1/処理中2/完了3/エラー9）を全件ベースで集計
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 9.3_

  - [ ]* 4.2 フィルタのプロパティテスト
    - **Property 4: フィルタ結果は全条件を満たす**
    - **Validates: Requirements 9.2**
    - ジョブ集合＋任意フィルタ条件を生成し、結果の全行が各指定条件を満たし未指定条件は絞り込まないことを検証。`// Feature: print-platform, Property 4` タグ、100イテレーション以上

  - [ ]* 4.3 サマリのプロパティテスト
    - **Property 5: サマリ件数は母集合と整合する**
    - **Validates: Requirements 9.3**
    - ジョブ集合を生成し、各 status 件数が母集合の該当行数と一致し合計が status∈{1,2,3,9} 行数に一致することを検証。`// Feature: print-platform, Property 5` タグ、100イテレーション以上

  - [x] 4.4 死活判定を実装
    - `m_print_agent_control` の最終 heartbeat が 30 秒以内なら「ポーリング中」、超過（または null）なら「応答なし」。`HeartbeatAliveSeconds = 30`（SmtpMonitor と同値・同ロジック）。マシン名・最終応答時刻(JST)を表示
    - _Requirements: 9.6_

  - [ ]* 4.5 死活判定のプロパティテスト
    - **Property 6: 死活判定は heartbeat 閾値と同値**
    - **Validates: Requirements 9.6**
    - 経過時間（負・0〜数分・境界30秒ちょうど・null）を生成し、Alive 判定が `経過<=30秒` と同値・null は「応答なし」を検証。`// Feature: print-platform, Property 6` タグ、100イテレーション以上

  - [x] 4.6 再出力 `OnPostReprintAsync` を実装
    - 完了(3)・エラー(9) かつ `pdf_path` が非空のジョブのみ `print_status=1` に戻し、`picked_at`/`printed_at`/`error_message` をクリア、`updated_at=UtcNow`
    - 待機(1)・処理中(2)・対象外(0) は不正遷移として拒否し通知。`pdf_path` 無しは「印刷ソースが無いため再出力できない」旨を通知
    - `DbUpdateConcurrencyException` を捕捉し「他のユーザーが先に更新しました。画面を再読み込みしてください。」を通知
    - _Requirements: 2.2, 2.3, 9.4, 9.5_

  - [ ]* 4.7 再出力遷移のプロパティテスト
    - **Property 3: 再出力は完了・エラーかつ pdf_path 有りのみを待機へ戻し、それ以外は不変**
    - **Validates: Requirements 9.4, 9.5**
    - print_status∈{0,1,2,3,9}×pdf_path 有無を生成し、3/9 かつ pdf_path 有りのみ 1 へ遷移＋クリア、他は不変を検証。`// Feature: print-platform, Property 3` タグ、100イテレーション以上

  - [x] 4.8 監視画面ビュー `Index.cshtml` を実装
    - Area "Common" 共通スタイル（Bootstrap 5 + vanilla JS、site.css は変更しない）で一覧・フィルタ・サマリ・死活表示・再出力操作・error_message 表示を描画（`Common_SmtpMonitor` と一貫）
    - _Requirements: 9.1, 9.6, 9.7, 10.1_

- [ ] 5. チェックポイント - CommonModule のテストを通す
  - すべてのテスト（Property 1〜6）が通ることを確認し、不明点があればユーザーに確認する。

- [x] 6. PrintAgent（別ソリューション）のエンティティ・DbContext・接続先変更
  - [x] 6.1 Worker 側エンティティ `TPrintQueue` を実装（`TOrderReport` を置換）
    - `\\OJIADM23120073\Labs\WindowsService\PrintAgent\Models\` に `t_print_queue` へマップする `TPrintQueue` を新規実装（PrintAgent 名前空間）
    - `TOrderReport` からの差分: `module` 追加・`pdf_path` 追加・`fax_status` 削除・`row_version`（`[Timestamp]`）追加・完了日時を `printed_at` に一本化・`printer_name`/`error_message` 継続
    - CommonModule 側 `TPrintQueue` と同一テーブル・同一列にマップされるようスキーマを一致させる
    - _Requirements: 1.6, 2.1, 5.1, 7.1_

  - [x] 6.2 `PrintAgentDbContext` を改修
    - `DbSet<TOrderReport> OrderReports` を廃し `DbSet<TPrintQueue> PrintQueue`（`ToTable("t_print_queue")`）へ差し替え
    - `MPrintAgentControl`（`ToTable("m_print_agent_control")`）は継続（読取先 DB が db_common_dev に変わる）
    - _Requirements: 5.1, 5.2, 6.1_

  - [x] 6.3 接続文字列を `db_common_dev` へ変更
    - `PrintAgent/appsettings.json` の `ConnectionStrings:CloudDb` を `db_material_dev` から `db_common_dev` へ変更（heartbeat 先も db_common_dev）
    - _Requirements: 5.1, 5.2, 6.1_

- [ ] 7. PrintAgent Worker（印刷専用・状態遷移・row_version 実効化）
  - [x] 7.1 印刷専用（pdf_path サイレント印刷）と状態遷移を実装
    - `PrintJobWorker` の待機取得条件を「`print_status=1` かつ `pdf_path IS NOT NULL`」に更新
    - 印刷ソースは `pdf_path` の生成済み PDF のみ。`SilentPrintService`（SumatraPDF）で当該 PDF を直接サイレント印刷する（PDF 生成は行わない）。従来の `print_payload` からの生成分岐および `PdfGeneratorService`/`IPdfGeneratorService`・`Documents/` は PrintAgent から退役する（投入側＝MaterialModule へ移管・別 spec 所有）
    - 取得時 `1→2`・`picked_at` 設定、完了時 `print_status=3`・`printed_at=UtcNow`（旧 completed_at/print_at 二重設定を廃止）、失敗時 `print_status=9`・`error_message`（500字切詰。`pdf_path` 指定ファイル不存在を含む）。SumatraPDF によるサイレント印刷ロジック自体は不変
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 1.6_

  - [ ]* 7.3 状態遷移単調性のプロパティテスト
    - **Property 7: 印刷ステータス遷移の単調性**
    - **Validates: Requirements 1.4, 5.3, 5.4, 5.5**
    - print_status と操作列を生成し、Worker は `1→2`/`2→3`/`2→9`、再出力は `3→1`/`9→1` のみ許容、3/9→2 が起きず 0 は非対象を純粋規則として検証。`// Feature: print-platform, Property 7` タグ、100イテレーション以上（CommonModule.Tests）

  - [ ] 7.4 heartbeat 更新（読取先 db_common_dev）を確認・維持
    - ポーリング毎に `m_print_agent_control.last_heartbeat_at`(UTC)・`machine_name` を更新（db_common_dev）。更新失敗は警告ログのみで処理継続（ロジック不変）
    - _Requirements: 6.2, 6.3_

  - [ ]* 7.5 二重取得防止の並行統合テスト
    - **Property 9: row_version による二重取得防止**
    - **Validates: Requirements 2.1, 2.2**
    - 同一 `t_print_queue` 待機行を 2 コンテキストで取得・`print_status=2` 更新し、一方成功・他方 `DbUpdateConcurrencyException`（スキップ）を確認（INTEGRATION・1〜2例）
    - _Requirements: 2.1, 2.2_

- [ ] 8. チェックポイント - PrintAgent/統合のテストを通す
  - すべてのテスト（Property 7〜9）が通ることを確認し、不明点があればユーザーに確認する。実印刷・実デプロイはユーザー側。

- [x] 9. カットオーバー（移行・切替）とSpec同期
  - [x] 9.1 未処理印刷データの移行 SQL を作成
    - `CommonModule/docs/sql/` に `t_order_reports` の `print_status∈{1,2}` を `t_print_queue` へ移行する INSERT スクリプトを作成
    - 列対応: `module` 既定 `material`／`pdf_path` は必須（NOT NULL）＝残ジョブは送信側（MaterialModule）が生成した pdf_path を付与、用意できない残ジョブは移行対象外／運用判断で除外／`completed_at`/`print_at`→`printed_at`／`fax_status`・`print_payload` は移行しない（`t_print_queue` に該当列は無い）／`row_version` は新規採番。`print_status=2` の扱い（1へ戻す or 除外）はコメントで運用判断を明記
    - 取り残しゼロ照合（移行前未処理件数＝移行後追加件数）の確認クエリを併記。スクリプト冒頭に「実行はユーザーが `db_common_dev` に対して行う・`t_order_reports` は削除せず保全」旨を明記
    - _Requirements: 11.2, 11.4, 11.5, 3.2_

  - [x] 9.2 Spec の最終整合確認（単一正本）
    - `.kiro/specs/CommonModule/print-platform/` の requirements.md・design.md・tasks.md の整合を確認（モジュール別コピーは廃止済み・同期不要）
    - _Requirements: （プロジェクトルール: 単一正本）_

- [ ] 10. 最終チェックポイント - 全テストを通す
  - すべてのテスト（Property 1〜9）が通ることを確認し、不明点があればユーザーに確認する。カットオーバー（③投入先切替は dispatch-monitoring-consolidation 所有・④読取先切替はユーザーデプロイ）の実施順序を確認する。

- [x] 11. 設計改訂に伴う CommonModule 実装是正（印刷専用・pdf_path 必須・print_payload 廃止）
  - [x] 11.1 `TPrintQueue` から `print_payload` プロパティを削除
    - `CommonModule/Data/Entities/TPrintQueue.cs` から `print_payload`（`PrintPayload`）プロパティを削除し、列構成を design「Data Models」（print_payload 無し・pdf_path 必須）に一致させる
    - _Requirements: 1.2, 1.6_

  - [x] 11.2 `IPrintQueueService`/`PrintQueueService` を pdf_path 必須へ是正
    - `IPrintQueueService`/`PrintQueueService`（`CommonModule/Services/`）の `EnqueueAsync` から `printPayload` 引数を削除し、`pdfPath` を必須（非空・空なら `ArgumentException`）に変更（design「Components and Interfaces」の契約に一致）
    - _Requirements: 4.2, 4.3_

  - [x] 11.3 DDL から `print_payload` 列を削除し `pdf_path` を NOT NULL に
    - `CommonModule/docs/sql/create_t_print_queue.sql` から `print_payload` 列を削除し、`pdf_path` を NOT NULL に変更
    - _Requirements: 1.5, 1.6_

  - [x] 11.4 `Common_PrintMonitor` の再出力条件を pdf_path 基準へ是正
    - `Common_PrintMonitor` の `OnPostReprintAsync` の再出力可否判定から payload 参照を削除し、`pdf_path` が非空であることのみを条件とする（3/9 かつ pdf_path 有り）
    - _Requirements: 9.5_

  - [x] 11.5 テーブル定義書・ER図を print_payload 削除・pdf_path NOT NULL に追随
    - `.kiro/docs/db/テーブル定義書.md`・`.kiro/docs/db/ER図.md` の `t_print_queue` から `print_payload` を削除し、`pdf_path` を NOT NULL に更新
    - _Requirements: 1.1_

## Notes

- `*` 付きサブタスクは省略可能（テスト）で、MVP優先時はスキップできる。コア実装タスクには `*` を付けていない。
- Correctness Property 1〜7 は CommonModule.Tests の PBT（最低100イテレーション）、Property 9 は並行統合テストで実装する（design「Testing Strategy」準拠）。Property 7 は状態遷移の純粋規則として CommonModule.Tests に置く。
- DBスキーマの作成・実行、ビルド、テスト実行、実印刷、PrintAgent の再デプロイはユーザー側で実施する（タスク内で実行しない）。
- 投入先切替（PrintJobService → IPrintQueueService）と旧 Monitor 廃止は `dispatch-monitoring-consolidation` が所有する（本 spec はスキーマ契約・CommonModule 受け口・PrintAgent 読取先・Common_PrintMonitor・カットオーバー定義を所有）。
- MainWeb・AuthModule は変更しない。成果物は CommonModule 内で完結し、Spec は `.kiro/specs/CommonModule/` に単一正本で配置する。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "2.2"] },
    { "id": 2, "tasks": ["2.3"] },
    { "id": 3, "tasks": ["3.1", "4.1", "4.4"] },
    { "id": 4, "tasks": ["3.2", "3.3", "3.4", "4.2", "4.3", "4.5", "4.6"] },
    { "id": 5, "tasks": ["4.7", "4.8"] },
    { "id": 6, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5"] },
    { "id": 7, "tasks": ["6.1", "6.2", "6.3"] },
    { "id": 8, "tasks": ["7.1", "7.4"] },
    { "id": 9, "tasks": ["7.3", "7.5"] },
    { "id": 10, "tasks": ["9.1", "9.2"] }
  ]
}
```
