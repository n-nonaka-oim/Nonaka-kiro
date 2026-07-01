# セッション備忘録（2026/06/20 - smtp-sender 実装着手: タスク1（DDL/ドキュメント）完了・タスク2（CommonModule/エンティティ/DbContext）完了）

## 前提（前回6/19からの継続）
- 6/19: SMTP送信汎用基盤(smtp-sender)の Spec（要件/設計/タスク）を完成。`.kiro/specs/smtp-sender/` 正本 + `MaterialModule/Doc/specs/smtp-sender/` コピー。
- 本日: tasks.md タスク1・タスク2 を実装着手し完了。実装はオーケストレーター方式（spec-task-execution サブエージェントに委譲）で実施。
- ビルド・DDL実行はユーザー側（プロジェクトルール）。本日は**まだビルド・DDL実行とも未実施**。

## 本日の完了作業

### タスク1: DBスキーマDDLとドキュメント整備（共通DB db_common_dev）完了
作成・更新ファイル（すべて `MaterialModule/Doc/sql/`）:
- `create_t_smtp_queue.sql`（新規）— 共通送信キュー。16列 + CHECK制約(status IN (1,2,3,9)) + インデックス2本（ix_t_smtp_queue_status_created (status, created_at) / ix_t_smtp_queue_module (module)）
- `create_m_smtp_config.sql`（新規）— 接続プロファイルマスタ（複数行）。config_key(PK)/host/port/fax_domain のみ
- `create_m_smtp_agent_control.sql`（新規）— 死活監視（1行運用）。初期1行INSERT付き
- `insert_m_smtp_config.sql`（新規）— 接続プロファイル例データ（Material: fax_domain=@faxmail.com / test: fax_domain空）。host=172.16.128.81, port=25
- `test_smtp_send.sql`（更新）— **t_smtp_queue版へ全面書き換え**。USE db_common_dev / config_key=test / 添付なし(パターンA)・PDF添付あり(パターンB)両方。テスト宛先 nonaka8722505@oji-gr.com
- 各CREATEスクリプト冒頭に「実行はユーザーが db_common_dev に対して行う」旨コメント明記

ドキュメント更新:
- `MaterialModule/Doc/テーブル定義書.md` — 「共通DB（db_common_dev）— SMTP送信汎用基盤」セクション追加（3テーブルの列定義表 + インデックス表 + 例データ表）。db_material_dev側の旧 m_smtp_config(1行版)/m_smtp_agent_control は並行運用の従来テーブルとして別物である旨を注記（既存内容は削除せず）
- `MaterialModule/Doc/ER図.md` — Mermaid で `m_smtp_config ||--o{ t_smtp_queue : "config_key"` を追記。m_smtp_agent_control は独立（リレーションなし）と明記。テーブル分類にも共通DB3テーブルを追加

