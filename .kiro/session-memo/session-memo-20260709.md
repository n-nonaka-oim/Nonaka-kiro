# セッション備忘録（2026/07/09）

前日（20260708）＝送信設定マスタ send-config-master 実装・spec 整合・メール/FAX 疎通OK まで完了。本日は残コミット＋新規追加案件（監視画面 削除機能／SendConfig ユーザー別＋添付）に着手。

## 本日の完了

### 1. 前回クローズ分のコミット（再開点確定）
- CommonModule `35fb376`（register_send_config_content ラベル「SMTP送信設定」整合）。
- Nonaka/.kiro `5571c40`（未実装案件一覧 I-4＋session-memo 20260708）。
- 3リポジトリ クリーン。

### 2. 任意PBT（回答のみ・未着手）
- send-config-master 3.3/4.4/6.2・dispatch 7.1〜7.5/10.3/11.5・print-platform 12.14〜12.16。全スキップ可。dispatch 11.5 は recipient 上書き方式に反転済み（実装時は新仕様）。

### 3. 未使用テーブル DROP（J-1・ユーザー実行待ち）
- スクリプト準備済 `MaterialModule/docs/sql/drop_legacy_orphan_tables_db_material_dev.sql`（db_material_dev 旧 m_smtp_config/m_smtp_agent_control/m_print_agent_control・t_order_reports 保全）。🔴破壊的・要バックアップ。未実行。

## 追加案件（ユーザー提示・SDD で実施）

### 追加1: 共通監視画面の一括削除機能【spec＋実装 完了・未コミット】
- 新規 spec `.kiro/specs/CommonModule/monitor-job-delete/`（requirements/design/tasks・診断クリア）。
- 仕様確定：対象＝Common_SmtpMonitor・Common_PrintMonitor 両画面／**チェックボックス複数選択＋一括削除**（Material/Dispatches 踏襲）／削除可＝**処理中(2)以外**（待機1・完了3・エラー9）／**物理削除**／**確認ダイアログ**あり／処理中や消失行はクエリ条件で自動除外し削除件数を通知。
- 実装（CommonModule・直接編集）：
  - `SmtpMonitor/Index.cshtml.cs`：`[BindProperty] List<int> SelectedJobIds`＋`OnPostDeleteAsync`（`SmtpQueue.Where(Contains(Id) && Status!=2).RemoveRange`）。
  - `PrintMonitor/Index.cshtml.cs`：同（`PrintQueue`・`PrintStatus!=2`）。
  - 両 `Index.cshtml`：空の削除フォーム（`smtpDeleteForm`/`printDeleteForm`）＋行チェックボックス（HTML5 `form` 属性で紐付け＝既存の再送/再出力フォームとの入れ子回避）＋ヘッダ「選択削除」ボタン＋全選択＋`confirm`。処理中(2)行はチェックボックス非表示。
- tasks 1/2＝[x]。任意PBT 4.1/4.2 は未実装。
- ⚠ diagnostics ツールが本ターン後半で一時利用不可。**ユーザー側ビルド確認要**（実装は既存パターン踏襲）。

### 追加2: SendConfig ユーザー別＋添付【未着手・次アクション】
確定要件（ユーザー回答）：
- (d) ユーザー識別キー＝ログインユーザーID（SharedCore `IUserRepository` 由来）。
- (e) default レコード＝ユーザー行が無いときの**初期表示値**（コピー元）。
- (f) 添付＝SendConfig に**固定パス1つ**保持・空なら添付なし・default は空。読込不可エラー判定＝**送信時**。
- ⇒ `m_send_config` を **ユーザー別**へスキーマ変更（`owner_user_id` 列追加＋ユーザー単位ユニーク・NULL=default 行）＋添付パス列追加。send-config-master spec の改訂＋DDL 変更＋PageModel/単発テスト送信の改修。影響大のため小刻みに。

## 次アクション（優先順）
1. 追加1 のユーザービルド確認 → OKなら追加1 をコミット（CommonModule 4ファイル）＋ Nonaka/.kiro（新spec monitor-job-delete）。
2. 追加2 の spec 改訂（send-config-master：ユーザー別＋添付）→ DDL（m_send_config ALTER）→ 実装。
3. 任意PBT・J-1 DROP（ユーザー）。

## コミット状況（本日）
- CommonModule `35fb376`。Nonaka `5571c40`。
- **未コミット**：CommonModule（SmtpMonitor/PrintMonitor 削除機能 4ファイル）・Nonaka/.kiro（新spec monitor-job-delete 3ファイル・本memo）。

## 運用メモ（継続）
- spec ワークフロー用サブエージェント起動は IDE クラッシュ（`i.map is not a function`）を誘発するため**使わない**。spec は直接編集（fs_write/str_replace）で作成・改訂。
- ビルド・テスト・DDL適用・実送信・実印刷はユーザー側。MainWeb/AuthModule/SharedCore 不変更。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。次アクション＝追加1 ビルド確認→コミット、または追加2 spec 改訂着手。

---

## 追加2: SendConfig ユーザー別＋添付 — spec 改訂＋実装 完了（未コミット）

### 方針（ユーザー確定）
- 送信設定を**ログインユーザー別**に保存/読込。`m_send_config` に `owner_user_id`（NULL=default 行）追加。ユーザー行が無ければ default を初期表示。保存でユーザー行を作成。
- **投入側（業務送信）は常に default 行を採用**（GetActiveAsync が default 限定）。default を変えれば業務送信に反映。
- 添付：`attachment_path`（固定1パス・空=添付なし・default 空）。**送信時**に File.Exists 判定→不可なら投入せずエラー。

### spec 改訂（send-config-master・単一正本・直接編集）
- requirements：Introduction/Glossary に改訂注記＋**R9（ユーザー別・default フォールバック）／R10（添付・送信時判定）** 追記。
- design：追加設計セクション（ALTER 2列・ISendConfigService.GetForUserAsync＋GetActiveAsync を default 限定・PageModel ユーザー別・単発テスト添付・Property 2）。
- tasks：task群8（8.1〜8.7）＋依存グラフ更新。8.1〜8.5＝[x]、8.6*（Property2/添付例示・任意）・8.7 CP（ユーザー）＝残。

### 実装（CommonModule・直接編集）
- `docs/sql/alter_m_send_config_user_attachment.sql` 新規（owner_user_id NVARCHAR(128)・attachment_path NVARCHAR(500) を冪等 ALTER）。
- `MSendConfig`：`OwnerUserId`・`AttachmentPath` 追加。
- `ISendConfigService`/`SendConfigService`：`GetActiveAsync` を **default 限定（owner_user_id==null）** に変更（投入側＝業務送信は default 採用・互換）＋`GetForUserAsync(userId)`（ユーザー行→default フォールバック）追加。
- `SendConfig/Index.cshtml.cs`：ユーザー別 表示/保存（owner_user_id=NameIdentifier クレーム。SharedCore 依存を増やさず Claims 利用）・default 初期表示・row_version 楽観ロック維持。単発テスト送信を `GetForUserAsync`＋添付（ResolveAttachment＝File.Exists・不可はエラー・pdfPath 付与）に改修。InputModel に AttachmentPath 追加。
- `SendConfig/Index.cshtml`：添付ファイルパス入力欄追加・説明文をユーザー別＋添付に更新。
- `.kiro/docs/db/テーブル定義書.md`・`ER図.md`：m_send_config に owner_user_id・attachment_path 追記。

