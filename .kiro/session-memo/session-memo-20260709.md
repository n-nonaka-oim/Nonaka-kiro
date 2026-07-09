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
