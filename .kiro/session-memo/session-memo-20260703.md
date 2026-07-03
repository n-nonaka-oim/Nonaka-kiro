# セッション備忘録（2026/07/03 - Print出力仕様改訂：output_type廃止・投入側ゲート・プリンタ存在チェック・m_printerマスタ）

前セッション（20260702）からの継続。dispatch-monitoring-consolidation 実装 1.1〜3.2 完了・実機確認 A 成功（/Common/PrintMonitor に material/order_approval 待機ジョブ表示）後、ユーザーから新 Print 出力仕様が提示され、2 spec 横断の改訂に着手。

## セッション開始時の状態（20260702 クローズより）
- dispatch-monitoring-consolidation: 1.1／1.2／1.3（親1）・2.1・3.1／3.2（親3）完了・全コミット済み（Material `d7137f4` / Nonaka `1478bed`）。
- 承認→PDF生成→マスタ由来パス保存→t_print_queue 投入 の一連が実機で稼働。
- print-platform は前回まで「完了」扱い。

## 🔴 新 Print 出力仕様（ユーザー確定・本日の主題）
①t_print_queue の output_type 列廃止／②t_print_queue には印刷対象のみ投入／③MaterialModule 側で output_type∈{1,3} のときのみ投入（ゲートを投入側へ）／④printer-name 未指定→既定プリンタ（実装済）／⑤printer-name 指定で非存在→status9 エラー／⑥PrintAgent が m_printer マスタを持ち起動時にインストール済みプリンタを自動 upsert／⑦共有投入関数＝IPrintQueueService.EnqueueAsync（output_type 引数は①で削除）。
→ ①②③⑤⑥ は print-platform（完了済み）を再オープン。実 DB は t_print_queue から output_type 列 DROP が必要。

## 本日の完了作業（最小単位・順に）

### 1. print-platform requirements 改訂 完了（外科的・診断クリア）
- Glossary: PrintStatus を 1/2/3/9（0=対象外 削除）。`m_printer` 追加。`printer_name`(NULL→既定) 追加。
- R1: AC2 列一覧から output_type 削除・AC4 status 値 1/2/3/9・新AC9「output_type 列を持たない」。
- R4: 新AC7「投入契約に output_type を含めず印刷対象のみ投入（判定は投入側所有）」。
- R5: AC6 を無条件印刷（output_type ゲート撤廃）・新AC8（printer_name NULL→既定）・新AC9（指定プリンタ非存在→status9・印刷試行しない）。
- **新 Requirement 14**（プリンタマスタと起動時自動登録）: m_printer 定義／(machine_name,printer_name) 一意＋is_default/is_active/last_seen_at／起動時 upsert／既定 is_default=1／存在チェックの基礎／機区別。番号衝突回避のため末尾追加。

### 2. print-platform design 改訂 完了（外科的・診断クリア）
- D7（output_type 廃止・投入側ゲート）・D8（プリンタ解決/存在チェック/マスタ）追加。
- Architecture ステータス対比表から 0対象外 削除。
- EnqueueAsync シグネチャから `int outputType` 削除（新: module/reportType/referenceCode/pdfPath/printerName/copies/ct）。投入時振る舞いから output_type 除去。実装同期注記に「output_type 撤去は tasks で是正＝未是正(PENDING)」を明記。
- PrintAgent Worker: output_type ゲート（shouldPrint）撤廃＝取得ジョブ全印刷。printer 解決（null→既定）＋存在チェック（未インストール→status9・印刷しない）。新サブ節「起動時プリンタ列挙とマスタ登録」（InstalledPrinters・upsert・is_default）。
- Data Models: t_print_queue から output_type 行削除・print_status 備考 1/2/3/9。**新 m_printer 表**（id/machine_name/printer_name/is_default/is_active/last_seen_at/created_at/updated_at/row_version・一意(machine_name,printer_name)・IX(machine_name)）。エンティティ対応表に MPrinter 追加。
- Correctness Properties: Property1 から output_type 除去・Property3 status {1,2,3,9}・Property7 から「0対象外」節削除・**新 Property8（プリンタ解決の決定性）**（Validates 5.8/5.9/14.5・マスタ upsert は統合）。
- Error Handling: printer 未インストール→status9 行追加。実装最小単位に MPrinter/m_printer DDL/起動時列挙 upsert/存在チェック/EnqueueAsync 引数削除＋output_type 撤去 を追加。