### 🔴 実行時前提（重要・ユーザー）
- **`alter_m_send_config_user_attachment.sql`（db_common_dev）を適用してからビルド実行**すること。未適用だと EF が `owner_user_id`/`attachment_path` 列を参照して**実行時エラー**（SendConfig 画面・GetActiveAsync 経由の投入側 DispatchEnqueue も影響）。output_type と同種の前提。
- 既存 default 行は ALTER 後 owner_user_id=NULL のまま＝default として機能。

### 次アクション
1. ユーザー：ALTER 適用 → slnCoCore ビルド → `/Common/SendConfig`（ユーザー別保存・添付・単発テスト送信）動作確認。OKなら追加2 をコミット（CommonModule 実装＋Nonaka/.kiro spec/docs/memo）。
2. 任意：8.6 PBT（Property2/添付例示）。J-1 DROP。

### コミット状況（本日）
- コミット済：`35fb376`/`5571c40`（前回クローズ分）・`f77a0b9`/`0a57ba9`（追加1 monitor-job-delete）。
- 未コミット：CommonModule（send-config-master ユーザー別＋添付：MSendConfig/ISendConfigService/SendConfigService/SendConfig画面2/ALTER SQL）・Nonaka/.kiro（send-config-master spec 3・docs/db 2・本memo）。

---

## 🔴 中間チェックポイント（2026/07/09・すぐ再開）

### 本日ここまで完了・全コミット済み
- 前回クローズ分：CommonModule `35fb376`／Nonaka `5571c40`。
- **追加1（監視画面 一括削除）**：spec＋実装＋ビルドOK。CommonModule `f77a0b9`／Nonaka `0a57ba9`。
- **追加2（SendConfig ユーザー別＋添付）**：spec 改訂＋実装＋ビルドOK。CommonModule `0373178`／Nonaka `b684de7`。
  - ⚠ 実行時前提：`alter_m_send_config_user_attachment.sql`（db_common_dev）適用済み前提（owner_user_id/attachment_path）。未適用だと EF 実行時エラー。
- 未コミット：`.kiro/steering/Agnet.md`（無関係な steering・PrintAgent/SmtpAgent 起動コマンドのメモ）＝ユーザー判断で別途。

### 現在の稼働仕様（要点）
- 送信設定＝ユーザー別（owner_user_id）。**業務送信（発注承認FAX）は default 行（owner_user_id NULL）を採用**（GetActiveAsync が default 限定）。SendConfig 画面はログインユーザー行→無ければ default 初期表示・保存で自分用行作成。
- 単発テスト送信＝GetForUserAsync（ユーザー行→default）＋添付（attachment_path・送信時 File.Exists 判定・不可はエラー）。
- 監視画面（Common_Smtp/PrintMonitor）＝チェックボックス複数選択で一括削除（処理中2以外・物理削除・確認ダイアログ）。

### 次アクション候補（未着手・任意）
1. 任意PBT：monitor-job-delete 4.1/4.2（削除対象選別 Property1・例示）／send-config-master 8.6（Property2 ユーザー設定解決・添付例示）。
2. 動作確認（ユーザー）：/Common/SendConfig ユーザー別保存・添付（存在/不存在）・監視画面一括削除。
3. J-1：孤立3テーブル DROP（`drop_legacy_orphan_tables_db_material_dev.sql`・db_material_dev・破壊的・要バックアップ）。
4. 次機能（未実装案件一覧 G/F 等）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## A. 直近3機能の残（任意PBT）着手：CommonModule.Tests に3本追加

配置は `clnCoCore/CommonModule.Tests`（FsCheck 2.16.6・InMemory・一意DB名・`[Property(MaxTest=100)]`・`// Feature:` タグ）。既存 `SmtpMonitorResendPropertyTests`／`SmtpMonitorTestHelper`（TempData/PageContext スタブ）作法に踏襲。

- **monitor-job-delete Property 1**（削除対象選別＝選択かつ処理中2以外のみ削除・非選択/処理中は残存）:
  - `Pages/SmtpMonitor/SmtpMonitorDeletePropertyTests.cs`（`SmtpMonitorTestHelper.CreateModel` 再利用・`SelectedJobIds` 設定→`OnPostDeleteAsync`→残存集合 SetEquals 検証）。
  - `Pages/PrintMonitor/PrintMonitorDeletePropertyTests.cs`（PrintMonitor 用に TempData 簡易セットアップ内包）。
  - tasks 4.1＝[x]。4.2（未選択→エラー例示）は未（任意）。
- **send-config-master Property 1/2**：`Services/SendConfigServicePropertyTests.cs`
  - Property 1：`GetActiveAsync` は default 行（owner_user_id NULL・is_active=1）の最小 id または null（default 限定）。tasks 3.3＝[x]。
  - Property 2：`GetForUserAsync("u1")` はユーザー行→無ければ default→無ければ null。tasks 8.6＝[x]（添付の PageModel 例示は未／任意）。
  - `SendConfigService` は internal だが CommonModule.Tests に InternalsVisibleTo 済（既存 PrintQueueService テストと同様）で直接 new 可。

### ⏳ ユーザー
- `dotnet test CommonModule.Tests`（clnCoCore）でグリーン確認。OKなら本テスト3本をコミット（clnCoCore）。
- ※テスト .cs は clnCoCore 配下（git 管理はユーザー側の運用に従う）。

### A 残（未着手・任意）
- monitor-job-delete 4.2（未選択→エラー例示）。
- send-config-master 4.4（画面例示）・6.2（単発送信例示）・添付 PageModel 例示。
- dispatch-monitoring-consolidation 2.2/7.1〜7.5/10.3/11.5（MaterialModule.Tests・別プロジェクト）。
- print-platform 12.14/12.15/12.16（CommonModule.Tests）。
- 各 CP はユーザーの `dotnet test`。

### 未コミット
- clnCoCore/CommonModule.Tests：SmtpMonitorDeletePropertyTests・PrintMonitorDeletePropertyTests・SendConfigServicePropertyTests（3本）。
- Nonaka/.kiro：monitor-job-delete/send-config-master tasks 進捗・本memo。

---

## dotnet test CommonModule.Tests 実行（Kiro・ユーザー明示指示）＝グリーン

- 初回：**既存テストが output_type 廃止に未追随でコンパイル失敗**（8エラー）。`TPrintQueue.OutputType` 参照＋旧 `EnqueueAsync`（outputType 位置引数）残存。これは print-platform 12.15 の未処理分。
- 修正（clnCoCore/CommonModule.Tests）：
  - `Services/PrintQueueServicePropertyTests.cs`：EnqueueInput/InvalidEnqueueInput から OutputType 除去、Generator 追随、`EnqueueAsync` を新シグネチャ（module/reportType/referenceCode/pdfPath/printerName/copies）に、OutputType 検証ブロック除去。
  - `Pages/PrintMonitor/PrintMonitorSummary/Filter/Reprint`・`Integration/PrintQueueConcurrency` の `TPrintQueue { OutputType = 1 }` を除去。
- 再実行：**合計21・成功20・スキップ1（Integration＝SQL Server 前提）・失敗0**。今回追加3クラス（SmtpMonitorDelete/PrintMonitorDelete/SendConfigService）含め全緑。
- print-platform tasks 12.15＝[x]（既存テスト追随＋是正）。

### 未コミット（clnCoCore/CommonModule.Tests）
- 新規：SmtpMonitorDeletePropertyTests・PrintMonitorDeletePropertyTests・SendConfigServicePropertyTests。
- 是正：PrintQueueServicePropertyTests・PrintMonitor(Summary/Filter/Reprint)・Integration(PrintQueueConcurrency)。
- ＋ Nonaka/.kiro（monitor-job-delete/send-config-master/print-platform tasks 進捗・本memo）。

