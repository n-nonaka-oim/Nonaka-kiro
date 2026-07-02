# セッション備忘録（2026/07/02 - print-platform 設計改訂：PrintAgent 印刷専用化・PDF一本・print_payload 廃止）

前セッション（20260701）からの継続。print-platform 実装 17/37（Web側1〜4・PrintAgent 6）まで完了後、設計の根本訂正が入ったため design→requirements を改訂中。

## セッション開始時の状態（20260701 末尾より）
- print-platform 実装 17/37 完了（タスク1〜4＝CommonModule/Web側、6＝PrintAgent エンティティ/DbContext/接続先）。
- コミット済み: CommonModule `88473b3`（4.6/4.8）・Nonaka `9ae68e9`。
- 未コミット: PrintAgent（6.1 TPrintQueue.cs 追加・6.2 DbContext・6.3 appsettings）・Nonaka/.kiro（tasks 進捗・memo）。
- ⚠ PrintAgent は 6.2 で `db.OrderReports` 参照が壊れ、7.1 までビルド不可（想定どおり）。
- 環境確認済み: db_common_dev 実在（SmtpAgent が既に使用）。db_material_dev は material オリジナルとして不変。PrintAgent/SmtpAgent はワークスペース内（小文字パス `ojiadm23120073` で編集可）。

## 🔴 設計の根本訂正（ユーザー確定・本日の主題）
**PrintAgent は「受け取った PDF をサイレント印刷するだけ」。印刷イメージ（PDF）の生成は送信側（投入側）の責務。**
現行 design のデュアルモード（D6＝pdf_path 無ければ payload から PrintAgent が生成）は誤り → **PDF一本（pdf_path 必須・payload 生成経路なし）**へ是正。

### ユーザー3決定
1. design を上記 To-Be へ改訂 = **OK**
2. PDF 生成の担い手 = **a) MaterialModule 側で生成して pdf_path を渡す**
3. `print_payload` = **完全廃止**

## 本日の完了作業（最小単位・順に委譲）

### 1. design.md 改訂 完了（単一正本・診断クリア）
- D6 を「印刷専用・単一パス」に全面改訂（payload 生成分岐撤廃・PrintAgent は pdf_path をサイレント印刷のみ）。D1/D4 追随。
- `print_payload` 列 廃止／`pdf_path` NOT NULL 必須化（Data Models 表・DDL 記述・スモーク）。
- `IPrintQueueService` から `printPayload` 引数削除・`pdfPath` 必須／`PrintQueueService` 検証を pdf_path 必須へ。
- Worker 取得条件「print_status=1 かつ pdf_path IS NOT NULL」／`PdfGeneratorService`・`Documents/*.cs` は PrintAgent から退役（→MaterialModule 所有）。
- Property 8（出力ソース選択）廃止・Property 2 を pdf_path 必須に・Property 1/3 の payload 参照除去（Property 1〜7＝PBT、9＝統合）。
- Error Handling／カットオーバー（残ジョブは pdf_path 必須）／責務分界（PDF生成は MaterialModule/dispatch 所有）追随。
- 「実装同期の注記」を design 内に明記：実装済み CommonModule（entity print_payload・service 検証・DDL・監視再出力条件）は tasks で是正。

### 2. requirements.md 追随更新 完了（単一正本・診断クリア）
- Glossary: `PrintPayload` 廃止→`pdf_path`（必須・唯一の印刷ソース）。PrintAgent=印刷専用。host 小文字化。
- R1: 列一覧に module/pdf_path/printer_name、print_payload 削除。AC5=pdf_path 必須(NOT NULL・唯一の印刷ソース)、新AC6=print_payload 列を持たない。
- R4: AC2=pdf_path 非空必須（payload 代替削除）、新AC4=送信側PDF生成が前提・キューは生成済みPDFパス受領。
- R5: AC3 取得条件「print_status=1 かつ pdf_path 非空」、AC5 に pdf_path 不存在、AC6 単一印刷パス（生成しない）。
- R9.5: 再出力可否を pdf_path 基準。R11.2: 残ジョブ移行に pdf_path 付与。R13: AC3 印刷専用化所有・新AC6 PDF生成非所有。
- 既存詳細化済みのため全要件の再詳細化はしない（外科的修正）。

## 次アクション（最小単位・1つずつ）
### 3. tasks.md 追随更新（次にやる）
- 7.1 を「pdf_path をサイレント印刷のみ」に簡素化。7.2（Property 8 出力ソース選択）削除。
- **CommonModule 是正タスク追加**: `TPrintQueue` から print_payload 削除／`PrintQueueService` pdf_path 必須・`IPrintQueueService` シグネチャ（printPayload 削除・pdfPath 必須）／`create_t_print_queue.sql`（print_payload 削除・pdf_path NOT NULL）／`Common_PrintMonitor` 再出力条件 pdf_path。
- PrintAgent 12（7.1 相当）: `PdfGeneratorService`/`Documents/*.cs` 退役の扱い（削除 or 保留）を明記。9.1 移行SQL pdf_path 必須。
- Property 一覧 1〜7＝PBT・9＝統合（8 廃止）を反映。

### 4. 実装是正（CommonModule）
- `TPrintQueue` から print_payload プロパティ削除／`PrintQueueService`・`IPrintQueueService`／`create_t_print_queue.sql`／`Common_PrintMonitor` 再出力条件。

### 5. PrintAgent 7.1（印刷専用）
- `PrintJobWorker` を pdf_path サイレント印刷のみに。PrintAgent 側 `TPrintQueue`（6.1作成）は print_payload 未実装なので確認のみ。PdfGeneratorService/Documents 退役の実施可否を判断。これで PrintAgent 再ビルド可能に。

## 未コミット（次回コミット対象）
- PrintAgent（別git・6.1/6.2/6.3）: `Models/TPrintQueue.cs`（新規）・`Data/PrintAgentDbContext.cs`・`appsettings.json`。
- Nonaka/.kiro: `design.md` 改訂・`requirements.md` 改訂・`tasks.md`(6.x [x])・session-memo（20260701 末尾＋本 20260702）。

## 運用ルール（厳守・再掲）
- 1ターン=1タスクで区切る。パスは小文字 `ojiadm23120073`（大文字は範囲外誤判定）。
- MainWeb・SharedCore・AuthModule 変更不可。spec 単一正本 `.kiro/specs/{Module}/{feature}/`。
- ビルド・テスト・DDL適用・実印刷・PrintAgent 再デプロイはユーザー側。
- `task_update` ツールが使用不可のことがある → tasks.md チェックボックスを正として継続。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260702）。

---

## tasks.md 追随更新 完了（印刷専用・Property8廃止・是正タスク11追加）

