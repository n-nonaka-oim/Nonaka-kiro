# セッション備忘録（2026/07/13）

前回（20260710）＝agent-service-manager 完成（実装・実機OK・spec クローズ）、「Labs 統合」はマルチルート `CoCore-Workspace.code-workspace`（Nonaka/clnCommonModule/WindowsService）で一元化。本日は残作業・未実装案件の整理から。

## 1. 未実装案件一覧の最新化（完了）
`.kiro/docs/未実装案件一覧.md` を 7/8 → **7/13 現況**に更新:
- 優先度表：**K（agent-service-manager）=完了** 行追加、I（send-config）を「実機疎通OK」、**G を「着手可（要件から）」**（A・B 完了で着手条件解除）、J（孤立テーブル DROP）行追加。
- **K 節新設**（agent-service-manager 完了詳細＋残＝repo remote/push・Tests 版管理・本番配置）。
- **I-2 更新**：MaterialModule→CommonModule 参照済・発注承認FAX は DispatchEnqueue 経由で連携済（案C 部分完了）。残は他業務トリガーの要件次第。

## 残作業の整理（現況）

**① すぐ終わる/確定（主にユーザー実行）**
- J-1 孤立3テーブル DROP（スクリプト済・破壊的・ユーザー）。

**② 小さめ機能修正（MaterialModule・要件ほぼ確定）**
- E/A-1 入庫ステータス色表示の不具合（バグ）。
- C-1 用途1 の編集UI（用途2/3 はマスタ化済）。
- D タンク残量 出庫自動登録 動作確認＋ナビリンク追加。

**③ 中規模（要件ヒアリング要・価値高）**
- G 原材料 計画単価・計画数量＋実績対比分析（7/9 保留・再開候補）。
- Excel インポート（仕入先/購買条件）。

**④ 将来/運用**
- F 所要計算・発注点自動計算（Phase2）。H HULFT。Agent 運用整備（remote/push・本番配置）。

## 次アクション
- ユーザーに ② or ③ の着手対象を確認（推奨：G 要件再開 or E/A-1 バグ）。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。ワークスペースは CoCore-Workspace.code-workspace。

---

## 新規 spec `materialmodule-legacy-cleanup` 起草＋実装着手

### 経緯
- CommonModule/PrintAgent/SmtpAgent 移行で MaterialModule に残った残骸（空ページ・legacy JobQueue・未使用エンティティ・デッドコード）を整理。ユーザー指示で **spec 化・小規模単位**で実施。

### spec 作成（`.kiro/specs/MaterialModule/materialmodule-legacy-cleanup/`・全診断クリア）
- requirements（R1 空dir／R2 JobQueue 廃止／R3 未使用エンティティ MSmtpConfig・MSmtpAgentControl・MPrintAgentControl／R4 デッドコード DeliveryMonitorDto・OrderRecommendationViewModel＋未使用OrderServiceメソッド／R5 TOrderReport コード側退役（テーブル保全）／R6 DB DROP=ユーザー／R7 保持=MPrintOutputPath／R8 docs）。
- design（撤去順・証拠・Data Models・Property1 残存参照ゼロ/Property2 ビルド不変）。
- tasks（1 空dir／2 JobQueue（2.1 PDF他利用確認/2.2 削除/2.3 導線解除SQL）／3 未使用エンティティ／4 デッドコード（4.1/4.2）／5 TOrderReport／6 ビルドCP／7 docs／8 DB DROP CP）＋依存グラフ。

### 調査で判明（証拠）
- 空dir（ソース0）：SmtpMonitor/PrintMonitor/FaxMonitor/PrintQueue/DeliveryMonitor/OrderRecommendation。
- 未使用（定義+DbSetのみ）：MSmtpConfig/MSmtpAgentControl/MPrintAgentControl。
- デッドコード：DeliveryMonitorDto＋IOrderService/OrderService.GetDeliveryMonitorListAsync（呼出元なし）、OrderRecommendationViewModel。
- JobQueue：t_order_reports 依存の旧印刷/FAX一覧＝廃止（ユーザー承認）。
- 保持：MPrintOutputPath/PrintOutputPaths（発注PDF保存先・使用中）。DeliveryMonitor/OrderRecommendation は「過去に存在→現在ソース空」の残骸（機能は Delivery/Mrp/OrderPlanning へ）。

### 実装 task 1 完了
- 空ページdir 6件を削除（各 items=0 確認済）。残ページ12件は業務ページ＋JobQueue。