### 次アクション
- clnCoCore のテスト変更をコミット（ユーザー承認後）。
- A 残：dispatch(MaterialModule.Tests) 7.x/10.3/11.5・print-platform 12.14/12.16・send-config 4.4/6.2 例示。

---

## 🔴 本日のクローズ・チェックポイント（2026/07/09 終了・新セッションで残作業）

### 本日完了・全コミット済み
- 前回クローズ分：CommonModule `35fb376`／Nonaka `5571c40`。
- **追加1（監視画面 一括削除）**：spec＋実装＋ビルドOK。CommonModule `f77a0b9`／Nonaka `0a57ba9`。
- **追加2（SendConfig ユーザー別＋添付）**：spec 改訂＋実装＋ビルドOK。CommonModule `0373178`／Nonaka `b684de7`。
  - ⚠ 実行時前提：`alter_m_send_config_user_attachment.sql`（db_common_dev）適用済み（owner_user_id/attachment_path）。
- **A 任意PBT＋既存テスト是正**：`dotnet test CommonModule.Tests`＝**21件 全緑（成功20/スキップ1/失敗0）**。clnCoCore `45776a9`／Nonaka `a182c3f`。
  - 追加：SmtpMonitorDelete・PrintMonitorDelete・SendConfigService の PBT。
  - 是正：output_type 廃止に未追随だった既存テスト（PrintQueueServicePropertyTests・PrintMonitor Summary/Filter/Reprint・Integration）＝print-platform 12.15。

### 現在の機能到達（要点）
- 送信設定＝ユーザー別（owner_user_id・NULL=default）。**業務送信は default 採用**（GetActiveAsync が default 限定）。単発テスト送信は GetForUserAsync（ユーザー行→default）＋添付（attachment_path・送信時 File.Exists 判定）。
- 監視画面（Common_Smtp/PrintMonitor）＝複数選択で一括削除（処理中2以外・物理削除・確認ダイアログ）。
- print-platform／dispatch／send-config／monitor-job-delete のコアは実装・テスト緑・実機疎通（メール/FAX）まで確認済み。

### 🟡 新セッションの残作業（A の残・任意PBT／その他）
1. **A 残（任意PBT・スキップ可）**：
   - send-config-master：4.4（画面例示）・6.2（単発送信例示）・添付の PageModel 例示。
   - monitor-job-delete：4.2（未選択→エラー例示）。
   - print-platform：12.14（プリンタ解決の決定性 Property8）・12.16（m_printer upsert 統合）。
   - dispatch-monitoring-consolidation：2.2・7.1〜7.5・10.3・11.5（**MaterialModule.Tests**・別プロジェクト。11.5 は recipient 上書き新仕様で）。
2. **ユーザー動作確認**：/Common/SendConfig（ユーザー別保存・添付 存在/不存在）・監視画面一括削除。
3. **B ユーザー実行系**：J-1 孤立3テーブル DROP（`drop_legacy_orphan_tables_db_material_dev.sql`・破壊的）／J-2（保全後）。
4. **未コミット**：`.kiro/steering/Agnet.md`（PrintAgent/SmtpAgent 起動コマンドの steering・無関係）＝ユーザー判断。
5. **E 将来機能**（未実装案件一覧）：G 計画単価・実績対比／F 所要計算・発注点自動計算／D タンク仕上げ／C-1 用途1 UI／Excelインポート／HULFT 連携。

### 運用メモ（継続）
- spec ワークフロー用サブエージェントは IDE クラッシュ（i.map is not a function）を誘発 → **spec は直接編集**。
- ビルド/テストはユーザー側が既定（明示指示時のみ Kiro 実行）。MainWeb/AuthModule/SharedCore 不変更。テスト＝clnCoCore/CommonModule.Tests・MaterialModule.Tests。
- パスは小文字 `ojiadm23120073`。1ターン1タスク・80%接近で区切り。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。次アクション候補＝A 残の任意PBT（print-platform 12.14 or send-config 例示が軽め／dispatch は MaterialModule.Tests で重め）。

---

## 追加着手：CommonModule 残作業（任意PBT）— print-platform 12.14 Property 8 実装完了

### 経緯
- G-1（原材料 計画単価・計画数量）は要件ヒアリング途中で保留（月単位で品目×年月の計画テーブル新設＋実績対比＝購入(入庫)実績×出庫実績で影響額、という方向まで確定）。**MaterialModule は後回し**にユーザー指示。
- CommonModule の未実装・残作業から着手。4 spec の tasks を精査：コア実装はほぼ完了、残るは主に**任意PBT（`*`）とユーザー実行チェックポイント**。純粋な未実装コアは print-platform 7.4（PrintAgent heartbeat 確認・維持）のみ。

### 実装（clnCoCore/CommonModule.Tests・直接編集）
- 新規 `Pages/PrintMonitor/PrinterResolutionPropertyTests.cs`（**Property 8 プリンタ解決の決定性**）。
  - 実 `PrintJobWorker`（PrintAgent・別ソリューション＝不参照）の D8 解決規則を**自己完結の純粋モデル** `ResolvePrinter(printerName, defaultPrinter, installed)` として定義（Property 7 テストと同方針）。
  - 規則：`printer_name ?? 既定`／解決空→ErrorNoPrinter／指定かつ実インストール集合に無→status=9(ErrorNotInstalled・既定退避なし)／NULL時は既定を存在チェックせず使用／OrdinalIgnoreCase。
  - プロパティ4本：(a) NULL→既定で印刷（存在チェックなし）、(b) 指定かつ実在→当該プリンタ、(c) 指定かつ非実在→既定退避せず status=9、(d) 決定性＋大文字小文字非依存。`[Property(MaxTest=100)]`・`// Feature: print-platform, Property 8` タグ。
  - 診断クリア。
- `print-platform/tasks.md` 12.14＝[x]*。

### ⏳ ユーザー
- `dotnet test CommonModule.Tests`（clnCoCore）でグリーン確認。OKなら本テスト1本をコミット。

### CommonModule 残（任意・次候補）
- print-platform 12.16（m_printer upsert・自動無効化 統合テスト）／7.4（PrintAgent heartbeat 確認・維持＝別ソリューション）。
- send-config-master 4.4/6.2（例示）。monitor-job-delete 4.2（未選択→エラー例示）。smtp-sender 10.2/10.3（統合・SQL Server 前提）。

### 未コミット
- clnCoCore/CommonModule.Tests：PrinterResolutionPropertyTests.cs（新規）。
- Nonaka/.kiro：print-platform tasks 12.14＝[x]・本memo。

---

## CommonModule 残作業（任意PBT）続き — print-platform 12.16 m_printer upsert 統合テスト完了

- コミット済：12.14 Property 8＝clnCoCore `9c52786`／Nonaka `aaa91db`。
- 新規 `CommonModule.Tests/Integration/PrinterInventoryUpsertIntegrationTests.cs`（**12.16**）。
  - 実 `PrinterInventoryHostedService`（PrintAgent・別ソリューション＝不参照）の upsert・自動無効化規則を副作用同一の自己完結ルーチン `RunUpsert` で再構成し、InMemory `CommonDbContext`＋CommonModule `MPrinter` で検証（一意DB名）。
  - 例1：追加(PR-C)/更新(PR-A・is_default=1・last_seen)/退役無効化(PR-B は今回列挙に無→is_active=0)/他機(M2)不変。
  - 例2：再実行べき等（重複追加なし）＋既定変更追随（PR-A→is_default=0, PR-B→is_default=1・last_seen=t2）。
  - `[Fact]`×2・診断クリア。
- `print-platform/tasks.md` 12.16＝[x]*。→ **task group 12 の 12.1〜12.16 すべて完了**（残 12 の CP は無し・実デプロイ/実DBはユーザー）。