- Overview/Notes: デュアルモード→印刷専用、Property 1〜8→1〜7（＋9統合）。host小文字化。
- 7.1 を「pdf_path サイレント印刷のみ（PdfGeneratorService/IPdfGeneratorService/Documents は PrintAgent から退役）」に書き換え。**7.2（Property 8）削除**。
- 完了済みタスクの記述是正（[x]維持）: 1.1（print_payload 列削除・pdf_path NOT NULL）／3.1（pdf_path 必須・printPayload 引数なし）／4.6（再出力条件 pdf_path）。3.3/4.7（Property 2/3）を pdf_path 基準に。
- **新タスク群 11 追加（CommonModule 実装是正・未着手）**:
  - 11.1 TPrintQueue.cs から print_payload 削除
  - 11.2 IPrintQueueService/PrintQueueService を pdf_path 必須へ（printPayload 引数削除）
  - 11.3 create_t_print_queue.sql から print_payload 削除・pdf_path NOT NULL
  - 11.4 Common_PrintMonitor OnPostReprintAsync 再出力条件 pdf_path 基準へ
  - 11.5 テーブル定義書・ER図 追随
- 9.1 移行SQL: pdf_path 必須（送信側生成 pdf_path 付与・用意不可は対象外）。print_payload 移行しない。
- 依存グラフ: 7.2 除去、wave6 に 11.1〜11.5、以降のwave繰り下げ（0〜10）。診断クリア。
- 軽微な残: チェックポイント 8「Property 7〜9」・10「Property 1〜9」は Property 8 廃止後も範囲表記のまま（許容・実害なし）。

### 進捗・次
- design ✅／requirements ✅／tasks ✅ 改訂完了。実装是正フェーズへ。
- **次の最小単位（1ファイルずつ）**: 11.1 → 11.2 → 11.3 → 11.4 → 11.5（CommonModule 是正）→ その後 PrintAgent 7.1（印刷専用）。
- CommonModule 是正（11.x）で PrintQueueService/IPrintQueueService/entity/DDL/監視を pdf_path 一本化 → CommonModule ビルド確認（ユーザー）。
- ⚠ PrintAgent は 7.1 まで依然ビルド不可。
- 未コミット: PrintAgent（6.x）・Nonaka/.kiro（design/requirements/tasks 改訂・memo）。

---

## CommonModule 実装是正 11.1〜11.4 完了（print_payload 排除・pdf_path 一本化）

- **11.1** `CommonModule/Data/Entities/TPrintQueue.cs`: `PrintPayload` プロパティ削除・`PdfPath` を [Required] 非nullable(string=empty) に。クラス概要を印刷専用に。診断クリア。
- **11.2** `IPrintQueueService`/`PrintQueueService`: `EnqueueAsync` から `printPayload` 引数削除・`pdfPath` 必須（RequireNonBlank 追加）・初期化子から PrintPayload 除去。診断クリア。CommonModule の entity↔service 不整合解消。
- **11.3** `CommonModule/docs/sql/create_t_print_queue.sql`: `print_payload` 列削除・`pdf_path` NOT NULL・ヘッダを印刷専用に。
- **11.4** `Common_PrintMonitor/Index.cshtml.cs` `OnPostReprintAsync`: 再出力条件を pdf_path 基準へ（payload 参照除去）・XMLドコメント是正。診断クリア。
- → CommonModule コードは print_payload を完全排除。**CommonModule.sln はビルド可能な状態**（ユーザー確認可）。tasks 11.1〜11.4 = [x]。

### 残・次
- **11.5**（ドキュメント）: `.kiro/docs/db/テーブル定義書.md`・`ER図.md` の t_print_queue から print_payload 削除・pdf_path NOT NULL に追随。
- その後 **PrintAgent 7.1**（印刷専用）: `PrintJobWorker` を pdf_path サイレント印刷のみに。PrintAgent 側 TPrintQueue（6.1）は print_payload 未実装のため確認のみ。PdfGeneratorService/Documents 退役の実施可否を判断。→ これで PrintAgent 再ビルド可能。
- 未コミット: CommonModule（11.1〜11.4）・PrintAgent（6.x）・Nonaka/.kiro（spec 3点改訂・tasks 進捗・memo）。

---

## 11.5 完了（親11完了）＋ MainWeb 依存関係はユーザー所有に確定

### MainWeb 登録の実態（判明）
- `MainWeb/Configuration/ModuleRegistration.cs`（gitignore対象・実行時）は既に `AddCommonModule(configuration)` を呼ぶ（using CommonModule.Extensions）。
- ただし **`MainWeb.csproj` に CommonModule の ProjectReference 無し**（DemoModule/MaterialModule/AuthModule/SharedCore/SharedInfrastructure のみ）。**`slnCoCore.sln` にも CommonModule 未登録** → **slnCoCore ではビルド不可**（CommonModule.sln 単独ビルドのみ可）状態。
- grep で clnCoCore に CommonModule ヒット無し＝ModuleRegistration.cs は gitignore のため検索外・MainWeb.csproj は実際に未参照。

### 決定（ユーザー）
- **slnCoCore への CommonModule 追加・MainWeb 依存関係構築はユーザーが実施**（MainWeb/clnCoCore は変更不可・こちらは触らない）。その後にビルド確認。
- 私（Kiro）は MainWeb/clnCoCore を変更しない。CommonModule 側成果物のみ担当。

### 11.5 完了（ドキュメント追随）
- `.kiro/docs/db/テーブル定義書.md` t_print_queue（db_common_dev）節: 説明を印刷専用に、`print_payload` 行削除、`pdf_path` を必須(○)・唯一の印刷ソースに。旧 t_order_reports（db_material_dev・line702付近・fax_status/print_payload 有）は保全で不変。
- `.kiro/docs/db/ER図.md`: リレーション備考の「デュアルモード」→「印刷専用・単一パス」。mermaid は元々 print_payload 非掲載で対応不要。
- 親タスク **11 完了**（11.1〜11.5）。tasks 進捗更新。

### 現状と次
- **CommonModule 側は print_payload 完全排除・pdf_path 一本化 完了**（entity/service/DDL/監視/ドキュメント）。CommonModule.sln 単独はビルド可。
- ⏸ ユーザー作業待ち: slnCoCore に CommonModule 追加＋MainWeb.csproj 参照＋（必要なら ModuleRegistration.cs.template 反映）→ slnCoCore ビルド確認。
- その後の次アクション: **PrintAgent 7.1（印刷専用ワーカー）**。`PrintJobWorker` を pdf_path サイレント印刷のみに（PdfGeneratorService/Documents 退役の可否も判断）。→ PrintAgent 再ビルド可能に。
- 未コミット: CommonModule（11.1〜11.4）・Nonaka/.kiro（spec 3点改訂・tasks・docs/db・memo）・PrintAgent（6.x）。

---

## MainWeb 依存関係登録（ユーザー明示許可のもと実施）