### 実装 task 2〜5 完了（2026/07/13）
- **task2 JobQueue 廃止**: `GenerateGroupOrderPdfAsync` は `ApprovalReportPdfProvider`（現行）で使用中→`IOrderPdfService`/`OrderPdfService` は残す。`JobQueue/` ページ削除。導線解除SQL `MaterialModule/docs/sql/unregister_jobqueue_content.sql` 作成（ユーザー適用）。
- **task3 未使用エンティティ削除**: `MSmtpConfig`/`MSmtpAgentControl`/`MPrintAgentControl` エンティティ＋DbSet 3行削除。診断クリア。
- **task4 デッドコード削除**: `DeliveryMonitorDto`＋`IOrderService.GetDeliveryMonitorListAsync`宣言＋`OrderService`実装、`OrderRecommendationViewModel` 削除。残存参照0。
- **task5 TOrderReport 退役**: エンティティ＋`OrderReports` DbSet 削除（テーブルは保全）。
  - テスト是正（承認 a）: `Nonaka\MaterialModule.Tests\...\DispatchEnqueueUnitTests.cs` の `Context.OrderReports` 参照除去（テスト名も `..._EnqueuesViaSmtpQueueOnly` に）。SmtpQueue 投入検証は維持。
- 全撤去シンボルの残存参照＝MaterialModule 0／`clnCoCore\MaterialModule.Tests` 0／`Nonaka\MaterialModule.Tests` 0。全診断クリア。保持: `MPrintOutputPath`（使用中）。

### 発見（別途整理候補・本 spec 範囲外）
- MaterialModule.Tests が二重: `Nonaka\MaterialModule.Tests`（slnCoCore 未参照・dispatch テスト有）と `clnCoCore\MaterialModule.Tests`（solution 参照）。統合/退役は別途。
- 併せて `Nonaka\ojiadm23120073\Labs\...` の階層まるごとの stray 複製も存在（別途）。

### ⏳ ユーザー（task6 CP）
- slnCoCore ビルドで撤去後も成功・現行ページに影響なしを確認。

### task6/7 完了（2026/07/13）
- task6: slnCoCore ビルド **OK**（ユーザー・撤去後も成功）。
- task7 docs 整合: `テーブル定義書.md`「重複テーブルの整理」にコード側撤去（cleanup 07/13）追記。`未実装案件一覧.md` に **L 節（cleanup）**追加・優先度表更新・**J-1 は 07/03 DROP 済**に是正（従来「ユーザー待ち」は陳腐化していた）。ER図はテーブル構成不変で変更なし。

### cleanup spec 実装ステータス
- **task 1〜7 完了**。残＝**task8（ユーザー）**：JobQueue 導線解除SQL 適用（dbAuthTest）。J-1 は DROP 済・J-2 は保全後。

### 未コミット（このあと・ユーザー承認で）
- MaterialModule：ページ/エンティティ/サービス/DbContext 撤去・`unregister_jobqueue_content.sql` 追加・DispatchEnqueueUnitTests 是正（テストは git 管理外運用）。
- Nonaka/.kiro：cleanup spec 3点・テーブル定義書・未実装案件一覧・本 memo。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。cleanup spec：task1〜7 完了・残 task8（ユーザーの導線解除SQL 適用）。

---

## 🔴 コンテキスト80%・ハンドオフ チェックポイント（2026/07/13）

### 現在地（確定・コミット済み）
- **materialmodule-legacy-cleanup spec**：task 1〜7 完了・コミット済み。
  - MaterialModule `cf00db5`（JobQueue廃止・未使用エンティティ MSmtpConfig/MSmtpAgentControl/MPrintAgentControl・TOrderReport・デッドコード DeliveryMonitorDto/OrderRecommendationViewModel/OrderService.GetDeliveryMonitorListAsync 削除・空ページdir6削除・`unregister_jobqueue_content.sql` 追加）。slnCoCore ビルドOK。
  - Nonaka/.kiro `09ff858`（cleanup spec 3点＋テーブル定義書/未実装案件一覧 整合＋本memo）。
  - 保持: `MPrintOutputPath`（発注PDF保存先・使用中）。
  - テスト是正: `Nonaka\MaterialModule.Tests\OrderApprovalFaxMail\DispatchEnqueueUnitTests.cs` の OrderReports 参照除去（git 管理外運用のためコミット対象外・ディスク更新済）。

### 残（次セッション先頭でユーザー実行）
- **cleanup task 8（ユーザー）**：`MaterialModule/docs/sql/unregister_jobqueue_content.sql` を **dbAuthTest** に適用（メニューから JobQueue 除去）。J-1 は 2026/07/03 DROP 済／J-2（t_order_reports）は保全後にユーザー判断で DROP。

### 次テーマ候補（未着手・優先度メモ）
1. **別途整理**（本 cleanup の副産物）:
   - MaterialModule.Tests の二重：`Nonaka\MaterialModule.Tests`（slnCoCore 未参照・dispatch テスト有）vs `clnCoCore\MaterialModule.Tests`（solution 参照）。統合/退役を要検討。
   - `Nonaka\ojiadm23120073\Labs\...` の階層まるごと stray 複製の除去。