### ⏳ ユーザー
- `dotnet test CommonModule.Tests` グリーン確認（12.14＋12.16 追加分）。

### CommonModule 残（任意・次候補）
- send-config-master 4.4（管理画面 例示）・6.2（単発送信 例示）。monitor-job-delete 4.2（未選択→エラー例示）。smtp-sender 10.2/10.3（SQL Server 前提・スキップ可）。print-platform 7.4（PrintAgent heartbeat＝別ソリューション確認）。

### 未コミット（このあとコミット）
- clnCoCore/CommonModule.Tests：PrinterInventoryUpsertIntegrationTests.cs（新規）。
- Nonaka/.kiro：print-platform tasks 12.16＝[x]・本memo。

---

## CommonModule 残作業（任意PBT）続き — send-config 4.4/6.2・monitor-job-delete 4.2 例示テスト完了

- コミット済：12.14＝clnCoCore `9c52786`／Nonaka `aaa91db`。12.16＝clnCoCore `fee19de`／Nonaka `e2d8889`。
- **send-config-master 4.4/6.2**：`CommonModule.Tests/Pages/SendConfig/SendConfigPageTests.cs`（新規）。
  - 4.4 管理画面：OnGetAsync ユーザー行→HasExisting=true／default フォールバック(Id=0)／OnPostSave 新規作成(default 不変)・既存更新→Redirect／ModelState 不正→Page 未保存／ログイン不明→Page＋Error。PageContext/TempData/Claims スタブ・InMemory。
  - 6.2 単発テスト送信：FAX→`EnqueueAsync("common","fax",…,test_fax_number,…,pdfPath=null)` を1回／Mail→mail+test_email 1回／宛先未設定→未投入＋Error／設定 null→未投入＋Error／添付非空かつ読込不可→未投入＋「添付ファイルが読み込めません」。`ISendConfigService`/`ISmtpQueueService` を Moq。
- **monitor-job-delete 4.2**：`Pages/SmtpMonitor/SmtpMonitorDeleteExampleTests.cs`・`Pages/PrintMonitor/PrintMonitorDeleteExampleTests.cs`（各新規）。未選択→0件＋「削除するジョブを選択してください。」／処理中(2)のみ→0件残存＋除外注記／混在→削除可(1/3/9)のみ削除・処理中残存＋件数。両監視画面・InMemory。
- tasks：send-config 4.4/6.2＝[x]*、monitor-job-delete 4.2＝[x]*。全診断クリア。

### CommonModule 任意PBT の到達
- 実装可能な任意PBTはほぼ消化：print-platform 12.14/12.16、send-config 3.3(既)/4.4/6.2/8.6(既)、monitor-job-delete 4.1(既)/4.2。
- 残るのは環境前提のもの：**smtp-sender 10.2/10.3（SQL Server 前提の統合・スキップ可）**・**print-platform 7.4（PrintAgent heartbeat 確認＝別ソリューション）**。CommonModule.Tests の単体/PBT 範囲では対象外。

### ⏳ ユーザー
- `dotnet test CommonModule.Tests`（clnCoCore）でグリーン確認（本セッション追加：PrinterResolution/PrinterInventoryUpsert/SendConfigPage/Smtp・PrintMonitorDeleteExample）。

### 未コミット（このあとコミット）
- clnCoCore/CommonModule.Tests：SendConfigPageTests.cs・SmtpMonitorDeleteExampleTests.cs・PrintMonitorDeleteExampleTests.cs（各新規）。
- Nonaka/.kiro：send-config-master/monitor-job-delete tasks・本memo。

---

## dotnet test CommonModule.Tests 実行（Kiro・ユーザー指示）＝グリーン

- `dotnet test CommonModule.Tests`（clnCoCore）＝**合計44・成功43・失敗0・スキップ1**（スキップ＝`PrintQueueConcurrencyIntegrationTests`・SQL Server db_common_dev 前提／環境変数 `PRINT_PLATFORM_IT_CONN` 設定時のみ・想定どおり）。
- 本セッション追加分（PrinterResolution Property 8×4／PrinterInventoryUpsert×2／SendConfigPage 管理画面6＋単発送信5／Smtp・PrintMonitorDeleteExample 各3）を含め全緑。ビルドも成功。
- コミット済：clnCoCore `9c52786`/`fee19de`/`7823f28`、Nonaka `aaa91db`/`e2d8889`/`4d0ddb7`。

### CommonModule 任意PBT ＝実装可能分は完了
- 残は環境前提のみ：smtp-sender 10.2/10.3（SQL Server）・print-platform 7.4（PrintAgent heartbeat＝別ソリューション）。次セッションは別作業 or これら環境依存項目。

---

## 新規 spec 起草：commonmodule-distribution（CommonModule クローン配布の整備）

### 経緯・確定事項（ユーザー）
- 環境依存の残タスクは実益薄と判断 → CommonModule の新規テーマへ。3案（機能追加/クローン化/Agent起動停止のWinアプリ管理）を提案。
- 起動/停止＝**OSレベル（Windows サービス）を Windows アプリで**（＝別 spec `agent-service-manager` 候補・今回は未着手）。
- クローン化＝**CommonModule を独立 Git リポジトリとして他開発者が各自ソリューションにクローン参照（ProjectReference）し Pull/Push で同期**。共有モデル＝**A（現行方式維持＋規約化）**。
- SharedCore 供給は**消費者責務＝対象外**。今回は **CommonModule のみ**対象。
- 事実確認：CommonModule は独立リポジトリ（origin GitHub `n-nonaka-oim/CommonModule`・main・クリーン）。`CommonModule.csproj` は `..\clnCoCore\SharedCore` を相対参照＝**`CommonModule` を `clnCoCore` の兄弟に置けば解決**（配置規約の核）。`AddCommonModule(services, configuration)`＋`CommonDb` 必須。docs/sql に DDL 一式あり。

### 作成（単一正本 `.kiro/specs/CommonModule/commonmodule-distribution/`・全診断クリア・直接編集）
- **requirements.md**（R1 README／R2 依存・前提／R3 参照＋配置規約／R4 ホスト登録 AddCommonModule＋CommonDb／R5 DB前提・SQL索引／R6 認可・導線／R7 ブランチ・貢献 CONTRIBUTING／R8 公開契約・破壊的変更告知／R9 変更範囲）。
- **design.md**（Architecture＝モデルA mermaid＋標準レイアウト図／Components and Interfaces＝整備物＋既存公開API／Data Models＝db_common_dev 必要テーブル7＋dbAuthTest 導線／Correctness Properties 1-4（Validates 付）／Error Handling／Testing Strategy／成果物設計＝README/USAGE/docs README SQL索引/CONTRIBUTING/CHANGELOG）。
- **tasks.md**（1 README／2 USAGE(2.1 配置・参照/2.2 登録・DB・導線・確認・TS)／3 docs/README SQL索引追記／4 CONTRIBUTING／5 CHANGELOG／6 CP＝新規消費者ドライラン（ユーザー））。全て**文書作成**・コード/スキーマ/csproj 不変更。

### 重要な設計判断
- コードは一切変更しない（配布容易性の文書整備のみ）。成果物は **CommonModule リポジトリ**（別 Git）に置く＝実装時はそちらにコミット/Push（ユーザー承認・CONTRIBUTING ブランチ運用）。
- 標準配置規約：`workspace-root/{clnCoCore/SharedCore, CommonModule}` の兄弟配置で相対参照解決。SharedCore は消費者が用意。

### 次アクション
- ユーザー確認後、tasks 1〜5 を実装（CommonModule リポジトリに README/USAGE/CONTRIBUTING/CHANGELOG 作成＋docs/README SQL索引追記）。1タスクずつ・完了ごとに提示。
- 未着手候補：`agent-service-manager`（Windows 管理アプリ・OSレベル start/stop/install・別ソリューション）。