### コミット
- print-platform requirements・design 改訂（Nonaka/.kiro）。

## 次アクション（最小単位・1つずつ）
### 3. print-platform tasks 改訂（次にやる）
- output_type 撤去タスク群（TPrintQueue プロパティ削除・PrintQueueService/IPrintQueueService 引数削除・create_t_print_queue.sql 列 DROP or 新DDL・Common_PrintMonitor 参照確認）。
- m_printer: CommonModule MPrinter entity+DbSet・DDL・テーブル定義書/ER図。
- PrintAgent: 起動時プリンタ列挙→m_printer upsert サービス・printer 存在チェック（status9）・output_type ゲート撤廃・TPrintQueue から output_type 削除・接続は既に db_common_dev。
- Property 一覧 1〜8（8=プリンタ解決）反映。実DBは output_type 列 DROP（ユーザー）。

### 4. dispatch-monitoring-consolidation requirements/design/tasks 追随
- 投入を output_type∈{1,3} に限定（PrintJobService でフィルタ）・EnqueueAsync 呼び出しから outputType 除去。
- 既存 3.2 実装（現状 outputType 引数渡し・全グループ投入）を是正するタスク追加。

### 5. 実装（合意後・最小単位・1つずつ）
- CommonModule（EnqueueAsync 引数削除・TPrintQueue・MPrinter・DDL）→ PrintAgent（列挙 upsert・存在チェック・ゲート撤廃）→ MaterialModule（投入フィルタ・呼び出し是正）。

## 運用ルール（厳守・再掲）
- 1ターン=1タスクで区切る。パスは小文字 `ojiadm23120073`。MainWeb・SharedCore・AuthModule 変更不可。
- spec 単一正本 `.kiro/specs/{Module}/{feature}/`。ビルド・テスト・DDL適用・実印刷はユーザー側。
- MaterialModule は clnCoCore 外の独立 git（toplevel=`Nonaka/MaterialModule`）。PrintAgent も別 git（`Labs/WindowsService/PrintAgent`）。CommonModule は clnCoCore 内。
- task_update ツールは不安定 → tasks.md チェックボックス直接編集を正とする。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260703）。

---

## レビュー確定＋2 spec の spec更新 完了（実装前フェーズ完了）

### ユーザー決定（全確定）
1. output_type=MaterialModule送信パラメータ（0=保存のみ/1=印刷/2=FAX/3=両方）。t_print_queue は持たない。印刷投入ゲート={1,3}。
2. プリンタ存在チェックは**実列挙が正**、m_printer は台帳。is_default/is_active 必須。
3. 消えたプリンタは起動時 is_active=0（当該機のみ・他機不変）。
4. m_printer に row_version 付与（将来のWeb編集の楽観ロック）。
5. EnqueueAsync 破壊的変更（outputType 引数削除）承認。