2. **優先度2：G 原材料 計画単価・計画数量＋実績対比分析**（MaterialModule・新規・7/9 に要件ヒアリング途中で保留＝再開候補・価値高）。着手条件（A・B）は解除済み。
3. 優先度1：E/A-1 入庫ステータス色表示の不具合（小バグ）。
4. その他：C-1 用途1 編集UI／D タンク残量／Excel インポート／F 所要計算・発注点自動計算／H HULFT。
   - 一覧の正本＝`.kiro/docs/未実装案件一覧.md`（2026/07/13 最新化済・優先度表に K=agent-service-manager 完了・L=cleanup 完了・G=着手可・J 是正 を反映）。

### 運用メモ（継続）
- ワークスペースは `CoCore-Workspace.code-workspace`（Nonaka/clnCommonModule/WindowsService の3ルート・git 管理外）。
- spec は直接編集（サブエージェント不使用）。1ターン1タスク・削除系は承認後。ビルド/テストはユーザー。MainWeb/AuthModule/SharedCore/CommonModule 不変更。
- push は各 repo でユーザー実施（本日 push なし）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。次アクション＝(a) cleanup task8（ユーザーの JobQueue 導線解除SQL 適用）確認、(b) 次テーマ選択（別途整理／G 再開／E-A1 バグ 等）。

---

## 新規 spec `order-report-sender-info` 起草（要件フェーズ完了）

### 経緯・目的
- 発注書兼納入依頼書PDF の発注元（自社）情報を、発注者本人の SharedCore ユーザー情報（`ApplicationUser` ＝ dbAuthTest `m_user`）から取得。空白/NULL 項目は補完マスタからフォールバック。
- 補完マスタ `m_company_info` → **`m_general_personal_info`** に改名＋`email` 列追加。

### 調査で確定した事実（重要）
- 発注書PDF の発注元情報は現在 `OrderPdfService`（単票 `GenerateOrderPdfAsync`／グループ `GenerateGroupOrderPdfAsync`）で `IMasterService.GetCompanyInfoAsync(order.UserId)` → **`m_company_info`**（MaterialDbContext）から取得。郵便=ZipCode/住所=Address1/TEL=Tel/FAX=Fax/会社=CompanyName1/部署=DepartmentName1,2/受入工場=SimpleName。送付先TEL/FAX は t_orders 由来。
- **`t_orders.user_id` はログイン名（`User.Identity.Name` ＝ `ApplicationUser.UserName`）**。`Create.cshtml.cs` で確認。→ `IUserRepository.GetUserByIdAsync`（Id 一致）は不可。**`UserManager<ApplicationUser>.FindByNameAsync(user_id)`** で解決する（SharedCore 非改変で可）。
- pull 後 `ApplicationUser`（m_user）に **`postal_code`（郵便）・`address`（住所）・`employee_code`** が追加。既存 `fax_number`・`extension_number`＋標準 `PhoneNumber`・`Email` あり。→ 郵便/住所/TEL/FAX/氏名/メール が SharedCore から取得可能。ただし**会社名・工場名は ApplicationUser に無い**＝マスタが正。
- マイアカウント（`AuthModule/Areas/Identity/Pages/Account/Manage/Index`）は表示専用で Email/内線/FAX 等を ApplicationUser から表示。**編集UIは AuthModule（変更禁止）側**＝本 spec スコープ外。
- MaterialModule.csproj は SharedCore/CommonModule を ProjectReference 済み。`IUserRepository` 実装は SharedInfrastructure（MainWeb DI 登録）。

### requirements.md（作成済み・単一正本）
- 場所: `.kiro/specs/MaterialModule/order-report-sender-info/requirements.md`
- R1 SharedCore取得（FindByNameAsync・郵便/住所/TEL/FAX/担当）／R2 フィールド単位フォールバック（各項目独立・担当は user.LastName→t_orders スナップ／ユーザー未解決時は全項目マスタ）／R3 会社名/部署/受入工場はマスタ正（ApplicationUser に列なし）／R4 マスタ改名 m_general_personal_info＋email列＋エンティティ MGeneralPersonalInfo／R5 メールは今回PDF非出力（列保持のみ）／R6 マスタ解決キー=user_code一致→DEFAULT フォールバック（後方互換）／R7 clnCoCore非改変・編集UIスコープ外／R8 docs（テーブル定義書/ER図）。
- ※format診断4件（英語見出し欠如）は**リポジトリ全 spec 共通**（日本語見出し運用・許容）。既存 dispatches-section-filter でも同一診断を確認済み。

### 未確定（要件レビューでユーザー確認したい点）
- 会社名/工場名をマスタ正とする方針でよいか（将来 m_user へ寄せる予定の有無）。
- メールは今回PDF非出力（列追加のみ）でよいか。
- 担当のフォールバック順（user.LastName → t_orders スナップショット）でよいか。