### コミット（このあと）
- Nonaka/.kiro：commonmodule-distribution spec 3点＋本memo。

---

## commonmodule-distribution 実装（tasks 1〜5 完了）

### クローン先の制約（重要）
- ユーザー指定の `\\OJIADM23120073\Labs\web\asp\CoCore\clnCommonModule` は**Kiro のワークスペース許可外**（許可＝`CoCore\Nonaka` と `WindowsService` のみ）。`list_directory` で `CoCore` 直下が "Access denied: File access is restricted to workspace"。→ 案1採用：**正本リポジトリ `\\...\Nonaka\CommonModule`（origin GitHub と同一・許可内）に作成**。clnCommonModule はユーザーが clone/pull で取得すれば docs が入る（単一正本維持）。

### 作成物（CommonModule リポジトリ・別 Git origin GitHub）
- `README.md`（一次導線：概要・共有モデルA・クイックスタート・依存前提・フォルダ配置規約・関連リンク・Non-Goals）
- `docs/USAGE.md`（配置規約図・ProjectReference例・AddCommonModule＋CommonDb例・DB準備・導線登録・動作確認・トラブルシュート表）
- `docs/README.md`（既存に**SQL索引・適用順表8ステップ**＋新規不要スクリプト注記を追記）
- `CONTRIBUTING.md`（main保護・feature/PR・Pull/Push・モデルAのバージョン非固定注意・breaking＋CHANGELOG必須）
- `CHANGELOG.md`（公開契約定義：AddCommonModule/CommonDb・各サービス署名・ページURL・DBスキーマ／Unreleased＋初版）
- コード・スキーマ・csproj は不変更（文書のみ）。
- tasks 1〜5＝[x]。残 6（新規消費者ドライラン＝ユーザー）。

### コミット（このあと）
- CommonModule リポジトリ（Nonaka\CommonModule）：README/USAGE/CONTRIBUTING/CHANGELOG/docs README。※Push はユーザー承認後・CONTRIBUTING のブランチ運用に従う。
- Nonaka/.kiro：tasks 1〜5＝[x]・本memo。

### 次アクション
- ユーザー：CommonModule リポジトリの docs をレビュー → push（origin）→ 必要なら `CoCore\clnCommonModule` に clone/pull。tasks 6 ドライラン。
- 未着手候補：`agent-service-manager`（Windows 管理アプリ・OSレベル start/stop/install）spec 起草。

### クローンフォルダ命名（cln 接頭辞・ユーザー指示）
- 他モジュール（clnCoCore/clnDemoModule）に合わせ、消費者のクローン先を **`clnCommonModule`**（cln 接頭辞）に統一。README/USAGE/design の配置図・ProjectReference例・クローン例（`git clone ... clnCommonModule`）を更新。
- `CommonModule.csproj` の `..\clnCoCore\SharedCore` は「clnCoCore の兄弟であること」だけに依存＝クローン名 `clnCommonModule` でも解決（csproj ファイル名は不変）。

---

## clnCommonModule クローン作成＋GitHub 初回公開（push）

### 重要発見
- **GitHub origin/main が初期スケルトン(`35eae96`)のまま**で、ローカル正本 `Nonaka\CommonModule` の main が **未push 20件以上**（send-config／print-platform／monitor-delete 実装全体＋本日 docs）先行していた。=> クローンしても中身が入らない状態だった。

### 実施（シェル経由・ファイル編集ツールはWS外で不可だが execute_pwsh は到達可）
1. ユーザー承認のうえ **`git push origin main`**（`35eae96..dfd5adc`）＝実装全体＋docs を GitHub 初回公開。
2. `\\OJIADM23120073\Labs\web\asp\CoCore\clnCommonModule`（ユーザーが作成）へ **GitHub から clone**（origin=GitHub・main・cln 接頭辞）。
3. push 後に **`git pull origin main`** で clnCommonModule を最新化 → 42ファイル反映（Areas/Data/Services/docs/sql/README/USAGE/CONTRIBUTING/CHANGELOG）。HEAD=`dfd5adc`。

### 状態
- GitHub `n-nonaka-oim/CommonModule` main = `dfd5adc`（最新・実装＋docs 公開済み）。
- `clnCommonModule` = GitHub と同期済みの消費者クローン（他開発者はこれと同様に clone→ProjectReference→pull/push）。
- ⚠ clnCommonModule は Kiro ワークスペース外のためファイル編集ツールでは触れない（シェルからは可）。

### 注意（今後の運用）
- 以後、CommonModule の変更は Nonaka\CommonModule で commit → **push（origin）** しないと他開発者クローンに反映されない。今回のように push 忘れに注意。
- CONTRIBUTING では main 保護・feature/PR を推奨だが、今回は初回公開として main 直 push（オーナー個人リポジトリ・ユーザー判断）。

### commonmodule-distribution spec 現況
- tasks 1〜5 実装済み・GitHub 公開済み。残 6（新規消費者ドライラン）＝clnCommonModule を clnCoCore 兄弟配置＋SharedCore 用意でビルド確認（ユーザー）。

---

## レイアウト方針の検討＋ワークスペース権限の知見（未決・次セッション判断）

### 論点（ユーザー提起）
- 現状は開発元が `Nonaka\CommonModule` で作業＋別に `CoCore\clnCommonModule` クローン＝**2作業コピー**。今回の push 漏れ（GitHub 初期のまま）はこの二重管理が一因。
- 「本体を `clnCommonModule`（clnCoCore 兄弟）に寄せ、slnCoCore は pull する single-source が smart では？」→ **その通り。ベストプラクティス＝「1マシン1クローン・開発元も消費者と同じ標準配置でドッグフーディング」**。

### ベストプラクティス（結論）
- 理想: `<root>\{clnCoCore, clnCommonModule}` を全員（開発元含む）共通配置。MainWeb は `..\..\clnCommonModule\CommonModule.csproj`、CommonModule は `..\clnCoCore\SharedCore` を参照。
- 単一クローンに寄せてドリフト/‑push忘れを防ぐ。

### ⚠ Kiro ツール制約の知見（重要）
- **ファイル編集ツール（fs_write/read/list/diagnostics）はセッション開始時の許可ルート `...\Nonaka` と `...\WindowsService` に固定**。VS Code で `\\OJIADM23120073\Labs` を後から追加しても**当該セッションには反映されない**（`Labs`・`CoCore\clnCommonModule` とも "outside the workspace" 拒否）。
- **シェル（execute_pwsh）は広域到達可**：`CoCore\clnCommonModule` への clone/pull/push は成功。git 運用は現状でも可能。
- 反映には **Reload Window / 新規セッション**が必要。再開後は `CoCore\clnCommonModule` を Kiro でリッチ編集可能になる見込み。

### 次セッションの選択肢（レイアウト・未決）
1. Reload 後、`CoCore\clnCommonModule` を単一作業コピーにして開発元もそこで作業（clnCoCore 兄弟・要 SharedCore 供給）。MainWeb 参照更新は project-rules で要ユーザー確認。
2. あるいは `Nonaka\CommonModule` を `Nonaka\clnCommonModule` にリネームして規約名に合わせる（Kiro WS 内維持・MainWeb 参照 `..\..\clnCommonModule` に更新＝要承認）。
3. 現行維持＋「1クローン・push 必須」を運用ルール化。
- いずれも **MainWeb.csproj の参照パス変更（要ユーザー承認）** と **重複クローンの解消**が論点。