- ユーザーが MainWeb 依存関係登録を一時解除 → 指示により **`MainWeb.csproj` に `<ProjectReference Include="..\..\CommonModule\CommonModule.csproj" />` を追加**（MaterialModule と同じ相対形・変更不可の例外＝ユーザー明示許可）。
- 既存: `ModuleRegistration.cs`（gitignore・実行時）は `AddCommonModule(configuration)` を既に呼ぶ。今回の ProjectReference 追加で解決可能に。
- slnCoCore.sln への CommonModule プロジェクト追加はユーザー実施（IDE可視化用。ビルドは csproj 参照で транзитивに通る）。
- パス整合確認: CommonModule → SharedCore = `..\clnCoCore\SharedCore\SharedCore.csproj`（OK）。
- ⏳ 次: ユーザーが **slnCoCore ビルド確認**。通れば print_payload 廃止後の CommonModule 含め CoCore 全体OK。
- 注意: この MainWeb.csproj 変更はユーザー所有領域（clnCoCore）。コミット/管理はユーザー側。

---

## slnCoCore ビルド：CommonModule/MainWeb は成功、PrintAgent OrderReports エラー→7.1で解消

### ビルド結果分析
- **ハードエラーは1件のみ**: `PrintAgentDbContext に OrderReports の定義が無い`（PrintJobWorker 旧参照＝想定内の中間状態）。
- CommonModule の print_payload 廃止・MainWeb への CommonModule ProjectReference 追加は**エラー0**（成功）。
- 他は既存警告のみ（CA1416 EventLog=Windows専用／未使用パラメータ prefService・masterService・receivingService／nullable）。ビルドを止めない。

### 7.1 完了（PrintAgent 印刷専用ワーカー）
- `PrintJobWorker.cs`: `db.OrderReports`→`db.PrintQueue`、取得条件 `print_status=1`（pdf_path は NOT NULL 必須）。JSON payload デシリアライズ・`PdfGeneratorService.GeneratePdf` 呼び出し・`PrintPayloadDto` 使用を除去。`job.PdfPath` を直接 `SilentPrintService.PrintPdf` でサイレント印刷。`File.Exists` ガード→無ければ status9。完了 `PrintStatus=3・PrintedAt=UtcNow`（CompletedAt/PrintAt 廃止）。失敗 status9・error_message(500)。row_version 楽観ロックの skip 維持。heartbeat 不変。コンストラクタから `IPdfGeneratorService` 引数を除去。
- **追加是正（重要）**: PrintAgent 側 `Models/TPrintQueue.cs` から `PrintPayload` プロパティ削除・`PdfPath` を [Required] 非nullable に（6.1 では print_payload 込みで作成していた）。→ t_print_queue に print_payload 列が無いため、放置すると EF が存在しない列を SELECT して実行時エラーになるのを防止。ワーカー取得条件の `r.PdfPath != null`（常真警告）も除去。
- PrintAgent 2ファイル診断クリア。tasks 7.1 = [x]。

### 残・注意
- `PdfGeneratorService`/`IPdfGeneratorService`/`Documents/*.cs` は**未削除（退役は別クリーンアップ）**。Program.cs の IPdfGeneratorService 登録も残置（無害）。→ 後続クリーンアップ候補。
- PrintAgent 側 `TOrderReport.cs` も未削除（6.2 で DbSet 差替え済み・現在未参照）。→ クリーンアップ候補。
- 次: ユーザーが **slnCoCore 再ビルド**（PrintAgent は別sln＝PrintAgent.sln のビルド）でエラー解消を確認。db_common_dev に DDL（t_print_queue/m_print_agent_control）適用が実行前提。
- 残タスク: 5(CP)・8(CP)・9.1/9.2(カットオーバー)・10(最終CP)・任意PBT(3.2/3.3/4.2/4.3/4.5/4.7/7.3/7.5)。PrintAgent クリーンアップ（PdfGenerator/Documents/TOrderReport 退役）。
- 未コミット: CommonModule(11.x)・MainWeb.csproj(参照追加・ユーザー領域)・PrintAgent(6.x/7.1)・Nonaka/.kiro(spec/tasks/docs/memo)。

---

## PrintAgent ビルド OK ＋ slnCoCore 構成方針（ユーザー確定）

- **PrintAgent（PrintAgent.sln）ビルド OK**（7.1・TPrintQueue是正後）。CommonModule/MainWeb（slnCoCore）もエラー0で成功済み。
- **方針確定**: PrintAgent・SmtpAgent は Web認証基盤を持たない Worker モジュールのため、**slnCoCore ソリューションからプロジェクト除外**（各 .sln でビルド・デプロイ）。＝system-architecture.md の「Worker は別ソリューション」と整合。slnCoCore に含めるのは Web 系（MainWeb/AuthModule/SharedCore/SharedInfrastructure/各モジュール）。CommonModule は MainWeb にホストされる Web モジュールなので slnCoCore 対象。
- この除外操作はユーザーが実施（clnCoCore/sln 領域）。

### print-platform 実装 現況（コア完了）
- Web側: 1〜4 完了＋是正11完了（print_payload 全廃・pdf_path 一本化）。MainWeb に CommonModule 登録済み（ユーザー許可）。
- PrintAgent側: 6.x（entity/DbContext/接続先）＋7.1（印刷専用）＋TPrintQueue是正 完了。ビルドOK。
- ビルド通過（CommonModule/MainWeb/PrintAgent）。

### 次アクション候補（最小単位・1つずつ）
1. **区切りコミット推奨**（安定点）: CommonModule(11.x)・PrintAgent(6.x/7.1)・Nonaka/.kiro（spec/tasks/docs/memo）。MainWeb.csproj はユーザー領域（ユーザーコミット）。
2. 9.1 未処理印刷データ移行SQL（`CommonModule/docs/sql`・ワークスペース内で可）。
3. PrintAgent クリーンアップ（PdfGeneratorService/IPdfGeneratorService/Documents/TOrderReport 退役・Program.cs 整理）＝別小タスク。
4. 任意PBT（3.2/3.3/4.2/4.3/4.5/4.7/7.3/7.5）・CP 5/8/10。
- 実行時前提: db_common_dev に DDL 適用（t_print_queue/m_print_agent_control）。

---

## 9.1 完了（残ジョブ移行SQL・pdf_path必須反映）

- 作成: `CommonModule/docs/sql/migrate_t_order_reports_to_t_print_queue.sql`（診断クリア）。
- pdf_path 必須の最重要注記: 旧 t_order_reports に pdf_path 無し・payload生成退役 → `#pdf_path_map`(reference_code[+report_type]→pdf_path) を INNER JOIN で供給、供給不可行は自動除外（ダミーパス禁止）。
- マッピング: module=N'material' 固定／printed_at=COALESCE(completed_at,print_at)／fax_status・print_payload 非移行／id・row_version 自動。print_status=2 は既定 1 リセット or 除外の両案。取り残しゼロ照合(eligible/out-of-scope/inserted)＋TX＋ロールバック(module/created_at窓口)。
- 留意（テンプレ軽微）: ロールバック(Y) created_at 窓口は移行行が元 created_at を引き継ぐためズレる → 並行投入時は (X) module マーカ推奨 or 移行目印を別途。SELECT確認後DELETE前提で実害限定。
- tasks 9.1 = [x]。ユーザーが pdf_path 対応表を確定して db_common_dev で実行。