### 次アクション
- 要件レビュー → design（撤去でなく差し替え中心・フォールバック解決の純粋ロジックを PBT 対象化候補）→ tasks。
- DBスキーマ変更（改名＋email）は適用SQLをタスクで用意し、実行はユーザー。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。order-report-sender-info：requirements 作成済み・design 未着手。cleanup spec は task8 完了で全完了・クローズ。

---

## order-report-sender-info：要件を更新（ユーザー確認反映）

- **会社名・工場名も SharedCore から取得**に訂正（当初「ApplicationUser に無い」は誤り）。発注者の**主所属 Section**経由：会社名=`Section.Company`／工場名=`Section.Office`。取得経路 `FindByNameAsync(user_id)`→`user.Id`→`IUserRepository.GetMainUserSectionAsync(user.Id)`→`Section`。空ならマスタ（company_name_1／department_name_1）へフォールバック。
- **担当**は `ApplicationUser.LastName`（姓のみ・サンプル「担当：宮下」）。空/未解決時のみ t_orders スナップショット。
- **email 列の用途確定**：PDF 非出力。**発注承認送信の差出人フォールバック**。From 解決順＝`m_send_config.from_address`→`ApplicationUser.Email`→マスタ`m_general_personal_info.email`→`FaxDispatchOptions.FromAddress`（`DispatchEnqueueService.EnqueueOrderApprovalFaxAsync` の fromAddress 解決に挿入）。
- requirements.md 更新済み（R1 SharedCore取得〔会社/工場/郵便/住所/TEL/FAX/担当〕・R2 フィールド単位FB・R3 受入工場=simple_name維持・R4 改名+email列・R5 送信差出人FB・R6 マスタキー・R7 スコープ・R8 docs）。

### ⏳ ユーザー確認中（design 着手前の最後の1点）
- 会社名の「株式会社」付き正式名称の扱い：(a) Section.Company をそのまま（差異はマスタで吸収）／(b) 会社名だけ常にマスタ company_name_1 を正。Section.Company の実データに「株式会社」が入るか次第。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：requirements 更新済み・上記1点の確認後に design 着手。

---

## order-report-sender-info：design・tasks 作成完了（spec 3点そろった）

- 方針確定：会社名は **(a) Section.Company そのまま**（空ならマスタ company_name_1）。**dbAuthTest 直接アクセス禁止**＝SharedCore 抽象（UserManager/IUserRepository）経由のみ（R7.3 追記）。
- design.md 作成：`ISenderInfoResolver`（FindByNameAsync→GetMainUserSectionAsync→GetGeneralPersonalInfoAsync）＋純粋ロジック `SenderInfoMerger.Merge`/`Coalesce`（PBT対象）→`SenderInfo` DTO。OrderPdfService 差し替え・DispatchEnqueueService 差出人FB（from_address→発注者Email→options.FromAddress）。エンティティ改名 MGeneralPersonalInfo＋email。正しさP1-4。
- tasks.md 作成：1 改名+email／2.1 DbSet・2.2 MasterService改名／3 SenderInfo／4 Merger／*5 Merger PBT／6 Resolver／7 DI／8.1・8.2 OrderPdf／9 Dispatch差出人FB／10 スキーマSQL（ユーザー適用）／11 ビルドCP（ユーザー）／12 docs＋依存グラフ。

### 実装ステータス
- requirements/design/tasks 完了・未着手（実装 task 1 から）。1ターン1タスク・削除/破壊系は承認後・ビルドはユーザー。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：spec 3点完了。次アクション＝実装 task 1（エンティティ改名＋email 列）から着手。

---

## order-report-sender-info：実装 task 1〜4 完了（2026/07/13）

- **task1 エンティティ改名+email**：`MCompanyInfo`→`MGeneralPersonalInfo`（新規ファイル `Data/Entities/MGeneralPersonalInfo.cs`・`[Table("m_general_personal_info")]`・`Email`列追加）。旧ファイル削除。型参照を全所（MaterialDbContext・MasterService・IMasterService・OrderPdfService×2・DispatchEnqueueService）で更新。
- **task2 DbContext/MasterService 追随**：2.1 DbSet `CompanyInfos`→`GeneralPersonalInfos`。2.2 `GetCompanyInfoAsync`→`GetGeneralPersonalInfoAsync`（戻り値 MGeneralPersonalInfo・DEFAULTフォールバック維持）＋呼出元3箇所追随。テストスタブ `StubMasterService`（Nonaka\MaterialModule.Tests\OrderApprovalFaxMail\DispatchEnqueueTestHarness.cs）も改名追随（CompanyResolver 型・メソッド名・cref）。
- **task3 SenderInfo DTO**：`Models/Dtos/SenderInfo.cs`（会社/工場/部署補足/郵便/住所/TEL/FAX/担当/受入工場）。
- **task4 SenderInfoMerger**：`Logic/SenderInfoMerger.cs`（`Coalesce`＝最初の非空白／`Merge`＝各項目独立FB・user/section/master null 安全）。
- 影響確認：PrintJobService は会社情報未使用（PDFはプロバイダ委譲）＝影響なし。clnCoCore\MaterialModule.Tests は `..\..\MaterialModule` 参照（編集対象一致）・会社情報未使用。全変更ファイル get_diagnostics クリア。
- grep が本 UNC 配下の .cs を拾わないため、参照確認は read/diagnostics で実施（メモ）。