### 現状の到達（コミット済み）
- GitHub `n-nonaka-oim/CommonModule` main=`dfd5adc`（実装＋docs 公開済み）。`CoCore\clnCommonModule` は同期済み消費者クローン。
- commonmodule-distribution spec：tasks 1〜5 完了・6（ドライラン）残。
- 本日の任意PBT（print-platform 12.14/12.16・send-config 4.4/6.2・monitor-job-delete 4.2）＝実装・dotnet test 44件緑・コミット済み。

### 再開合図
「再開します、session-memoを確認」。**次はまず Reload Window して `\\OJIADM23120073\Labs` 認識を確認 → レイアウト方針（上記1/2/3）を決定**。

---

## レイアウト集約 実施（サブ案2・Nonaka\CommonModule → clnCommonModule リネーム）

### 決定（ユーザー承認）
- 2作業コピー（開発元 `Nonaka\CommonModule`＝ビルド正本／消費者 `CoCore\clnCommonModule`）の二重管理＝push漏れ・ドリフト源。→ **サブ案2**：開発元コピーを cln 命名の単一正本へ集約。`Nonaka\CommonModule` を `Nonaka\clnCommonModule` にリネームし、ビルド正本を Nonaka 内（clnCoCore の真の兄弟・Kiro 編集可）に維持。`clnCoCore`/`clnDemoModule`/`clnMaterialModule` と命名統一。

### 実施内容（Kiro・完了）
- **リネーム**：Kiro のファイル監視で `Rename-Item` が Access denied（多数の Kiro プロセスがワークスペース `Nonaka` を再帰監視・フォルダ直リネーム不可）。→ 回避策：新フォルダ `clnCommonModule` を作成し `CommonModule` 配下の全項目（隠し含む・.git 込み）を `Move-Item`（同一ボリューム=メタデータ操作・データ複製なし）で移動 → 空の旧 `CommonModule` を削除。`.vs`/`bin`/`obj`（git 管理外）は事前削除。`.git` 健在確認（origin GitHub 追跡不変）。
- **参照4ファイル更新**（`.csproj`/`.sln` は gitignore 対象＝grep 不可・手動特定）:
  - `clnCoCore\slnCoCore.sln`：`..\CommonModule\` → `..\clnCommonModule\`
  - `clnCoCore\MainWeb\MainWeb.csproj`：`..\..\CommonModule\` → `..\..\clnCommonModule\`（**MainWeb 変更＝プラットフォームモジュールのホスト登録の例外・承認済み**）
  - `MaterialModule\MaterialModule.csproj`：`..\CommonModule\` → `..\clnCommonModule\`
  - `clnCoCore\CommonModule.Tests\CommonModule.Tests.csproj`：`..\..\CommonModule\` → `..\..\clnCommonModule\`
  - `clnCommonModule\CommonModule.csproj` の `..\clnCoCore\SharedCore` は変更不要（親 Nonaka のまま解決・確認済み）
- 全走査で旧パス `\CommonModule\CommonModule.csproj` 参照＝0件・新パス4件確認。
- spec 反映：`commonmodule-distribution` design に「レイアウト集約」章追記／tasks に task 7（7.1/7.2＝[x]・7.3/7.4＝ユーザー）＋依存グラフ更新。全診断クリア。

### ⏳ ユーザー（次アクション）
1. **slnCoCore ビルド確認**：全プロジェクトが `clnCommonModule` を参照して解決すること（MainWeb/MaterialModule/CommonModule.Tests 含む）。旧 `.vs`/`bin`/`obj` は削除済みのため再生成される。
2. **重複クローン退役**：`CoCore\clnCommonModule`（配置ズレ・SharedCore 相対参照が解決しない）を退役（削除はユーザー判断＝破壊的）。以後「1マシン1クローン・commit→push 必須」を運用ルール化。
3. コミット：`clnCommonModule`（リネーム後・変更なし）／clnCoCore（sln/MainWeb/CommonModule.Tests 参照更新）／MaterialModule（参照更新）／Nonaka/.kiro（spec/memo）。※フォルダ移動は各 git では追跡外/内で見え方が異なるため要確認。

### 注意
- Nonaka メタリポジトリ上、旧 `CommonModule` 配下が tracked だった場合は delete、`clnCommonModule` 配下が add として現れうる（内部 .git を持つネスト repo なら通常 gitignore/untracked）。git status で確認のうえコミット。
- MainWeb/AuthModule/SharedCore の機能ソースは不変更（今回は参照パス付け替えのみ＝ホスト登録の例外）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。次＝ユーザーの slnCoCore ビルド確認 → OKなら退役＋コミット。

---

## レイアウト集約の撤回 — 命名規約に整合（本体=CommonModule／クローン=clnCommonModule）確定

### 経緯
- 直前で本体を `Nonaka\clnCommonModule` にリネーム＋4参照を `clnCommonModule\` に変更したが、ユーザー指摘により**このワークスペースの規約（`cln`なし=本体作業ツリー／`cln`あり=クローン。`MaterialModule` と `clnMaterialModule` の先例・MainWeb は `..\..\MaterialModule` を参照）と逆**と判明 → **撤回**。

### 実施（撤回・完了）
- フォルダを `Nonaka\clnCommonModule` → `Nonaka\CommonModule` に戻す（VS 未起動確認・`.vs`/`bin`/`obj` 事前削除・中身移動＋空フォルダ削除・`.git` 健在＝origin 追跡不変）。
- 参照4ファイルを本体パスに復帰：
  - `clnCoCore\slnCoCore.sln`：`..\CommonModule\CommonModule.csproj`
  - `clnCoCore\MainWeb\MainWeb.csproj`：`..\..\CommonModule\CommonModule.csproj`
  - `MaterialModule\MaterialModule.csproj`：`..\CommonModule\CommonModule.csproj`
  - `clnCoCore\CommonModule.Tests\CommonModule.Tests.csproj`：`..\..\CommonModule\CommonModule.csproj`
- 全走査：旧 cln 参照0件・本体参照4件・SharedCore 解決OK。＝**今日のリネーム前と同じ状態に復帰**。
- 別途 `clnCoCore\.vs` は削除済み（VS が旧 CommonModule.csproj タブを復元しようとするエラーの解消用）。

### 確定した配置・命名
| 区分 | パス | 役割 |
|---|---|---|
| 本体（開発・push 元） | `…\CoCore\Nonaka\CommonModule` | git 本体（origin=GitHub `n-nonaka-oim/CommonModule`）・slnCoCore が参照 |
| クローン（消費者） | `…\CoCore\clnCommonModule` | pull のみ・検証用（不要なら退役可） |
| リモート | GitHub `n-nonaka-oim/CommonModule` | 配布の単一真実 |

- 規約：`cln`なし=本体／`cln`あり=クローン。
- 運用ルール：**変更は本体 `Nonaka\CommonModule` でコミット→GitHub push、クローンは pull のみ**（push漏れドリフト防止）。
- spec 反映：design「レイアウト・命名規約」章を確定版に差し替え／tasks 7（7.1/7.2=[x]・7.3/7.4=ユーザーCP）更新。診断クリア。

### ⏳ ユーザー
1. `slnCoCore.sln` を開き直す（`.vs` 再生成）→ ビルドし全プロジェクトが本体 `..\CommonModule\CommonModule.csproj` で解決することを確認。旧パスエラーは出ないはず。
2. コミット対象：今回はフォルダ名・参照とも**リネーム前と同一に復帰**したため、clnCoCore/MaterialModule の csproj・sln は実質差分なし（gitignore 対象なら元々追跡外）。Nonaka/.kiro（spec/memo）は差分あり。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。次＝ユーザーの slnCoCore ビルド確認。

---

## ビルド確認 OK（本体=CommonModule 復帰後）

- ユーザーが `slnCoCore.sln` を開き直しビルド → **OK**。全プロジェクトが本体 `..\CommonModule\CommonModule.csproj` を参照して解決。旧パス（`clnCommonModule` / 旧 CommonModule タブ）エラーも解消。
- tasks 7.3＝[x]。task 7 は 7.4（クローンの位置づけ＝退役はユーザー任意）を残すのみ。
- 確定：本体 `Nonaka\CommonModule`（開発・push 元）／クローン `CoCore\clnCommonModule`（pull のみ）。規約 cln=クローン。

### 残（任意・ユーザー）
- クローン `CoCore\clnCommonModule` の退役（不要なら削除・破壊的）。
- Nonaka/.kiro の spec/memo コミット（本日分）。csproj/sln はリネーム前と同一復帰のため実質差分なし（gitignore 対象なら追跡外）。

---

## 配布モデルの確定（CoCore ソリューション限定・消費者クローン配置条件）

### ユーザー確認・合意
- **CommonModule は CoCore 系ソリューション（MainWeb 利用）に限定**。理由＝`CommonModule.csproj` が `..\clnCoCore\SharedCore` を参照（ドメイン層依存）＝SharedCore を供給できる CoCore 以外では成立しない。単独ビルド不可。
- 消費者（他開発者）は自身で: MainWeb（ホスト）の ProjectReference 追加＋`AddCommonModule`＋`CommonDb`＋DB テーブル＋認可導線。
- この条件を満たせばクローン CommonModule は利用可能。

### 成立条件（配置・重要）
- クローン `clnCommonModule` は**消費者自身の `clnCoCore`（SharedCore 含む）の兄弟**に置く必要あり（`..\clnCoCore\SharedCore` 解決のため）。
- OK: `CoCore\{開発者名}\{clnCoCore, clnCommonModule}`。NG: `CoCore\clnCommonModule`（直下）＝隣に `CoCore\clnCoCore` が無く（確認済み・存在しない）SharedCore 未解決でビルド不可。
- ⇒ 共有参照先は「CoCore 直下の clnCommonModule」ではなく「各自の clnCoCore の隣にクローン」が正。`CoCore\clnCommonModule`（直下）は成立条件外＝退役 or 放置。

### あなた（開発元）
- `Nonaka\clnCoCore\slnCoCore.sln` → 本体 `Nonaka\CommonModule`（隣に `Nonaka\clnCoCore`＝SharedCore 解決）。変更時 push。＝現状のままで正。

### spec 反映
- design に「利用前提（CoCore ソリューション限定）」章を追記（配置条件・消費者責務を明記）。診断クリア。USAGE.md（クローンは clnCoCore の兄弟）と整合。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## Agent サービス名リネーム（Material… → Common…）＋運用Q&A

### 決定・実施（ユーザー確定：CommonPrintAgent / CommonSmtpAgent）
- コード（各 `Program.cs`・WindowsService 別 git）:
  - PrintAgent：`ServiceName` と EventLog `SourceName` を `MaterialPrintAgent` → `CommonPrintAgent`。
  - SmtpAgent：同 `MaterialSmtpAgent` → `CommonSmtpAgent`。
- 運用 docs（新名に更新）:
  - `WindowsService\PrintAgent\docs\spec.md`（sc.exe create/start/stop/delete）・`requirements.md`（AC1 サービス名）。
  - `WindowsService\SmtpAgent\docs\spec.md`（sc.exe create/start）。
  - 本体 `Nonaka\CommonModule\docs\smtp-sender実送信テスト手順.md`（Worker 名）。※clone(CoCore\clnCommonModule) は pull で反映。
- 履歴（未変更・意図的）: session-memo 各日／`PrintAgent\docs\tasks.md` V-1／`direct-print` 実装案（過去記録・設計案のため据え置き）。

### ⚠ 再インストール必要
- 既に旧名 `MaterialPrintAgent`/`MaterialSmtpAgent` でサービス登録済みなら、`sc stop`→`sc delete`（旧名）→ 新名で `sc create` し直す。EventLog ソース名変更も管理者権限。

### 運用Q&A（回答済み）
1. 別サーバ移設時：Windows Service はマシンごとの登録が必要（新サーバで sc create、旧から delete）。
2. 役割分担：CommonModule(Web)=キュー投入＋監視画面(表示のみ)。**キュー監視(ポーリング)と送信/印刷は Agent 側**。
3. Agent 実行に登録は必須でない：`AddWindowsService()` はサービス対応にするだけで、コンソール(`dotnet run`)でも動く。登録が要るのは常駐サービスとして動かすときのみ。
4. 「未登録ならエラー」「自動登録」：どちらも技術的に可能だが、自己判定/自己インストールは権限・堅牢性で非推奨。推奨は install/uninstall スクリプト or CLI 引数(`--install`)方式で分離。

### 🟡 未決（次アクション・ユーザー選択待ち）
- **登録方式**：a) install/uninstall PS スクリプトを各 Agent repo に用意（推奨）／b) exe に `--install`/`--uninstall` CLI 引数追加。決まり次第、各 Agent の deploy 手順(spec.md)を整備。
- 旧名サービスが稼働中なら停止→delete→新名 create（ユーザー実行）。
- Agent 変更のコミット/Push は各 repo（PrintAgent/SmtpAgent は独立 git）でユーザー実施。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## Agent サービス登録方式 a 採用：install/uninstall スクリプト作成

### 作成（各 Agent repo・独立 git）
- `WindowsService\PrintAgent\install-service.ps1` / `uninstall-service.ps1`
- `WindowsService\SmtpAgent\install-service.ps1` / `uninstall-service.ps1`
- 仕様：`#requires -RunAsAdministrator`・`New-Service`（自動起動）・`sc.exe failure` で障害時自動再起動（5秒×3・24h reset）。install は exe 存在チェック＋既存サービス検出でガード・`-BinPath`/`-StartAfterInstall` パラメータ。uninstall は停止→delete＋**旧名（MaterialXxxAgent）を -AlsoRemove 既定で後片付け**（リネーム移行対応）。既定 BinPath＝`C:\{Print|Smtp}Agent\App\{Print|Smtp}Agent.exe`。
- 方針：開発＝`dotnet run` コンソール実行（登録不要）、本番サーバ＝スクリプトで登録。