### 残（次回候補）
- 9.2 Spec 最終整合確認（単一正本・requirements/design/tasks 整合）。
- PrintAgent クリーンアップ（PdfGeneratorService/IPdfGeneratorService/Documents/*.cs・旧 TOrderReport.cs 退役・Program.cs 整理）。
- CP 5/8/10・任意PBT。
- 実行時前提: db_common_dev に DDL（t_print_queue/m_print_agent_control）適用。
- 未コミット: CommonModule(9.1 SQL)・Nonaka/.kiro(tasks 9.1・memo)。

---

## 9.2 完了（Spec 最終整合確認）＋SQL実行タイミング整理／親9完了

### SQL 実行タイミング（ユーザー質問への回答）
- **DDL 2本（create_t_print_queue.sql / create_m_print_agent_control.sql）= 今すぐ実行可**（db_common_dev・非破壊）。CommonModule 監視画面・PrintAgent の疎通確認の前提。
- **移行SQL（migrate_...）= カットオーバー時（今はまだ）**。③投入先切替は dispatch-monitoring-consolidation 所有で未実装。かつ残ジョブの pdf_path は MaterialModule の PDF 生成が実装されて初めて用意可能。今流すと in-scope 0件。

### 9.2 完了
- spec 3ファイル（requirements/design/tasks）整合確認。print_payload/デュアルモード/Property8 の残存は全て「廃止・持たない」記述 or 履歴注記のみ（有効残存なし）。
- design「実装同期の注記」を未来形→**完了形（tasks 11 で是正済み・現行実装と一致）**に更新。
- tasks 9.2＝[x]、親9＝[x]。

### print-platform 残（全て任意 or 検証 or 実行系）
- 任意PBT: 3.2/3.3/4.2/4.3/4.5/4.7（CommonModule.Tests）・7.3/7.5。
- 検証CP: 5（CommonModuleテスト）・8（PrintAgent/統合）・10（最終）。
- 7.4 heartbeat（既存維持で実質OK・未チェック）。
- PrintAgent クリーンアップ（PdfGeneratorService/IPdfGeneratorService/Documents/*.cs・旧 TOrderReport.cs 退役・Program.cs 整理）＝別小タスク（死コード）。
- 実行系（ユーザー）: DDL 適用・実印刷・カットオーバー（dispatch-monitoring-consolidation 前提）。

### 未コミット
- CommonModule（9.1 SQL）・Nonaka/.kiro（tasks 9.1/9.2・design 注記・memo）。

---

## 関連ドキュメント反映（印刷専用化）：横断構成書・CommonModule README 更新

- `.kiro/docs/system-architecture.md`:
  - 構成図の PrintAgent ラベルを「印刷専用・pdf_path をサイレント印刷」に。
  - コンポーネント表 PrintAgent 行を「印刷専用（投入側生成 pdf_path を印刷・PDF生成しない）」に。
  - 組込セクションに **ソリューション構成**注記追加：slnCoCore は Web ホスト対象（MainWeb/Auth/SharedCore/SharedInfrastructure/Material/**CommonModule**）を含み、**PrintAgent・SmtpAgent は Worker のため slnCoCore 除外**（各 .sln）。CommonModule は MainWeb.csproj から参照し slnCoCore 対象。
- `CommonModule/docs/README.md`:
  - sql/ の内訳を SMTP群／Print群（create_t_print_queue[印刷専用・pdf_path NOT NULL・print_payload無]／create_m_print_agent_control／migrate_...）に整理。
  - 旧「コピーを docs/specs に置く」記述を単一正本（コピー廃止）に是正。

### 残（関連ドキュメント反映の続き・別小単位）
- **PrintAgent/docs 一式の更新**（`requirements.md`/`design.md`/`tasks.md`/`spec.md`／`direct-print/`）：旧 payload 生成方式 → 印刷専用（t_print_queue＠db_common_dev 読取・pdf_path サイレント印刷・PdfGenerator/Documents 退役）。やや大きめのため分割して実施予定。
- 未コミット: CommonModule（9.1 SQL・README）・Nonaka/.kiro（tasks 9.x・design 注記・system-architecture・memo）。

---

## PrintAgent/docs 印刷専用化 反映（改訂ノート方式）

- 方針: 全面書き換えではなく、各 core ドキュメント冒頭に「⚠ 改訂ノート（print-platform 対応・印刷専用化）」を追記し、権威契約は `.kiro/specs/CommonModule/print-platform/` を参照。旧 payload/PDF生成記述は改訂前履歴として残置。
- 追記済み（`\\ojiadm23120073\Labs\WindowsService\PrintAgent\docs\`）:
  - `spec.md`: 詳細版改訂ノート（読取先 t_print_queue@db_common_dev／印刷専用・pdf_path 必須／print_payload・PdfGeneratorService・Documents 退役／printed_at 一本化・row_version／slnCoCore 除外）。
  - `requirements.md`・`design.md`・`tasks.md`: 簡潔版改訂ノート（spec.md 参照）。design は TOrderReport→TPrintQueue・接続 db_common_dev も明記。tasks は「改訂作業は print-platform tasks 6・7 で実施済み」を明記。
- `direct-print/`（旧設計案4本）・`PrintAgent_Source/`（旧ソーススナップショット）は履歴資料としてそのまま（更新せず）。

### 残（次回候補）
- PrintAgent クリーンアップ（コード）: `PdfGeneratorService`/`IPdfGeneratorService`/`Documents/*.cs`・旧 `TOrderReport.cs` 削除＋`Program.cs` の IPdfGeneratorService 登録除去。※ビルド確認要（別sln）。
- 任意PBT（3.2/3.3/4.2/4.3/4.5/4.7/7.3/7.5）・CP 5/8/10。
- 実行系（ユーザー）: DDL適用・実印刷・カットオーバー（dispatch-monitoring-consolidation 前提）。
- 未コミット: PrintAgent/docs（spec/requirements/design/tasks 改訂ノート・別git）・Nonaka/.kiro（本memo）。

---

## PrintAgent クリーンアップ完了（退役コード削除・印刷専用の最小構成へ）

- コミット済み: PrintAgent `121efdf`（docs改訂ノート）／Nonaka `a96568d`（memo）。
- **退役実施（PrintAgent・別git）**:
  - `Program.cs`: QuestPDF ライセンス設定・`using QuestPDF.Infrastructure;`・`AddSingleton<IPdfGeneratorService,PdfGeneratorService>()` 除去。ISilentPrintService/DbContext/AddHostedService<PrintJobWorker> は維持。
  - `PrintAgent.csproj`: `QuestPDF`・`QRCoder` PackageReference 除去（EF Core/Hosting系維持）。
  - 削除8ファイル: Services/IPdfGeneratorService.cs・PdfGeneratorService.cs／Documents/IReportDocument.cs・OrderApprovalDocument.cs・ReceivingSlipDocument.cs・FactoryInvoiceDocument.cs（Documents/空）／Models/PrintPayloadDto.cs・TOrderReport.cs。
  - grep で退役型名・QuestPDF/QRCoder の残参照なし。Program.cs/PrintJobWorker.cs 診断クリア。
- PrintAgent は印刷専用の最小構成（ポーリング→pdf_path サイレント印刷→状態遷移→heartbeat）。
- ⏳ ユーザー: PrintAgent.sln 再ビルドで確認。未コミット: PrintAgent（Program.cs/csproj/削除8）。

### print-platform 残（任意・検証・実行系のみ）
- 任意PBT: 3.2/3.3/4.2/4.3/4.5/4.7・7.3/7.5。検証CP: 5/8/10。7.4 heartbeat（実質OK・未チェック）。
- 実行系（ユーザー）: DDL適用（t_print_queue/m_print_agent_control）・実印刷・カットオーバー（dispatch-monitoring-consolidation 前提）。
- コア実装＋関連ドキュメント反映＋クリーンアップ 完了。

---

## 任意PBT 着手：PrintQueueService（3.2/3.3）完了

- PrintAgent クリーンアップ コミット済み: PrintAgent `1df9156`（10ファイル・578行削除）。PrintAgent.sln ビルドOK（ユーザー確認）。
- CommonModule.Tests のPBT作法確認: FsCheck 2.16.6・FsCheck.Xunit・InMemory 8.0.23・`[Property(MaxTest=100)]`・一意DB名・`// Feature:` タグ。参照＝`Services/SmtpQueueServicePropertyTests.cs`、`Pages/SmtpMonitor/*`（Alive/List/Resend/ErrorMessage＋TestHelper）。
- **作成: `clnCoCore/CommonModule.Tests/Services/PrintQueueServicePropertyTests.cs`**（診断クリア）:
  - 3.2 Property 1（投入は1件追加・print_status=1・入力保持・copies正規化・created_at==updated_at・他テーブル不操作）。
  - 3.3 Property 2（必須 module/reportType/referenceCode/**pdfPath** のいずれか空白→ArgumentException・テーブル不変。null! で null 注入・AggregateException/ArgumentException 両捕捉）。
- tasks 3.2/3.3＝[x]（任意）。テスト実行はユーザー側（未実行のため pass/fail 未記録）。

### 残（任意PBT・検証・実行系）
- 監視画面PBT（SMTP対応あり）: 4.2 フィルタ(P4)／4.3 サマリ(P5)／4.5 死活(P6)／4.7 再出力(P3)。Worker: 7.3 状態遷移(P7)／7.5 二重取得統合(P9)。
- 検証CP 5/8/10。実行系（DDL適用・実印刷・カットオーバー）。
- 未コミット: CommonModule.Tests（PrintQueueServicePropertyTests.cs）・Nonaka/.kiro（tasks 3.2/3.3・memo）。

---

## 任意PBT 追加完了（4.2/4.3/7.3）＋7.5 の技術的論点

- コミット済み: clnCoCore `193f50b`（4.5/4.7）/ Nonaka `867e8e8`。以降 4.2/4.3/7.3 は未コミット。
- **作成（CommonModule.Tests・診断クリア）**:
  - `Pages/PrintMonitor/PrintMonitorFilterPropertyTests.cs`（4.2 Property4 フィルタ：全条件充足＋一致集合SetEquals＋TotalCount）。
  - `Pages/PrintMonitor/PrintMonitorSummaryPropertyTests.cs`（4.3 Property5 サマリ：status別件数＝母集合・0除外・フィルタ非依存）。
  - `Pages/PrintMonitor/PrintStatusTransitionPropertyTests.cs`（7.3 Property7 状態遷移：純粋モデル TryApply。Worker 1→2/2→3/2→9・Reprint 3→1/9→1・3/9→2禁止・0不活性・列単調性。Worker は別sln参照不可のため自己完結モデルで検証）。
- tasks 4.2/4.3/7.3＝[x]（任意）。

### 🔴 7.5（Property 9 二重取得防止・統合）の論点＝要判断
- 内容: 同一 t_print_queue 待機行を2コンテキストで取得・print_status=2 更新→一方成功・他方 `DbUpdateConcurrencyException`。
- **技術的制約**: EF Core **InMemory は rowversion 同時実行を強制せず `DbUpdateConcurrencyException` を発生させない**。SQLite も [Timestamp]/rowversion 自動採番を扱えない。→ **真の検証には SQL Server（db_common_dev）実DBが必要**。design も「INTEGRATION・1〜2例・実行はユーザー側」と規定。
- 選択肢:
  - (A) SQL Server 実DB向け統合テストを作成（既定スキップ＝環境変数/接続文字列ガード。ユーザーが db_common_dev に対し手動実行）。
  - (B) 実装せず「ユーザー手動の統合確認」として据え置き（optional のためスキップ可）。
- → 次セッションでユーザー判断。他の任意PBT（3.2/3.3/4.2/4.3/4.5/4.7/7.3）は完了。

### print-platform 残
- 7.5（上記・要判断）。検証CP 5/8/10（テスト実行＝ユーザー）。実行系（DDL適用・実印刷・カットオーバー）。
- 未コミット: CommonModule.Tests（Filter/Summary/Transition 3ファイル）・Nonaka/.kiro（tasks 4.2/4.3/7.3・memo）。

---

## 7.5 完了（Property 9 統合テスト・既定スキップ）＝任意PBT 全完了

- 作成: `clnCoCore/CommonModule.Tests/Integration/PrintQueueConcurrencyIntegrationTests.cs`（診断クリア）。
  - xUnit `[Fact(Skip=...)]` 既定スキップ。環境変数 `PRINT_PLATFORM_IT_CONN`（未設定時 db_common_dev 既定接続）で `.UseSqlServer`。
  - 待機行1件投入→2コンテキストで同一行取得→双方 print_status=2 更新→ctx#1成功・ctx#2 `DbUpdateConcurrencyException`→最終 status=2 検証→finally で行削除。
  - InMemory は rowversion 競合を再現しないため実 SQL Server 前提（design の INTEGRATION 方針どおり）。ユーザーが DDL 適用後に手動実行。
- tasks 7.5＝[x]。

### print-platform タスク到達状況
- 実装系タスク（1〜4・6・7.1・9・11）＝完了。任意PBT（3.2/3.3/4.2/4.3/4.5/4.7/7.3）＝完了。統合(7.5)＝完了(スキップ)。7.4 heartbeat＝既存維持で実質OK。
- **未完＝ユーザー実行の検証ゲートのみ**: CP 5（CommonModule.Tests 実行）・CP 8（PrintAgent/統合）・CP 10（全テスト）＝テスト実行はユーザー側。実行系（DDL適用・実印刷・カットオーバー＝dispatch-monitoring-consolidation 前提）。
- コミット済み: clnCoCore `f22c660`(4.2/4.3/7.3) / Nonaka `48765ee`。未コミット: clnCoCore（7.5 Integration）・Nonaka/.kiro（tasks 7.5・memo）。

### 次
- 7.5 コミット後、print-platform は**実装・テスト実装・ドキュメント・クリーンアップが完了**。残るはユーザーのテスト実行（CP）・DDL適用・カットオーバー（dispatch-monitoring-consolidation 実装後）。
- 次の大きな一手は依存spec **dispatch-monitoring-consolidation**（投入側 PrintJobService→IPrintQueueService＋MaterialModule の PDF 生成→pdf_path）。

---

## テスト実行結果（CommonModule.Tests）＝グリーン／CP5 完了

- Kiro が `dotnet test CommonModule.Tests` を実行（ユーザー明示指示）。
- 初回: 合計17/成功16/スキップ1/失敗0。ただしビルド警告 CS8620（`PrintMonitorReprintPropertyTests.cs` pdfPathGen の `Gen.OneOf` に `Gen<string>` と `Gen<string?>` 混在）。
- 修正: 先頭 `Gen.Elements` を `Gen.Elements<string?>` に統一。再テスト＝**合計17/成功16/スキップ1/失敗0・警告0**（クリーン）。
- スキップ1＝Property 9 統合テスト（要 SQL Server db_common_dev・既定スキップ）。InMemory 不要の PBT（Property 1〜7）は全緑。
- **CP5（CommonModule のテストを通す）＝完了**（tasks 5＝[x]）。コミット clnCoCore `a67582c`。
- InMemory PBT は t_print_queue 実テーブル不要（モデルからメモリ生成）で実行可能を実証。

### print-platform 残（ユーザー実行系のみ）
- CP8（Property 7〜9）：7.3 緑・**7.5 は要 SQL Server 実行**（DDL適用後に PRINT_PLATFORM_IT_CONN 設定 or Skip解除）。
- CP10（全テスト）：7.5 実DB実行を含め最終確認。
- 実行系: DDL適用（t_print_queue/m_print_agent_control）・実印刷・カットオーバー（dispatch-monitoring-consolidation 前提）。
- 未コミット: Nonaka/.kiro（tasks CP5・本memo）。

---

## 次アクション：ビルド→/Common/PrintMonitor 表示確認（スモーク）

- ユーザーが CommonModule ページ権限（m_content: area=Common/page=PrintMonitor/Index）を登録。
- 手順: ①db_common_dev に DDL 2本適用（create_t_print_queue.sql / create_m_print_agent_control.sql）→ ②slnCoCore ビルド→MainWeb 起動 → ③ログイン→ /Common/PrintMonitor 表示確認。
- **正常時**: 一覧空・サマリ0・PrintAgent「応答なし」（db_common_dev 向け PrintAgent 未起動のため正常）・SmtpMonitor と一貫スタイル。
- **異常時の切り分け**: 500「Invalid object name 't_print_queue'」＝DDL未適用／トップへリダイレクト＝権限未登録／null例外・崩れ＝Kiro 対応。
- 表示確認OK＝CommonModule 側の疎通完了（ルーティング/認可/DB接続）。実データ投入は dispatch-monitoring-consolidation 実装後。
- 現状コミット済み: print-platform 実装・PBT・CP5・docs。未コミットなし（tasks/memo 直近コミット済み）。
- 表示確認の結果待ち → OKなら dispatch-monitoring-consolidation 着手 or 一区切り。

---

## /Common/PrintMonitor 実機表示確認 OK（CommonModule 疎通完了）

- 経緯: 初回アクセスで `SqlException: オブジェクト名 'm_print_agent_control' が無効` → **DDL未適用**（想定内・コード起因でない）。ユーザーが db_common_dev に `create_m_print_agent_control.sql`＋`create_t_print_queue.sql` を適用。
- 再アクセスで **表示OK**（スクショ確認）: タイトル「プリント出力監視」／死活「応答なし・最終応答:記録なし」（PrintAgent 未起動で正常）／サマリ 待機・処理中・完了・エラー=全0／フィルタ（ステータス/レポート種別/キーワード/作成日From-To）／一覧「該当するジョブはありません。」／自動更新チェック・件数セレクタ・SmtpMonitor と一貫スタイル。
- → **CommonModule 側の疎通確認完了**（MainWeb ホスト・ルーティング・DbPermissionCheck 認可・db_common_dev 接続・EF クエリ・Razor 描画）。print-platform の Web 側は実機で完全動作。
- DDL適用済み（db_common_dev）: t_print_queue / m_print_agent_control。

### print-platform 到達サマリ（実機確認まで完了）
- 実装・PBT(16緑/1skip)・CP5・ドキュメント・退役クリーンアップ・**実機表示確認** すべて完了。
- 残＝実データを流す一連（投入→PrintAgent印刷）＝依存spec **dispatch-monitoring-consolidation**（MaterialModule で PDF 生成→pdf_path 投入・旧Material_PrintMonitor 廃止・導線を /Common/PrintMonitor へ）。Property9 実DB検証・カットオーバーもこの後。

### 次アクション
- print-platform は一区切り（Web側は実機動作確認済み）。
- 次の大きな一手＝ **dispatch-monitoring-consolidation**（requirements/design/tasks は既存？ 要確認 → 着手）。

---

## 関連資料更新：未実装案件一覧（print-platform 完了を反映）

- `.kiro/docs/未実装案件一覧.md`:
  - ヘッダ最終更新を 2026/07/02・print-platform 実装/実機確認完了に更新。
  - サマリ表: 旧「PrintAgent 資材固有 t_order_reports」＝置換完了／「PrintAgent 方向性2」→「共通印刷基盤 print-platform ＝実装・実機確認完了(2026/07/02)」／新規「dispatch-monitoring-consolidation＝未着手（次）」を追加。
  - B-2 節に【更新 2026/07/02】追記：print-platform spec として実装・実機確認完了（t_print_queue/pdf_path必須/print_payload廃止・CommonModule 投入/監視・PrintAgent 印刷専用化・PBT緑・表示OK）。残は dispatch-monitoring-consolidation（投入側/旧Monitor廃止/カットオーバー）。
- 既更新: system-architecture.md（印刷専用・slnCoCore構成）／テーブル定義書・ER図（print-platform テーブル）／PrintAgent docs（改訂ノート）／CommonModule docs README。

### 現状（再開用チェックポイント）
- **print-platform：実装・テスト(PBT)・ドキュメント・実機表示確認まで完了・コミット済み**。Web側は db_common_dev の DDL 適用済みで /Common/PrintMonitor 稼働。
- 次の一手＝**dispatch-monitoring-consolidation**（requirements/design は既存有り＝session-memo 20260701 記載。tasks 未作成）。着手時: 既存 requirements/design を確認 → tasks 生成 → 実装（MaterialModule で PDF生成→IPrintQueueService 投入・旧Material_PrintMonitor廃止・導線更新）→ カットオーバー。
- 未コミット: `.kiro/docs/未実装案件一覧.md`・session-memo（本追記）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260702）。

---

## dispatch-monitoring-consolidation 着手：requirements 整合更新（print-platform 最終契約へ）

### ユーザー確定（3決定）
1. PDF生成は送信側モジュール（MaterialModule）の責任＝印刷イメージ生成は送信側。
2. PDF保存先パスは**マスタ管理**（現行 `\\ojiadm23120073\app_share\PrintAgent`・将来クラウド化はマスタ変更で対応）。
3. requirements 整合更新から進める＝OK。

### requirements.md 更新（診断クリア・単一正本 `.kiro/specs/MaterialModule/dispatch-monitoring-consolidation/`）
- Introduction: 項3=PrintJobService が PDF 生成・保存→pdf_path 付きで t_print_queue 投入（PrintPayload 削除）。新項4=PDF生成責務の移管（PrintAgent→MaterialModule・3帳票 QuestPDF）。
- 依存: 投入契約を pdf_path 付与（必須）に。PDF生成は print-platform 非所有＝本spec(MaterialModule)所有と明記。
- Non-Goals: 「帳票レイアウト・PDF生成ロジックの変更」を除去（IN スコープ化）。
- Glossary: PrintPayload→pdf_path、PrintJobService=PDF生成・保存、**印刷出力パスマスタ**追加。
- R4: pdf_path 必須付与・print_payload 不使用。**新R8**=PDF生成のMaterialModule所有（3帳票・保存→pdf_path投入・レイアウト所有）。**新R9**=PDF保存先パスのマスタ管理（現行値・コード変更なし変更可・双方到達・配置は設計）。
- R7.3: 2箇所配置→単一正本（コピー廃止）。

### 次アクション
- requirements 整合済み → **design 生成**（要点: 投入経路＝IPrintQueueservice 経由/直接どちらか・PDF生成サービス設計（QuestPDF レイアウト3種の MaterialModule 移設）・保存先パスマスタのテーブル/DB配置（db_material_dev想定・要design判断）・命名/保存規則・旧Material_SmtpMonitor/PrintMonitor廃止と導線・カットオーバー協調）。
- その後 tasks → 実装 → カットオーバー。
- 未コミット: requirements.md・session-memo。

---

## メモ：PDFサイレント出力テスト方針＋design 着手

- コミット済み: requirements 整合（Nonaka `3d7f1b6`）。未コミットなし。
- **サイレント出力テスト**: 開発環境の PrintAgent＋開発環境プリンタ設定で実施予定（ユーザー）。段階1（手動 t_print_queue INSERT→PrintAgent 印刷専用パス検証）は DDL適用済みのため PrintAgent 再デプロイ＋SumatraPDF/プリンタ設定＋SkipPrint=false で今でも可能。段階2（承認→PDF生成→投入→印刷）は本spec R8/R4 実装後。
- **design 生成の論点**:
  - 投入経路: MaterialModule は既に CommonModule 参照済み（order-approval-fax-mail で ISmtpQueueService 利用）→ **IPrintQueueService 経由**が有力。
  - PDF生成: MaterialModule に既存 `OrderPdfService.GenerateGroupOrderPdfAsync`（発注書兼納入依頼書・QuestPDF）が有るはず→**既存資産の再利用**を優先検討（PrintAgent の旧 Documents は重複だった）。工場入れ請求／入庫伝票の生成有無を確認。
  - 保存先パスマスタ: テーブル/DB配置（db_material_dev 想定）・ファイル名規則（reference_code ベース）・保存後 pdf_path 投入。
  - 旧 Material_SmtpMonitor／Material_PrintMonitor 廃止・導線更新。カットオーバー協調（print-platform 手順）。
- 次: design.md 生成 → tasks → 実装 → カットオーバー。

---

## dispatch-monitoring-consolidation design.md 生成完了（IDE生成→上書き解決・診断クリア）

- 「design.md 保存できませんでした（内容が新しい）」→ ユーザーが**上書き**選択で解決。生成された design は最終契約と完全整合の完成版。
- 内容: Overview/Architecture(FAX投入とのパリティ表・承認→印刷 Mermaid)/Components(PrintJobService改修・OrderPdfService再利用・**IPrintOutputPathService新規**・旧Monitor2画面廃止・m_content導線解除)/Data Models(**m_print_output_path**@db_material_dev・MPrintOutputPath・ファイル名規則・t_print_queue投入列対応)/Correctness Properties 1〜3(PBT・MaterialModule.Tests)/Error Handling/Testing/カットオーバー協調(③投入先切替所有)/排他制御/Open Decisions/実装最小単位9。診断クリア。
- 主要設計判断: 投入=**IPrintQueueService経由**（既存CommonModule参照・MainWeb変更不要）／PDF=**OrderPdfService再利用**（PrintAgent旧Documentsは重複・移植不要）／**キュー印刷対象=order_approdval のみ**（receiving/factory はDL方式・キュー非経由）／保存先=**m_print_output_path マスタ**（is_active・現行値シード・実行時取得でコード変更なし変更可）／導線=**m_content解除SQL**（Auth DB・ユーザー実行・MainWeb不変更）。

### Open Decisions（tasks前に確認・既定案）
1. キュー印刷対象＝order_approval のみ（receiving_slip/factory_invoice はDL方式のまま）。
2. TOrderReport/t_order_reports は参照除去のみ・削除しない（print-platform 移行/保全依存）。
3. 印刷出力パスマスタ編集UIはスコープ外（DB直更新/シード）。

### 次
- 上記3点ユーザー確認 → tasks 生成 → 実装（最小単位9）→ カットオーバー協調。
- 未コミット: design.md（IDE生成・未コミット）・session-memo。

---

## dispatch-monitoring-consolidation design 作成完了（診断クリア）

- 開発環境PrintAgentで dev プリンタ設定によるサイレント出力テスト予定（ユーザー）。PDFサイレントテストの段階: ①PrintAgent単体（手動INSERT・今すぐ可）②業務フロー全体（本spec R8/R4 実装後）。
- design 主要決定:
  - 投入経路＝`IPrintQueueService.EnqueueAsync`（既存 CommonModule 参照・SMTPパリティ）。t_order_reports 非書込・fax_status/print_payload 非使用。
  - PDF生成＝既存 `OrderPdfService.GenerateGroupOrderPdfAsync` 再利用（**3帳票とも MaterialModule に既存**・PrintAgent移植不要）。キュー投入対象は order_approval のみ（receiving_slip/factory_invoice は現状オンデマンドDL）。
  - パスマスタ＝db_material_dev 新設 `m_print_output_path`（base_path/description/is_active/row_version/created_at/updated_at・監査created_by等なし）。`IPrintOutputPathService.GetBasePathAsync`（無キャッシュ・既定 `\\ojiadm23120073\app_share\PrintAgent`）。pdf_path=Path.Combine(base_path, fileName)。fileName=`{reportType}_{referenceCode}_{yyyyMMddHHmmssfff}.pdf`。
  - 旧 Material_SmtpMonitor/PrintMonitor 削除＋fax_status/print_status/print_payload 参照除去。導線＝dbAuthTest.m_content 駆動 → 解除SQL（ユーザー実行）で /Common/* へ。
  - Property 1〜3（PBT・MaterialModule.Tests）。カットオーバー③投入先切替のみ所有（print-platform R11 参照）。row_version 排他。MainWeb/AuthModule 不変。
- 実装最小単位9項目を design 内に明記（tasks 指針）。

### Open Decisions（tasks前に確認）
1. **キュー印刷対象=order_approval のみ**（receiving_slip/factory_invoice はオンデマンドDLのまま）でよいか。
2. TOrderReport/t_order_reports は参照除去に留め削除しない（保全）。
3. パスマスタ編集UIはスコープ外（DB直/シード運用）。

### 次
- design 合意 → tasks 生成（最小単位9）→ 実装（1つずつ）。
- 未コミット: design.md・.config.kiro・session-memo。

---

## dispatch-monitoring-consolidation tasks.md 生成完了（3フェーズ揃い）

- design コミット: Nonaka `f37a21a`。
- tasks.md（診断クリア・16リーフ/7ウェーブ）:
  - 1. パスマスタ基盤（1.1 MPrintOutputPath+DbSet／1.2 DDL+シードSQL／1.3 テーブル定義書・ER図）
  - 2. IPrintOutputPathService（2.1 実装+DI／2.2* BuildFullPath例示）
  - 3. PrintJobService改修（3.1 純関数 ExtractGroupKey/BuildPdfFileName／3.2 CreateOrderApprovalJobsAsync 投入先変更）
  - 4. CP（非任意ゲート）
  - 5. 旧画面廃止（5.1 SmtpMonitor削除+fax_status撤去／5.2 PrintMonitor削除+print_status/PrintPayload撤去）
  - 6. 導線解除SQL（6.1 dbAuthTest m_content/r_content_auth）
  - 7. テスト（7.1* P1／7.2* P2／7.3* P3／7.4* 例示／7.5* 統合）
  - 8. CP（非任意ゲート）
  - 9. カットオーバー協調（9.1 doc/spec-sync）
  - Wave: 0[1.1,1.2,1.3]→1[2.1]→2[2.2,3.1]→3[3.2]→4[5.1,5.2,6.1]→5[7.x]→6[9.1]。
- 制約明記: MaterialModule 限定（+既存CommonModule参照）・MainWeb/AuthModule不変更・投入=IPrintQueueService経由・IPrintJobService シグネチャ維持・DDL/テスト/実印刷/m_content SQLはユーザー側。

### 現況・次
- print-platform：実装/テスト/実機確認 完了。dispatch-monitoring-consolidation：requirements/design/tasks 揃い＝**実装着手可**。
- 実装は最小単位で1つずつ（wave順）: **1.1 MPrintOutputPath エンティティ+DbSet** から。
- 未コミット: tasks.md・session-memo。

---

## 🔴 チェックポイント（コンテキスト80%超・new-session ハンドオフ用）

### 現在地（2026/07/02 時点）
- **print-platform（共通印刷基盤）: 完了**。実装・PBT(16緑/1skip)・ドキュメント・退役クリーンアップ・実機表示確認(/Common/PrintMonitor)まで済み・全コミット済み。db_common_dev に DDL 適用済み（t_print_queue / m_print_agent_control）。
- **dispatch-monitoring-consolidation（MaterialModule・投入側）: requirements/design/tasks 3点揃い・全コミット済み・実装未着手**。
  - 直近コミット: design `f37a21a` / tasks `34b2a2e`（Nonaka repo）。未コミットなし。

### 次に行う1アクション
- **タスク 1.1「`MPrintOutputPath` エンティティ追加＋`MaterialDbContext` に DbSet 追加」** から着手（wave0）。
  - `MaterialModule/Data/Entities/MPrintOutputPath.cs` 新規（`[Table("m_print_output_path")]`・Id/BasePath[Required,MaxLength500]/Description/IsActive/RowVersion[Timestamp]/CreatedAt/UpdatedAt・監査 created_by/updated_by は持たない＝MaterialModule規約）。
  - `MaterialDbContext` に `DbSet<MPrintOutputPath> PrintOutputPaths` 追加。
  - 参照: `.kiro/specs/MaterialModule/dispatch-monitoring-consolidation/design.md`「Data Models / エンティティ MPrintOutputPath」。

### 実装 wave 順（tasks.md）
- 0: 1.1 entity+DbSet / 1.2 DDL+シードSQL(MaterialModule/docs/sql・db_material_dev・base_path 既定 \\ojiadm23120073\app_share\PrintAgent) / 1.3 テーブル定義書・ER図
- 1: 2.1 IPrintOutputPathService/PrintOutputPathService+DI(AddMaterialModule)＋純関数 BuildFullPath
- 2: 2.2* 例示 / 3.1 純関数 ExtractGroupKey・BuildPdfFileName（PrintJobService内 internal static）
- 3: 3.2 CreateOrderApprovalJobsAsync 改修（OrderPdfService再利用でPDF生成→保存→IPrintQueueService.EnqueueAsync 投入。t_order_reports非書込・fax_status非設定・print_payload廃止。IPrintJobService シグネチャ維持）
- 4: CP（ビルド/テスト＝ユーザー）
- 5: 5.1 Material_SmtpMonitor 削除+fax_status/fax_at/fax_error_message 撤去 / 5.2 Material_PrintMonitor 削除+print_status/PrintPayload/PrintAgentControls 撤去 / 6.1 導線解除SQL(dbAuthTest m_content/r_content_auth・Material SmtpMonitor/Index・PrintMonitor/Index)
- 6→: 7.1*-7.5* テスト(Property1〜3+例示+統合・MaterialModule.Tests・xUnit+FsCheck.Xunit・≥100) → 8 CP → 9.1 カットオーバー協調ノート

### 重要な決定・制約（再掲）
- 投入=**IPrintQueueService.EnqueueAsync 経由**（既存 MaterialModule→CommonModule ProjectReference 利用・MainWeb 不変更）。PDF=**OrderPdfService.GenerateGroupOrderPdfAsync 再利用**（PrintAgent旧Documentsは退役・移植不要）。
- **キュー印刷対象=order_approval のみ**（receiving_slip/factory_invoice はDL方式のまま・確定）。
- 保存先=**m_print_output_path マスタ**(db_material_dev・is_active・実行時取得でコード変更なし変更可・現行値シード)。pdf_path=Path.Combine(base_path, `{reportType}_{referenceCode}_{yyyyMMddHHmmssfff}.pdf`)。
- 導線=**m_content 解除SQL**（Auth DB・ユーザー実行）。TOrderReport/t_order_reports は参照除去のみ・削除しない。
- パスは小文字 `ojiadm23120073`。1ターン=1タスクで区切る。長時間処理は分割。ビルド/テスト/DDL/実印刷/SQL実行はユーザー側。MainWeb/SharedCore/AuthModule 変更不可。

### PDFサイレント印刷テスト（ユーザー・開発環境）
- 段階1（今でも可）: 手動で t_print_queue に1行 INSERT（pdf_path=共有パスの実在PDF・print_status=1・output_type=1）→ PrintAgent(db_common_dev向け・SumatraPDF・開発プリンタ・SkipPrint=false)で印刷専用パス検証。
- 段階2: 承認→PDF生成→投入→印刷の一連（本spec R8/R4 実装後）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260702）。次アクション＝タスク1.1。