### print-platform（CommonModule）spec 更新 完了・コミット
- requirements: R1.9(output_type列なし)・R4.7(投入契約output_typeなし)・R5.6(全印刷)・R5.8/5.9(プリンタ解決/存在チェック=実列挙)・**R14(m_printer+起動時upsert+is_active自動無効化+row_version)**。PrintStatus 1/2/3/9。
- design: D7(output_type廃止)・D8(プリンタ解決/存在チェック/マスタ・実列挙が正)・EnqueueAsync から outputType 削除・m_printer テーブル定義・Property8(プリンタ解決の決定性)・実装同期注記(output_type撤去=tasksで是正)。
- tasks: **新タスク群12**（12.1-12.5 output_type撤去／12.6-12.8 m_printer entity/DDL/docs／12.9-12.13 PrintAgent(output_type削除・ゲート撤去・プリンタ解決/存在チェック・MPrinter・起動時upsert)／12.14-12.16 テスト）。wave11-14 追加。
- コミット: Nonaka `49ad7fb`(req/design初版)・`0a57b7d`(レビュー反映)・`e5ecfbc`(tasks群12)。

### dispatch-monitoring-consolidation（MaterialModule）spec 更新 完了・コミット
- requirements: Glossary OutputType 全意味づけ・PrintStatus 1/2/3/9。R4 に投入ゲート{1,3}・EnqueueAsync output_type非送出 AC 追加。R8.2 PDF生成保存は全output_type・投入のみ条件付き。
- design: EnqueueAsync signature から outputType 削除・承認フロー mermaid にゲート分岐・PrintJobService改修手順(ゲート/二重生成回避)・**二重生成の回避節**（PrintJobService=OutputType{0,1,3}生成／OutputType=2 は FAX経路担当）・Property2 更新・投入列対応から output_type 削除・Open Decision4。
- tasks: **新タスク群10**（10.1 PrintJobService を OutputType ゲート是正＋EnqueueAsync outputType 削除＋二重生成回避／10.2 二重生成整合確認／10.3* Property2 追随）。wave7-9 追加。既存 3.2 は改定前実装として保持し 10 で是正。
- コミット: Nonaka `ab4bad5`。

## 現状
- **print-platform／dispatch 双方の requirements/design/tasks が新Print仕様で整合・全コミット済み**。実装未着手（spec のみ）。
- ⚠ 既存実装との差分（是正が必要な実コード）:
  - CommonModule: TPrintQueue(output_type削除)・IPrintQueueService/PrintQueueService(outputType引数削除)・create_t_print_queue.sql(output_type列削除+ALTER)・Common_PrintMonitor(参照確認)・新MPrinter entity+DbSet+DDL。
  - PrintAgent: TPrintQueue(output_type削除)・PrintJobWorker(ゲート撤去・プリンタ解決/存在チェック)・MPrinter+DbContext・起動時列挙upsertサービス。
  - MaterialModule: PrintJobService(OutputTypeゲート{1,3}・EnqueueAsync outputType削除・二重生成回避)。
- 実DB: t_print_queue から output_type 列 DROP・m_printer 作成（ユーザー）。

## 次アクション（実装フェーズ・最小単位・1つずつ）
実装順の推奨（依存: CommonからPrintAgent/Material へ）:
1. **CommonModule**: 12.6 MPrinter entity+DbSet → 12.1 TPrintQueue output_type削除 → 12.2 EnqueueAsync outputType削除 → 12.3 DDL(output_type削除+m_printer 12.7) → 12.4 Monitor確認 → 12.5/12.8 docs。※CommonModule.sln ビルド確認（ユーザー）。
2. **MaterialModule**: 10.1 PrintJobService ゲート{1,3}+EnqueueAsync呼び出し是正+二重生成回避 → 10.2 整合。※MaterialModule/slnCoCore ビルド（ユーザー）。※EnqueueAsync シグネチャ変更で呼び出し元が一致するのは Common 側是正後。
3. **PrintAgent**: 12.9 TPrintQueue output_type削除 → 12.10 ゲート撤去 → 12.11 プリンタ解決/存在チェック → 12.12 MPrinter+DbContext → 12.13 起動時列挙upsert。※PrintAgent.sln ビルド（ユーザー）。
4. テスト（任意PBT: Property8・Property2追随・print_status集合更新・m_printer統合）。
- ⚠ ビルド順の注意: EnqueueAsync 引数削除（Common 12.2）と呼び出し元（Material 10.1）は**セットで**ないと slnCoCore がビルド不可（中間状態）。Common→Material を続けて実施し、その後まとめてビルド確認する。