### docs 更新
- `PrintAgent\docs\spec.md` §3/§4・`SmtpAgent\docs\spec.md` デプロイ節に「推奨＝install/uninstall スクリプト」＋手動 sc.exe（同等）を併記。サービス名 Common{Print|Smtp}Agent。

### ⏳ ユーザー
- 旧名サービスが稼働中なら `.\uninstall-service.ps1`（旧名も消える）→ publish → `.\install-service.ps1 -StartAfterInstall`（管理者 PowerShell）。
- Agent 変更（Program.cs リネーム＋スクリプト＋docs）のコミット/Push は各 repo（PrintAgent/SmtpAgent 独立 git）でユーザー実施。

### 補足（未対応・別件）
- `SmtpAgent\docs\spec.md` の「連携テーブル」節は旧モデル（t_order_reports/fax_status）記述のまま＝現行 t_smtp_queue と不整合（今回のサービス登録タスク対象外・別途整合可）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## SmtpAgent spec.md 不整合訂正（旧モデル → 現行 t_smtp_queue モデル）

- 実コード（TSmtpQueue/MSmtpConfig/MSmtpAgentControl/SmtpJobWorker/SmtpSendService）を正として `WindowsService\SmtpAgent\docs\spec.md` を全面改稿。
- 訂正内容:
  - キュー: `t_order_reports`＋`fax_status`＋`print_payload` → **`t_smtp_queue`＋`status`（1/2/3/9）＋ジョブ自身が From/宛先/件名/本文/pdf_path 保持**。
  - 送信モード: `config_key`→`m_smtp_config` 解決。fax_domain 空=メール直送／`@`始まり=メールtoFAX（数字抽出・先頭0→81・ドメイン付与）／完全アドレス=固定宛先（レガシー・非推奨・残存）。
  - To/CC/BCC: `;` 分割・trim・空除外。CC/BCC は FAX 正規化なし。
  - PDF: `pdf_path` 実在時のみ添付／指定あるが不在は**添付なしで送信＋警告**（旧「不在→fax_status=9」は誤り）／未指定は添付なし。
  - 設定: `SmtpAgent:PdfDirectory` 廃止（ジョブが絶対 pdf_path 保持）。m_smtp_config は config_key/host/port/fax_domain のみ（from/test は持たない）。
  - 監視画面: `/Material/SmtpMonitor` → **`/Common/SmtpMonitor`**。テスト送信は投入側 recipient 上書き方式（Worker にテスト専用ロジック無し）。
  - サービス名 `CommonSmtpAgent`・デプロイはスクリプト方式併記。