### 残タスク（次）
- 5*（Merger PBT）／6（ISenderInfoResolver）／7（DI）／8.1・8.2（OrderPdf 差し替え）／9（Dispatch 差出人FB）／10（スキーマSQL）／11（ビルドCP=ユーザー）／12（docs）。

### ⚠ 注意（未適用）
- DBスキーマ変更（`sp_rename` + `email` 追加）は task10 でSQL用意→ユーザー適用。**コード（エンティティ）は既に `m_general_personal_info` 前提**なので、実行時までにDB改名が必要（ビルドは通るが、未改名DBでは実行時にテーブル不整合）。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：task1〜4 完了。次＝task5*/6/7/8/9/10、その後ユーザー task11 ビルドCP。

---

## order-report-sender-info：実装 task 5〜7 完了（2026/07/13）

- **task5* Merger PBT**：`MaterialModule.Tests/OrderReportSenderInfo/SenderInfoMergerPropertyTests.cs`。P3 Coalesce（最初の非空白/全空null）・P1 各項目独立フォールバック・P2 user=section=null で全マスタ＋担当スナップショット。FsCheck 生成器で user/section/master/snapshot を網羅（Nonaka\MaterialModule.Tests に配置＝既存 dispatch PBT と同居）。
- **task6 Resolver**：`Services/ISenderInfoResolver.cs`＋`SenderInfoResolver.cs`。`UserManager<ApplicationUser>`/`IUserRepository`/`IMasterService` 注入。FindByNameAsync→GetMainUserSectionAsync(user.Id)?.Section→GetGeneralPersonalInfoAsync→`SenderInfoMerger.Merge`。`ResolveSenderEmailAsync`=user.Email→master.Email。各SharedCore取得は try/catch＋Warning＋null継続（PDF/送信を止めない）。直接DBアクセスなし。
- **task7 DI**：`MaterialModuleExtensions` に `AddScoped<ISenderInfoResolver, SenderInfoResolver>()`。
- 全新規/変更ファイル get_diagnostics クリア。

### ⏳ ユーザー（ここで一度ビルド確認推奨）
- slnCoCore ビルドで task1〜7（改名・DTO・Merger・Resolver・DI）がコンパイル通ることを確認。※DB改名SQL未適用でもビルドは通る（実行時に必要）。

### 残タスク
- 8.1/8.2（OrderPdfService を SenderInfo 差し替え＝帳票出力挙動変更）／9（Dispatch 差出人FB）／10（スキーマSQL）／11（ビルドCP）／12（docs）。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：task1〜7 完了。次＝8.1/8.2（OrderPdf 差し替え）以降。

---

## ビルドエラー修正（task2 改名の波及漏れ・2026/07/13）

- 原因：`Areas/Material/Pages/Receivings/Index.cshtml.cs` の `OnGetExportPdfAsync`（入庫伝票PDF）が `MCompanyInfo`＋`masterService.GetCompanyInfoAsync(...)` を直接使用しており、task2 改名で未解決になった（会社情報 local `company` は当該PDF描画では未使用だがコンパイル対象）。
- 修正：`MGeneralPersonalInfo company = await masterService.GetGeneralPersonalInfoAsync(...)` に変更。診断クリア。
- 教訓：**grep_search は本 UNC 配下の MaterialModule .cs を検索できない**（nested git）。read_code のセレクタは「定義」検索でメソッド本体内の使用は拾わない。改名の波及確認は各ファイル本体の読み取りで行うこと。
- ビルドエラーは本1ファイル2件のみ（他は既存の警告：未使用パラメータ prefService/masterService/receivingService、null許容）。

### ⏳ ユーザー
- 再ビルドで task1〜7＋本修正が通ることを確認。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：task1〜7＋Receivings波及修正 完了。次＝再ビルド確認→task8.1/8.2。

---

## order-report-sender-info：実装 task 8〜10・12 完了（2026/07/13）＝実装ほぼ完了