## コミット状況（本日 7/3）
- Nonaka: `49ad7fb`→`0a57b7d`→`e5ecfbc`→`ab4bad5`（print-platform req/design/tasks・dispatch req/design/tasks・memo 20260703 初版）。
- `.config.kiro`（dispatch）は誤って書き換わった specId をコミット版 `b7e4c2a1` に復元済み（git checkout）。

---

## 実装フェーズ：コア実装 完了（3モジュール・全コミット済み）

### CommonModule（別git・toplevel=Nonaka/CommonModule）＝コミット `8f6161a`
- 12.1 TPrintQueue から output_type 削除（＋クラス/プロパティ XMLコメントの 0=対象外 除去）。
- 12.2 IPrintQueueService/PrintQueueService の EnqueueAsync から outputType 引数削除（新シグネチャ: module/reportType/referenceCode/pdfPath/printerName/copies/ct）。
- 12.3 create_t_print_queue.sql から output_type 列削除・CHECK を IN(1,2,3,9)・print_status コメント是正／新規 alter_t_print_queue_drop_output_type.sql（DEFAULT制約動的削除→DROP COLUMN・COL_LENGTH ガード）。
- 12.4 Common_PrintMonitor に output_type 参照なし（確認済み）。
- 12.6 MPrinter エンティティ新規＋CommonDbContext に DbSet<MPrinter> Printers 追加。
- 12.7 create_m_printer.sql 新規（id/machine_name/printer_name/is_default/is_active/last_seen_at/created_at/updated_at/row_version・UQ(machine_name,printer_name)・IX）。
- 診断クリア。CommonModule.sln 単独ビルド可。

### MaterialModule（別git）＝コミット `317c4a5`
- 10.1 PrintJobService.CreateOrderApprovalJobsAsync 是正: OutputType==2 は skip（FAX経路担当・二重生成回避）、PDF生成保存は {0,1,3}、印刷キュー投入ゲート {1,3}、EnqueueAsync から outputType 引数除去。IPrintJobService シグネチャ不変。診断クリア。
- → **CommonModule の EnqueueAsync 契約変更と呼び出し元が一致。slnCoCore ビルド可能**。

### PrintAgent（別git・Labs/WindowsService/PrintAgent）＝コミット `b03c359`
- 12.9 TPrintQueue から output_type 削除。
- 12.10 PrintJobWorker の output_type 印刷可否ゲート（shouldPrint）撤去＝取得ジョブ全印刷。
- 12.11 プリンタ解決（printer_name ?? 既定）＋存在チェック（printer_name 明示指定かつ InstalledPrinters に無ければ status=9・「指定プリンタが存在しません」・印刷試行せず）。IsPrinterInstalled/TruncateError ヘルパ追加。
- 12.12 MPrinter エンティティ＋PrintAgentDbContext DbSet（ToTable("m_printer")）。
- 12.13 PrinterInventoryHostedService（IHostedService・起動時 InstalledPrinters 列挙→m_printer upsert・既定 is_default=1・現存 is_active=1・当該機の今回未列挙は is_active=0 自動無効化・他機不変・scoped DbContext・try/catch）。Program.cs に AddHostedService 登録。
- **PrintAgent.csproj に System.Drawing.Common 8.0.* 追加**（PrinterSettings.InstalledPrinters に必要）。診断クリア（CA1416 Windows専用は許容）。

### Nonaka(.kiro)＝コミット `bc00ac0`・`c0819e1`
- docs/db: テーブル定義書・ER図（t_print_queue output_type削除・print_status 1/2/3/9・m_printer 追記）。
- tasks 進捗: print-platform 12.1-12.13＝[x]、dispatch 10.1＝[x]。