- 残存2ヒットは意図的（「t_order_reports 等に依存しない」否定文・uninstall の旧名後片付け注記）。
- ※PrintAgent spec は今回対象外（別途必要なら確認）。

### ⏳ ユーザー
- SmtpAgent の変更（Program.cs 名称・スクリプト・spec.md）を SmtpAgent repo でコミット/Push。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## 新規 spec 起草：agent-service-manager（Agent 管理 WinForms アプリ）

### 経緯・確定要件（ユーザー）
- SmtpAgent/PrintAgent の起動・停止・状態管理を WinForms(.NET8) 管理アプリ化。**ローカル限定・install/uninstall 含む・ハートビート＋キュー滞留件数表示**まで。WinForms がベストか→小規模運用ツールとして妥当と回答。

### 作成（単一正本 `.kiro/specs/CommonModule/agent-service-manager/`・直接編集・全診断クリア）
- `.config.kiro`（feature/requirements-first）。
- requirements.md：R1 一覧／R2 起動停止／R3 状態・自動更新／R4 登録解除(install)／R5 ハートビート／R6 キュー滞留件数／R7 管理者昇格／R8 ローカル限定・DB接続前提／R9 変更範囲（Agent本体・DBスキーマ不変更・リモート/行単位再送は対象外）。EARS・Glossary 付。
- design.md：WinForms 構成（MainForm＋定期タイマー）／`IServiceControlService`(ServiceController)・`IServiceInstallService`(sc.exe)・`IAgentStatusReader`(db_common_dev 読取専用)・`AppConfig`／`AgentDescriptor`（CommonSmtpAgent=status／CommonPrintAgent=print_status／m_*_agent_control）／Data Models（読み取りのみ）／Correctness Properties 4（応答判定境界・件数保存則・状態マッピング全域・操作ガード）。
- tasks.md：1 雛形＋対象定義／2 純粋ロジック(2.1〜2.4)／3 サービス制御・登録アダプタ／4 DB読取／5 UI／6 PBT(6.1〜6.4・任意*)／7 CP(ユーザー実機)。依存グラフ付。

### 実装方針の要点
- 新規独立プロジェクト（`\\...\WindowsService\AgentServiceManager` 想定・net8.0-windows）。他モジュール参照/変更なし。DB は読み取りのみ。管理者昇格(app.manifest)。
- 純粋ロジックを I/O から分離して FsCheck で検証。ServiceController/sc.exe/実DB は実機確認(ユーザー)。

### 次アクション
- ユーザーが tasks レビュー → OK なら実装着手（1.1 雛形から1タスクずつ）。プロジェクト配置先（新規 git repo か WindowsService 配下か）を実装前に確認。
- コミット/Push は当該プロジェクト repo 方針に従う（ユーザー）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。

---

## 🔴 本日のクローズ・チェックポイント（2026/07/09 終了）

### 本日完了（要点）
1. **CommonModule レイアウト/命名 確定**：本体＝`Nonaka\CommonModule`（開発・push 元・slnCoCore が参照）／クローン＝`CoCore\clnCommonModule`（消費者・pull のみ）。規約 cln=クローン。いったん `clnCommonModule` へ集約リネームしたが規約と逆のため撤回・現状復帰。slnCoCore ビルド OK 確認済み。`clnCoCore\.vs` 削除で VS の旧パスタブエラーも解消。
   - 利用前提を design に明記：CommonModule は CoCore ソリューション限定（SharedCore 参照）。消費者はクローンを自分の clnCoCore の兄弟に置き、MainWeb 参照＋AddCommonModule＋CommonDb＋DBテーブル＋導線を自前で用意。
2. **Agent サービス名リネーム**：`Material{Print,Smtp}Agent` → `Common{Print,Smtp}Agent`（各 Program.cs の ServiceName／EventLog SourceName）。運用 docs（両 spec.md・PrintAgent requirements・本体 CommonModule テスト手順 doc）も更新。
3. **Agent 登録方式 a**：各 Agent repo に `install-service.ps1`/`uninstall-service.ps1` 作成（New-Service 自動起動＋sc.exe failure 再起動・exe/既存チェック・uninstall は旧名 Material… も後片付け）。spec.md にスクリプト方式を併記。
4. **SmtpAgent spec.md 全面改稿**：旧モデル（t_order_reports/fax_status/print_payload/PdfDirectory/Material監視）→ 現行 t_smtp_queue モデル（status・config_key・mail/fax・pdf_path・/Common/SmtpMonitor）に整合。
5. **新規 spec `agent-service-manager`**（`.kiro/specs/CommonModule/agent-service-manager/`）：requirements/design/tasks＋.config.kiro 作成・全診断クリア。WinForms(.NET8)・ローカル限定・install 含む・ハートビート＋キュー滞留件数表示。配置先＝**a: `\\...\WindowsService\AgentServiceManager`（新規 git repo）で確定**。

### 🟡 次セッションの次アクション
1. **agent-service-manager 実装着手**：tasks 1.1（WinForms 雛形＋app.manifest requireAdministrator）から1タスクずつ。配置＝`\\...\WindowsService\AgentServiceManager`（net8.0-windows）。
2. 純粋ロジック(2.1〜2.4)→ アダプタ(3/4)→ UI(5)→ 任意PBT(6)→ 実機CP(7) の順。
3. 未処理の任意事項：`CoCore\clnCommonModule` 退役（任意）／PrintAgent spec.md の点検（今回 SmtpAgent のみ改稿）。

### コミット状況（本日・ユーザー実施分）
- **本体 CommonModule**（`Nonaka\CommonModule`・独立 git・origin GitHub）：docs（smtp-sender テスト手順の Worker 名）→ commit/push はユーザー。
- **PrintAgent / SmtpAgent**（各独立 git）：Program.cs 名称・install/uninstall スクリプト・docs → 各 repo で commit/push はユーザー。
- **Nonaka/.kiro**：commonmodule-distribution spec 更新（レイアウト/命名/利用前提）・agent-service-manager spec 新規・本 memo → commit はユーザー。
- ※csproj/sln はリネーム前と同一復帰のため clnCoCore/MaterialModule は実質差分なし。

### 運用メモ（継続）
- 本体で編集→push、クローンは pull のみ（ドリフト防止）。MainWeb/AuthModule/SharedCore 不変更。
- spec は直接編集（サブエージェント不使用・IDE クラッシュ回避）。1ターン1タスク。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260709）。次アクション＝agent-service-manager 実装（tasks 1.1 雛形）。