### タスク2: CommonModule プロジェクト + 共通エンティティ + DbContext 完了
新規プロジェクト `CommonModule`（配置: `\\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\CommonModule\` = MaterialModule と同じ親フォルダ）:
- `CommonModule.csproj` — net8.0 / Microsoft.NET.Sdk.Razor / Nullable+ImplicitUsings enable / AddRazorSupportForMvc / FrameworkReference Microsoft.AspNetCore.App / EF Core(+SqlServer) 8.0.* / ProjectReference SharedCore / InternalsVisibleTo CommonModule.Tests
- `README.md` — CommonDb接続前提・タスク範囲・後続タスク区分
- `Areas/Common/Pages/_ViewImports.cshtml`（@namespace CommonModule.Areas.Common.Pages）/ `_ViewStart.cshtml`（Layout="_Layout"）/ `.gitkeep`
- **slnCoCore.sln に登録済み**: Project行（SmtpAgentの直後）GUID `{6E196B25-6418-4019-9EEB-9F787BD77CA7}` + ProjectConfigurationPlatforms（Debug/Release × AnyCPU/x64/x86、全て Any CPU にマップ）

共通エンティティ（`CommonModule/Data/Entities/`、名前空間 CommonModule.Data.Entities、DDLと列名・型完全一致）:
- `TSmtpQueue.cs` — [Table("t_smtp_queue")]。Id(IDENTITY,PK)/Module/ConfigKey/FromAddress/FromName?/Recipient/Subject/Body?(nvarchar max)/PdfPath?/Status(既定1)/PickedAt?/CompletedAt?/ErrorMessage?/CreatedAt/UpdatedAt/RowVersion([Timestamp] byte[])
- `MSmtpConfig.cs` — [Table("m_smtp_config")]。ConfigKey(PK)/Host/Port(既定25)/FaxDomain?。row_version等は持たせない
- `MSmtpAgentControl.cs` — [Table("m_smtp_agent_control")]。Id(IDENTITY,PK)/LastHeartbeatAt?/MachineName?/UpdatedAt

DbContext:
- `CommonModule/Data/CommonDbContext.cs` — 名前空間 CommonModule.Data。DbSet 3つ（SmtpQueue/SmtpConfigs/SmtpAgentControls）。SMTP系3テーブルのみ、資材固有テーブル非依存。OnModelCreating なし（マッピングはエンティティの DataAnnotations に委ねる）

- 全ファイル getDiagnostics エラーなし。**ビルドは未実行**。

## 次回タスク（最優先）
**まず CommonModule をクリーンビルドして通ることを確認**（新規プロジェクト追加直後のため。site.cssは変更しない/Worker起動中はexeロックでビルド不可）。
ビルドOK後の順序（依存グラフ準拠）:
1. **タスク3: 投入ヘルパー ISmtpQueueService**（CommonModule側を自己完結させる）
   - 3.1 ISmtpQueueService / SmtpQueueService（EnqueueAsync。status=1, created_at==updated_at=now でINSERT。module/configKey/fromAddress/recipient/subject の空文字バリデーション→ArgumentException。config_key実在チェックはWorker側）
   - 3.2* 投入不変条件PBT（Property 1、EF Core InMemory、100イテレーション）
   - 3.3 CommonModuleExtensions.AddCommonModule(configuration)（CommonDbContext・ISmtpQueueService・Area登録）+ MainWeb の ModuleRegistration.AddModules に AddCommonModule 追加・CommonDb 接続文字列注入
2. **タスク1のDDLを db_common_dev に実行**（タスク4の前提。create 3本 → insert_m_smtp_config）
3. **タスク4: SmtpAgent改修**（別sln。TSmtpQueue/MSmtpConfigエンティティ・SmtpAgentDbContext差し替え・接続先 db_common_dev・PDFディレクトリ共通設定廃止）
4. タスク5（送信サービス）→ 6（Worker）→ 8（監視画面 SmtpMonitor）→ 10（統合テスト・Spec同期）

## EnqueueAsync シグネチャ（再掲・使用側IF）
`EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body?, pdfPath?)`

## 注意（継続）
- ビルド・DDL実行・動作確認はユーザー側。新規プロジェクト/Razorページ追加時はクリーンビルド必須。Worker起動中はexeロックでビルド不可（停止してから）。
- SQL実行時は接続DBを確認（db_common_dev / db_material_dev を取り違えると「オブジェクト無効」エラー）。新基盤の3テーブルは **db_common_dev**。
- SmtpAgent/appsettings の SkipSend は実送信時 false。送信テスト後は true に戻す等で誤送信防止。
- 共有フォルダ: \\OJIADM23120073\app_share\PrintAgent（PDF保管）。
- SMTP: 172.16.128.81:25 / 暗号化なし・認証なし・固定IP許可 / FAXドメイン @faxmail.com。
- DB: OJIADM23120073\DEVELOPMENT。
- slnCoCore.sln: \\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\clnCoCore\slnCoCore.sln（CommonModule 追加済み）。
- 並行運用: 既存 t_order_reports.fax_status 経路・既存Print/Smtpページ・db_material_dev側の旧smtpテーブルは削除せず残す。

## Spec進捗（.kiro/specs/smtp-sender/tasks.md）
- タスク1（1.1/1.2/1.3）完了 ✓
- タスク2（2.1/2.2/2.3）完了 ✓
- 次: タスク3（3.1/3.2*/3.3）から。tasks.md を開いて Start task、または該当タスクから再開。
- 注: tasks.md 本体のチェックボックス状態はタスク管理ツール側で更新済み。`MaterialModule/Doc/specs/smtp-sender/tasks.md`（コピー）へのチェック状態同期は未実施（実装本体未完のため、タスク10.4のSpec同期で一括反映予定）。

## 主要変更ファイル（本日）
- `MaterialModule/Doc/sql/create_t_smtp_queue.sql`（新規）
- `MaterialModule/Doc/sql/create_m_smtp_config.sql`（新規）
- `MaterialModule/Doc/sql/create_m_smtp_agent_control.sql`（新規）
- `MaterialModule/Doc/sql/insert_m_smtp_config.sql`（新規）
- `MaterialModule/Doc/sql/test_smtp_send.sql`（更新: t_smtp_queue版）
- `MaterialModule/Doc/テーブル定義書.md`（共通DB3テーブル追記）
- `MaterialModule/Doc/ER図.md`（共通DBリレーション追記）
- `CommonModule/CommonModule.csproj`（新規プロジェクト）
- `CommonModule/README.md`（新規）
- `CommonModule/Areas/Common/Pages/_ViewImports.cshtml`・`_ViewStart.cshtml`・`.gitkeep`（新規）
- `CommonModule/Data/Entities/TSmtpQueue.cs`・`MSmtpConfig.cs`・`MSmtpAgentControl.cs`（新規）
- `CommonModule/Data/CommonDbContext.cs`（新規）
- `clnCoCore/slnCoCore.sln`（CommonModule 登録）

## 申し送り
- 本日: smtp-sender の実装に着手。タスク1（DDL/例データ/テストSQL/テーブル定義書/ER図）とタスク2（CommonModule新規プロジェクト/共通エンティティ3種/CommonDbContext）を完了。ビルド・DDL実行は未実施。
- 次回: まず CommonModule のクリーンビルド確認 → タスク3（ISmtpQueueService + MainWeb登録）→ DDL実行 → タスク4（SmtpAgent改修）。新セッションは「再開します、session-memoを確認」で本ファイルから。