## 残（次回・任意/検証/協調）
- **dispatch 10.2**（要コード確認）: OutputType=3（印刷+FAX）で PrintJobService と DispatchEnqueueService が同一グループ PDF を二重生成・二重保存しないよう整合。現状 10.1 は OutputType=2 を skip するのみで、=3 は両経路が各自生成する（要 DispatchEnqueueService レビュー・保存の一元化）。
- 任意PBT: print-platform 12.14（Property8 プリンタ解決）・12.15（既存 Property1/3/7 の print_status 集合を {1,2,3,9} に更新）・12.16（m_printer upsert/自動無効化 統合）／dispatch 10.3（Property2 追随）。
- 検証CP: print-platform 8/10。

## ユーザー実行（ビルド/DDL/デプロイ）
- **ビルド**: slnCoCore（CommonModule+MaterialModule・EnqueueAsync 契約セット是正済みで通るはず）／PrintAgent.sln（System.Drawing.Common 復元）。
- **DDL（db_common_dev）**: alter_t_print_queue_drop_output_type.sql（既存 t_print_queue の output_type 列 DROP）＋create_m_printer.sql（新規）。※新規環境は create_t_print_queue.sql（output_type 無し版）でよい。
- **PrintAgent 再デプロイ**: 起動時に m_printer へ自機プリンタ登録・印刷は printer_name/既定で実行。SkipPrint=false＋実プリンタ設定で実印刷確認。

## コミット状況（本日 7/3 追加分）
- CommonModule `8f6161a` / MaterialModule `317c4a5` / PrintAgent `b03c359` / Nonaka `bc00ac0`・`c0819e1`。

---

## 🎉 印刷経路 実機・実紙 検証完了（新Print仕様 End-to-End OK）

### ユーザー実行の検証ログ（STEP1-4）
- **STEP1（DDL・db_common_dev）完了**: alter_t_print_queue_drop_output_type.sql（output_type 列 DROP）＋ create_m_printer.sql（新規）適用。
- **STEP2（PrintAgent）**: slnCoCore ビルドOK（ユーザー）。PrintAgent.sln リビルド（System.Drawing.Common 復元）・起動。
- **STEP3 確認OK**:
  - m_printer に自機（machine_name=OJIADM23120069）のプリンタ5件自動登録。既定=OJP-33094（is_default=1）、他 is_active=1（OneNote/OJP-22002/OJP-22001/Microsoft Print to PDF）。起動時列挙 upsert 実機動作確認。
  - /Common/PrintMonitor 死活=「ポーリング中」・最終応答時刻更新（OJIADM23120069）。heartbeat 実機OK。
- **STEP4 確認OK（実紙出力まで）**:
  - 発注承認（output_type=1）→ PDF生成・保存（共有 \\ojiadm23120073\app_share\PrintAgent に実ファイル生成＝MaterialModule 側生成OK）→ t_print_queue 投入（module=material/order_approval/pdf_path・G201-260703-001/002）→ 完了(3) 遷移。
  - 途中経緯（想定内・切り分け成功）:
    1. SkipPrint=true のまま完了3＝ドライラン（紙出ず）→ appsettings 変更は**再起動必須**（_skipPrint/_defaultPrinter は起動時読込の readonly）。
    2. 再起動後 SkipPrint=false で **status=9・error「SumatraPDF.exe が見つかりません: C:\PrintAgent\T...」**＝環境に SumatraPDF 未配置（エラーハンドリング＝FileNotFound→status9・PrintMonitor エラー表示が正しく動作）。
    3. ユーザーが SumatraPDF を C:\PrintAgent\Tools\SumatraPDF.exe に配置 → 再出力 → **実紙出力 OK**。
  - PrintAgent appsettings（OJIADM23120069）: CloudDb=db_common_dev / TempPdfDirectory=\\OJIADM23120073\app_share\PrintAgent / SumatraPdfPath=C:\PrintAgent\Tools\SumatraPDF.exe / DefaultPrinterName=OJP-33094 / SkipPrint=false。