- **task8 OrderPdfService 差し替え**：`ISenderInfoResolver` 注入（`IMasterService` 依存を除去）。単票/グループとも右上ブロックを `SenderInfo` で構築（会社=CompanyName/工場=FactoryName/部署補足=DepartmentSub/〒ZipCode Address/TEL・FAX/担当=Contact）＋問合せ文言＝Contact。単票の「受入工場」＝ReceivingFactory（simple_name）。`using MaterialModule.Models.Dtos;` 追加。
- **task9 Dispatch 差出人FB**：`DispatchEnqueueService` に `ISenderInfoResolver` 注入。差出人解決を**グループ単位**で `Coalesce(m_send_config.from_address, ResolveSenderEmailAsync(head.UserId), FaxDispatchOptions.FromAddress)` に変更（従来の外側一括 fromAddress を廃し head 単位に）。`using MaterialModule.Logic;` 追加。
  - テストハーネス追随：`StubSenderInfoResolver`（EmailResolver 既定null）追加・`BuildService` へ引数追加。`WhenFromAddressUnavailable` テストを是正（SendConfig.FromAddress/Options.FromAddress/EmailResolver すべて null にして「全経路未解決→スキップ」を正しく検証）。※ハーネス既定 SendConfig.FromAddress が入っており従来から意図と不整合だった点を是正。
- **task10 スキーマSQL**：`MaterialModule/docs/sql/rename_m_company_info_to_general_personal_info.sql`（db_material_dev・存在チェック付き冪等：sp_rename＋email 追加＋確認SELECT）。**適用はユーザー**。
- **task12 docs**：`テーブル定義書.md`（セクション改名＋email 行＋各項目に「正/FB」注記・一覧エントリ改名）／`ER図.md`（一覧行改名）／`ER図.mmd`（エンティティ改名＋email）反映。
- 全変更ファイル get_diagnostics クリア。

### 実装ステータス
- **task 1〜10・12 完了**。残＝**task11（ユーザー）＝ビルド＋SQL適用＋実機確認**、task5* PBT はユーザー実行で緑確認。

### ⏳ ユーザー（task11 CP）
1. slnCoCore 再ビルド（OK 期待）。
2. **`rename_m_company_info_to_general_personal_info.sql` を db_material_dev に適用**（改名＋email 列）。※適用しないと実行時にテーブル不整合。
3. 発注書PDF（単票/グループ）で発注元＝発注者の m_user/所属 由来（郵便/住所/TEL/FAX/会社/工場/担当）＋空欄はマスタ補完を確認。宛先未設定FAXの差出人FB（発注者Email）も任意確認。
4. `dotnet test`（Nonaka\MaterialModule.Tests）で SenderInfoMerger PBT 緑を確認（当該テスト projectは slnCoCore 未参照のため個別実行）。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：実装 task1〜10・12 完了。残＝ユーザーの task11（ビルド/SQL適用/実機/テスト）。

---

## 〒重複の是正（既存バグ・2026/07/13）

- 事象：発注元の郵便が「〒〒660-8577」と二重表示。原因はテンプレートで `〒` を前置しつつ、郵便番号データ（m_user.postal_code / マスタ zip_code）側にも `〒` が含まれていたため。
- 修正：`OrderPdfService`（単票・グループ両方）で `〒{(sender.ZipCode ?? "").TrimStart('〒', ' ', '　')} {Address}` とし、先頭の 〒・半角/全角空白を除去してから 〒 を1つだけ前置。データに 〒 有無どちらでも1つになる。診断クリア。
- 実機確認：担当＝ログインユーザーの ApplicationUser.LastName（例「大西」）が反映＝SharedCore取得は動作OK。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：実装 task1〜10・12＋〒是正 完了。残＝ユーザー task11（ビルド/SQL適用済みなら実機再確認・テスト）。

---

## 〒重複 再是正（2026/07/13・2回目）

- 1回目の TrimStart 版でも重複が残ったとの報告。より確実に `OrderPdfService`（単票・グループ両方）で `(sender.ZipCode ?? "").Replace("\u3012", "").Trim()`（〒=U+3012 を位置問わず全除去）してから 〒 を1つ前置に変更。診断クリア。
- 重要：**PDF はサーバ側(MainWeb)生成のため、コード反映には再ビルド＋アプリ再起動が必要**。前回 FAX 番号だけ変わったのは DB データ差（再ビルド不要）で、〒修正コードが未ロードだった可能性大。ユーザーに再ビルド＋再起動を依頼。
- なお残る場合は postal_code/zip_code の実値（先頭文字コード）確認 → 除去対象に追加。

### 再開合図
「再開します、session-memoを確認」。order-report-sender-info：実装完了＋〒是正(2回目)。残＝ユーザー再ビルド/再起動で〒単一化確認・task11。

---

## 🔴 本日のクローズ・チェックポイント（2026/07/13 終了）