### 検証済み事項（実機）
- MaterialModule: 承認→PDF生成・保存→IPrintQueueService 投入（output_type ゲート・EnqueueAsync 新シグネチャ）実機OK。
- CommonModule: t_print_queue（output_type 無し）投入・PrintMonitor 表示・死活。
- PrintAgent: t_print_queue 全印刷（ゲート撤去）・プリンタ解決（printer_name null→既定 OJP-33094）・SumatraPDF サイレント印刷・m_printer 起動時 upsert・エラー時 status9。
- ⇒ **print-platform＋dispatch の印刷経路（output_type=1）は実データ・実紙で完全動作**。

### 残（印刷基本経路には不要・任意/協調/別案件）
- dispatch 10.2（output_type=3 の二重生成回避・DispatchEnqueueService 協調）＝印刷+FAX 同時時の最適化。output_type=1 印刷には影響なし。
- 任意PBT: print-platform 12.14（Property8）/12.15（print_status 集合更新）/12.16（m_printer 統合）、dispatch 10.3（Property2 追随）。CP 8/10。
- SmtpAgent FAXテスト送信（未実装案件 I-3・発注書テスト段階で着手）。
- プリンタ選択UI・既定変更などの m_printer 管理画面（将来・スコープ外）。

### 運用メモ（重要）
- PrintAgent の appsettings（SkipPrint/DefaultPrinterName/SumatraPdfPath）変更は**再起動で反映**（起動時一度読込）。
- printer_name 未指定ジョブは config の DefaultPrinterName にフォールバック（OS既定ではなく設定値）。実プリンタ名と完全一致必須。
- SumatraPDF は各 PrintAgent 稼働機に配置が前提（C:\PrintAgent\Tools\SumatraPDF.exe）。

### コミット状況（本日 7/3・変更なし＝実装は既コミット済み）
- 実装コミット: CommonModule `8f6161a` / MaterialModule `317c4a5` / PrintAgent `b03c359` / Nonaka `bc00ac0`・`c0819e1`・`a27f099`・`4cb8b19`。今回の検証はユーザー環境作業（コード変更なし）。

---

## dispatch 10.2 完了（二重生成回避・PDF生成保存の一元化）

- **新規 scoped `IApprovalReportPdfProvider`/`ApprovalReportPdfProvider`**（MaterialModule/Services）: `GetOrCreateOrderApprovalPdfAsync(groupKey)` が生成(OrderPdfService)→保存(IPrintOutputPathService 由来ベースパス)→フルパス返却。**スコープ内 `Dictionary<groupKey,fullPath>` キャッシュ**で groupKey ごと1回だけ生成・保存。`BuildPdfFileName` は本プロバイダが所有。DI: `AddScoped`（AddMaterialModule）。
- **PrintJobService**: 生成・保存ブロックをプロバイダ呼び出しに置換（IOrderPdfService/IPrintOutputPathService 注入を除去）。OutputType ゲート（2=skip、{1,3}=投入）は不変。`BuildPdfFileName` 除去、`ExtractGroupKey` 維持。
- **DispatchEnqueueService**: 生成・保存ブロック（`_options.PdfShareRoot` 保存）をプロバイダ呼び出しに置換（IOrderPdfService 注入除去・`BuildPdfFileName` 除去）。他 FAX ロジック（ShouldDispatchFax/dedup/宛先/件名本文/test-send/dispatch log）不変。`_options` は ConfigKey/FromAddress/TestSend* で継続使用（PdfShareRoot 参照のみ消失・プロパティは残置）。
- **不変条件達成**: ApprovalService が PrintJobService→DispatchEnqueueService を同一スコープで順に呼ぶため、OutputType=3 は PrintJobService が生成・キャッシュ→FAX 経路が同一パス再利用（単一生成）。=2 は FAX 側が初回生成。=0/1 は印刷側のみ。保存先の単一真実源＝m_print_output_path ベースパス。
- 診断クリア。公開シグネチャ（IPrintJobService/IDispatchEnqueueService）不変。tasks 10.2＝[x]。
- コミット: MaterialModule `b68dc1c`。
- ⚠ FAX PDF の保存が `FaxDispatchOptions.PdfShareRoot` → マスタ由来ベースパスに一元化（現行値一致・SmtpAgent は渡された pdf_path を読むため無影響）。ファイル名も `order_...` → `order_approval_...` に統一。ユーザーは slnCoCore 再ビルドで確認。

### dispatch 残
- 10.3*（Property2 追随テスト・任意）。
- print-platform 任意PBT 12.14-12.16・CP 8/10。
- SmtpAgent FAXテスト送信（未実装案件 I-3）。

---

## DB 重複テーブル整理＋旧・孤立テーブル DROP（案件 J-1 完了）

### 経緯
- 「db_material_dev と db_common_dev に同名テーブルが併存して混乱」との指摘を受け整理。
- 調査: 現行コードは全て db_common_dev（新）側を参照。旧 db_material_dev コピーは孤立。
  - SmtpAgent 接続先＝**db_common_dev**（`SmtpAgent/appsettings.json` CloudDb で確認）。
  - PrintAgent 接続先＝**db_common_dev**（稼働確認済）。
  - MaterialModule に旧テーブルの DbSet/ToTable 参照なし（grep 0件）。Material_SmtpMonitor/PrintMonitor ページも既に存在せず。
- 孤立3テーブル（db_material_dev の `m_smtp_config`／`m_smtp_agent_control`／`m_print_agent_control`）は安全に DROP 可能と判断。

### 実施
1. **DROP スクリプト作成**: `MaterialModule/docs/sql/drop_legacy_orphan_tables_db_material_dev.sql`（存在ガード付き・3テーブル DROP・t_order_reports は対象外・実行はユーザー）。コミット MaterialModule `78a8c26`。
2. **ユーザーが db_material_dev で DROP 実施済み**（3テーブル削除）。
3. **ドキュメント整合（DROP後の状態に一致）**:
   - `.kiro/docs/db/テーブル定義書.md`: マスタ一覧 23→**20**（旧3行削除）・旧3テーブルの詳細節を削除・db_common_dev 節の注記2箇所を「DROP済み」に更新・「重複テーブルの整理」節を DROP実施済に更新（退役状況）。
   - `.kiro/docs/db/ER図.md`: 資材マスタ分類 23→**20**（旧3行削除・DROP済み注記追加）。db_common_dev 節（新テーブル）は現存として維持。
   - `.kiro/docs/未実装案件一覧.md`: 案件 J（DB重複テーブル退役）追加。J-1 は最終確認済＋DROP実施済で完了、J-2（t_order_reports・保全後）は継続。
- 診断クリア（テーブル定義書・ER図）。

### 現存整理（DROP後）
- **同名テーブルは db_common_dev（共通基盤）側のみ**: `t_smtp_queue`/`m_smtp_config`(複数行)/`m_smtp_agent_control`/`t_print_queue`/`m_print_agent_control`/`m_printer`。
- db_material_dev 現行: 資材業務テーブル一式＋`m_print_output_path`＋`t_order_dispatch_log`＋`t_order_reports`（履歴保全・案件 J-2）。

### 残（次回）
- J-2: `t_order_reports` 退役（保全期間後・ユーザー判断）。
- 任意PBT: print-platform 12.14-12.16 / dispatch 10.3。CP 8/10。
- SmtpAgent FAXテスト送信（I-3・発注書テスト段階）。

### コミット
- MaterialModule `78a8c26`（DROP SQL）。Nonaka: `6fa7241`（整理記録初版）・`190df9d`（J-1確認反映）・本コミット（DROP後ドキュメント整合・memo）。