### 完了（確認OK・コミット待ち）
- **order-report-sender-info（新規spec・実装完了）**：発注書兼納入依頼書PDF の発注元情報を発注者本人の SharedCore（`ApplicationUser`＋主所属 `Section`）から取得、空/NULL 項目のみ補完マスタへフィールド単位フォールバック。dbAuthTest 直接アクセスなし（`UserManager`/`IUserRepository` 経由）。
  - task1〜10・12 実装完了、task11（ビルド/SQL適用/実機/〒是正）ユーザー確認 **OK**。task5* PBT 実装済（Nonaka\MaterialModule.Tests・個別実行）。
  - 変更: エンティティ `MCompanyInfo`→`MGeneralPersonalInfo`（`m_general_personal_info`・`email`列追加）／DbSet・MasterService 改名／`SenderInfo` DTO／`SenderInfoMerger`（純粋・PBT）／`ISenderInfoResolver`/`SenderInfoResolver`／DI／`OrderPdfService` 単票・グループ差し替え／`DispatchEnqueueService` 差出人FB（from_address→発注者Email→options）／Receivings 入庫伝票PDF の会社情報参照 追随／スキーマSQL／docs（テーブル定義書・ER図）。
  - 〒重複是正：`〒{(ZipCode).Replace("\u3012","").Trim()}`（単票/グループ）。実機で単一化・担当＝ログインユーザー姓 確認OK。
  - DB：`rename_m_company_info_to_general_personal_info.sql` 適用済（改名＋email）。
- **Orders/Create 申請ボタン**：ヘッダ左側へ移動＋ラベルと位置入替（左＝「申請」→「エントリリスト（N件）」）。確認OK。
- **materialmodule-legacy-cleanup**：task8（JobQueue導線解除SQL）適用済でクローズ済（前記）。

### コミット（未・ユーザー承認で）
- MaterialModule：エンティティ改名/DbContext/MasterService/SenderInfo・SenderInfoMerger・ISenderInfoResolver/SenderInfoResolver/DI/OrderPdfService/DispatchEnqueueService/Receivings/Create.cshtml/docs sql。
- Nonaka/.kiro：order-report-sender-info spec 3点・テーブル定義書・ER図(.md/.mmd)・本memo。
- ※テスト（Nonaka\MaterialModule.Tests）は従来どおり git 管理外運用。

### 次テーマ候補（未着手）
- G 原材料 計画単価・計画数量＋実績対比分析（要件再開候補）／E-A1 入庫ステータス色バグ／MaterialModule.Tests 二重・stray 複製整理。正本＝`.kiro/docs/未実装案件一覧.md`。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。order-report-sender-info 実装・実機OK。次テーマ未定。

---

## 🟡 次テーマ：印刷（PDF出力）方式の協議メモ（2026/07/13・未確定・spec未着手）

前提：ユーザーは「印刷・SMTP送信テスト機能」を実装予定。その前段として **PDF印刷方式の方針協議**を実施。要件確定は次回。

### 確定した技術評価（事実）
- **ブラウザ単体ではサイレント（ダイアログなし）印刷は不可**（仕様上ブロック。Chrome kiosk 等は業務常用に不適）。無確認印刷＝**PrintAgent 一択**。
- 現行 **PrintAgent サイレント印刷の実挙動**（`\\...\WindowsService\PrintAgent`）:
  - `Services/SilentPrintService.cs`：`SumatraPDF.exe -print-to "プリンタ名" -silent -exit-when-done [.-print-settings "Nx"]`。**必ずプリンタ名指定**（-print-to-default は使っていない）。
  - `Workers/PrintJobWorker.cs`：`t_print_queue` を print_status=1 でポーリング。プリンタ解決＝**printer_name 指定→当該／NULL→サーバ既定（config `PrintAgent:DefaultPrinterName`）**。**指定済みだが稼働機に未インストール→status=9 エラー（既定へフォールバックしない）**。存在判定は `PrinterSettings.InstalledPrinters` 実列挙。
  - → 「未到達/未インストール時もサーバ既定へ」を望むなら **PrintAgent 改修が必要**（別repo/別spec）。
- **CommonModule（Nonaka\CommonModule）の公開状況**（MaterialModule は ProjectReference 済）:
  - 投入：`IPrintQueueService.EnqueueAsync(module, reportType, referenceCode, pdfPath, printerName?, copies, ct)` … **printer_name 指定投入可**。
  - プリンタ一覧：**read 用の公開I/Fは無し**。データは `m_printer`（`CommonDbContext.Printers`・PrintAgent 棚卸しが投入）に在るが外部提供I/F未整備。
  - `CommonDbContext` DbSet：SmtpQueue/SmtpConfigs/SmtpAgentControls/PrintQueue/PrintAgentControls/**Printers(m_printer)**/SendConfigs。
- MaterialModule 側 PDF 保管：`m_print_output_path` で固定管理（`\\OJIADM23120073\app_share\PrintAgent\`）。全帳票PDF保持。
- 現状 MaterialModule の印刷投入：`PrintJobService.CreateOrderApprovalJobsAsync` は `printerName: null`（＝サーバ既定）で投入。OutputType 0=保存のみ/1=印刷/2=FAX(印刷スキップ)/3=印刷+FAX。

### 方針の転換（ユーザー最新の考え）＝ジョブを出力先性質で二分
- **(A) サイレントPDF出力Job（他部署／共有プリンタ）**：出力先＝**サーバ登録済みプリンタ**（例 Printer_D）。経路＝**PrintAgent**（printer_name 指定・無確認）。単位は**個人でなく帳票/部署等**で管理者割当（要確認②）。
- **(B) ローカルPCのデフォルトプリンタへ出力するJob**：操作ユーザー自身の端末既定プリンタ。方式2択（**要確認①**）:
  - (B-1) ブラウザ経路（推奨）：PDF生成→表示/DL→**印刷ダイアログで既定プリンタへ**。サーバ登録不要・導入ゼロ・**ダイアログは出る**。CommonModule連携も個人登録も不要。
  - (B-2) サイレント維持：各ユーザーのローカル既定を共有＋PrintAgent機に登録＋個人マッピング（運用重い）。
- **Dispatches は (A)＋(B) の2カ所出力**（Printer_D サイレント＋手元既定）。

### 対象帳票（ユーザー提示の表）
- (B) ローカル既定：Orders/Create=発注書兼納入仕様書／Receivings=入庫伝票／Dispatches=原材料工場入請求。PDF保管=`\\OJIADM23120073\app_share\PrintAgent\`。
- (A) サーバ登録：Dispatches=原材料工場入請求→Printer_D（サーバサイド登録プリンタ）。
- Orders/Create の適用＝「出力区分(OutputType)に準ずる」。

### デュアル方式の暫定ポリシー（ユーザー回答済み・(B)方式のみ未確定）
1. サイレント対象プリンタの登録単位＝当初「個人」→ 転換後は (A)=帳票/部署単位・(B-1)なら登録不要（**②で再確認**）。
2. モード選択の主体＝**管理者**（ユーザーにサーバ登録をさせない）。
3. フォールバック＝未登録(printer_name 空)→サーバ既定（現行と一致）。未到達→現行はエラー（(a)既定フォールバックはPrintAgent改修／(b)エラー通知 の判断＝**要確認**）。
4. 対象帳票＝上記表。
5. PDF出力ダイアログなし可否＝**ブラウザは不可・PrintAgentのみ可**（回答済）。PDF保管先＝固定（回答済）。

### 🔴 次回の確定すべき事項（要件クローズ前）
- **①(B) の方式**：B-1（ブラウザ・ダイアログあり・登録不要／推奨）か B-2（サイレント・個人登録あり）か。
- **②(A) の割当単位**：帳票ごと／部署（送付先/工場）ごと（個人ではない）で良いか。
- **③ Dispatches 2カ所出力**：(A)Printer_D サイレント＋(B)手元既定 で確定か。
- **④ 未到達時フォールバック**：サーバ既定へ(要PrintAgent改修) か エラー通知留め か。
- **⑤ CommonModule への read I/F 追加可否**：`IPrinterQueryService.GetAvailablePrintersAsync(machineName?)`（m_printer 読み取り公開）を許可するか。許可しない場合は MaterialModule に db_common `m_printer` 読み取り専用 DbContext（インターフェース経由でない点がトレードオフ）。※(B-1)採用なら (A) 用途に限定。
- **⑥ (A) 割当マスタの所属**：MaterialModule 側テーブル（例 `m_print_routing`：report_type/section→printer_name 等）で持つ想定。
- **⑦ SMTP送信テスト機能**：当初ユーザーが挙げた「印刷・SMTP送信テスト機能」の要件は未着手（別途 or 本テーマと統合か要整理）。CommonModule 側に `docs/smtp-sender実送信テスト手順.md`・`SendConfig` テスト送信（TestFaxNumber/TestEmail）既存あり。

### 想定 spec 分割（未作成）
- CommonModule spec：プリンタ一覧 read I/F 追加（(A)用・⑤次第）／必要なら PrintAgent 未到達フォールバック改修（④次第・PrintAgent repo）。
- MaterialModule spec：(A) 割当＋PrintAgent投入／(B) ブラウザ印刷導線／Dispatches 2カ所出力／OutputType連動／PDF保管固定。

### 参照ファイル（今回確認済み）
- `WindowsService\PrintAgent\Services\SilentPrintService.cs`・`Workers\PrintJobWorker.cs`・`Models\MPrinter.cs`。
- `Nonaka\CommonModule\Services\IPrintQueueService.cs`・`Data\CommonDbContext.cs`・`Data\Entities\MPrinter.cs`・`TPrintQueue.cs`。
- `MaterialModule\Services\PrintJobService.cs`・`ApprovalReportPdfProvider.cs`・`DispatchEnqueueService.cs`。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260713）。次回＝上記①〜⑦を確定 → CommonModule（一覧I/F）→ MaterialModule（A/B・2カ所出力）の順で spec 起票。※order-report-sender-info は実装完了・コミット済み（MaterialModule ab73774／Nonaka 564aa61）。
