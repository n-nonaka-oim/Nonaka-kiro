# セッション備忘録（2026/06/26 - smtp-sender 実送信検証(添付/FAX)完了 / タスク10.4 Spec同期完了 / CC・BCC・複数宛先対応のSpec(req/design/tasks)策定完了）

## 前提（前回6/25からの継続）
- 6/25: タスク8（共通監視画面 SmtpMonitor）実装完了・CommonModuleビルドOK。
- 本日: タスク9（CommonModule.Tests 全緑=6件）確認 → タスク10.4（Spec同期）→ 実送信テスト（添付/FAX）実機OK → CC/BCC・複数宛先対応のSpec策定（req/design/tasks）まで。

## 本日の作業

### 1. タスク9（チェックポイント）完了
- CommonModule.Tests 実行: **合計6・成功6・失敗0**（Property 1/10/12/13 + error_message）。タスク8/9 完了。

### 2. タスク10.4（Spec同期）完了
- `.kiro/specs/smtp-sender/` の requirements/design/tasks を `MaterialModule/Doc/specs/smtp-sender/` へ同期。
- その際、正本 tasks.md のチェックボックスを実態へ更新（タスク1〜9完了・10.4完了）。タスク管理ツール未使用分を手動反映。

### 3. 実SMTP送信テスト（実機）—全OK
- 手順書作成: `MaterialModule/Doc/smtp-sender実送信テスト手順.md`。
- パターンA 添付なし直送（config_key=test）→ 着信OK。
- パターンB PDF添付あり → 着信OK。
- 実FAX送信（config_key=Material・fax_domain=@faxmail.com・宛先@なしFAX番号）→ **FAX送信OK**。ハイフン入りFAX番号→数字抽出+先頭0→81+@faxmail.com 変換を確認。
- → 要件5.3/5.4 の実地確認（タスク10.1相当）は実機で達成。

### 4. 【本日のメイン】CC/BCC・複数宛先（;区切り）対応の Spec 策定（req→design→tasks）
ユーザー要望: 宛先以外に CC/BCC を追加、宛先が複数の場合の区切りは「;」。

**確定仕様（ユーザー合意済み・推奨案）**
- To/CC/BCC とも「;」区切りで複数指定可。
- CC/BCC はメールアドレス前提（FAX正規化しない。@必須想定）。
- To に複数FAX番号を;区切り→各トークンを既存解決ロジックで個別正規化。
- CC/BCC は空可（NULL/空ならヘッダ付与しない）。
- スキーマ: t_smtp_queue に `cc` `bcc` nvarchar(1000) NULL 追加、`recipient` を nvarchar(256)→nvarchar(1000) 拡張。**既存テーブルなので ALTER TABLE で適用**。

**requirements.md 更新（正本+Docコピー同期済み）**
- Glossary: To/CC/BCC・宛先トークン・複数宛先区切り(;) 追加。
- Requirement 3: AC1に cc/bcc 追記、AC8-12 追加（recipient桁・cc/bcc列・NULL許容・EnqueueAsync任意引数・;値そのまま登録）。
- Requirement 6: AC9-13 追加（recipientを;分割・trim・空除外、各トークンに解決ロジック適用、To複数設定、有効0件はエラー9）。
- Requirement 13 新規: CC/BCC付与（;分割・trim・空除外、FAX正規化せずメールアドレスとしてそのまま、NULL/空はヘッダなし）。

**design.md 更新（正本+Docコピー同期済み）**
- Overview にキー変更点8（複数宛先・CC/BCC・ALTER方針）追加。
- Data Models: t_smtp_queue に cc/bcc 追加・recipient nvarchar(1000)。ALTERマイグレーションSQL明記:
  - `ALTER TABLE t_smtp_queue ADD cc nvarchar(1000) NULL;`
  - `ALTER TABLE t_smtp_queue ADD bcc nvarchar(1000) NULL;`
  - `ALTER TABLE t_smtp_queue ALTER COLUMN recipient nvarchar(1000) NOT NULL;`
- 最終シグネチャ確定:
  - `EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body?=null, cc?=null, bcc?=null, pdfPath?=null, ct=default)`
  - `ResolveToAddress(profile, recipientToken)` ← **1トークン解決の純粋関数のまま維持**（;分割はWorker側）
  - `BuildMessage(profile, fromAddress, fromName, IReadOnlyList<string> toAddresses, ccAddresses, bccAddresses, subject, body, pdfPath)`
  - `SendMail(...同上...)`
- Property追加: **Property 14（複数To解決＝各有効トークンのResolveToAddress結果集合と一致）**、**Property 15（CC/BCC付与の同値）**。Property 6 に「;分割後有効0件」統合。Property 5/7/9 を BuildMessage 参照に更新。
- 設計判断: ResolveToAddressは1トークン純粋関数維持、;分割・trim・空除外・ヘッダ付与はWorker/BuildMessageが担当（関心分離）。

**tasks.md 更新（正本+Docコピー同期済み）**
- 既存タスク1〜11は無変更（完了状態保持）。
- **タスク12（CC/BCC・複数宛先対応）11サブタスク追加**:
  - 12.1 ALTER DDL作成 / 12.2 テーブル定義書・ER図更新 / 12.3 CommonModuleエンティティ(Cc/Bcc追加・Recipient1000) / 12.4 EnqueueAsync改修 / 12.5* Property1拡張(cc/bcc保持) / 12.6 SmtpAgentエンティティ更新 / 12.7 ISmtpSendService(BuildMessage/SendMailリスト化・ResolveToAddress維持) / 12.8* Property5/7/9追従修正 / 12.9 SmtpJobWorker改修(;分割→To/CC/BCC構築) / 12.10* Property14 / 12.11* Property15
  - タスク13 チェックポイント / タスク14（14.1* 実送信手順にCC/BCC・複数宛先版追記、14.2 Spec再同期）
- 依存グラフ wave15〜19 追加。Property総数 13→15。

## 現在のSpec進捗（.kiro/specs/smtp-sender/tasks.md）
- タスク1〜9 完了 ✓（基盤・投入・SmtpAgent・送信・Worker・監視画面、全テスト緑）
- タスク10: 10.4(Spec同期)完了 ✓。10.1〜10.3(*統合テスト)は未（10.1相当の実送信は実機確認済み）。
- タスク11（最終チェックポイント）未。
- **タスク12（CC/BCC・複数宛先）・13・14 = 新規追加・未着手 ← 次回実装**。

## 次回タスク（最優先: タスク12 CC/BCC・複数宛先 実装）
実装順（依存グラフ wave15〜19）。**実装はサブエージェント委譲、ビルド/DDL/テストはユーザー側**。
1. 12.1 ALTER DDL作成（`MaterialModule/Doc/sql/` に alter_t_smtp_queue_cc_bcc.sql 等）→ ユーザーが db_common_dev に実行
2. 12.2 テーブル定義書(cc/bcc追記・recipient桁更新)・ER図
3. 12.3 CommonModule/Data/Entities/TSmtpQueue.cs（Cc/Bcc追加・Recipient MaxLength1000）
4. 12.6 SmtpAgent/Models/TSmtpQueue.cs（同上・Web側と一致）
5. 12.4 ISmtpQueueService/SmtpQueueService EnqueueAsync（cc/bcc引数）
6. 12.7 ISmtpSendService/SmtpSendService（BuildMessage/SendMailをTo/CC/BCCリスト化、ResolveToAddressは1トークン維持）
7. 12.9 SmtpJobWorker（recipient;分割→To構築、cc/bcc;分割→CC/BCC構築、有効0件/例外=status9）
8. 12.5*/12.8*/12.10*/12.11* テスト（Property1拡張・5/7/9追従・14・15）
9. タスク13 チェックポイント（両sln ビルド＋テスト）
10. タスク14（実送信手順CC/BCC版追記・Spec再同期）

## 注意（継続）
- ビルド・DDL・テスト実行はユーザー側。新規Razorページ/プロジェクト追加時はクリーンビルド。Worker起動中はexeロックでビルド不可。
- **タスク12の ALTER は既存 t_smtp_queue に対して実行**（新規CREATEではない）。db_common_dev。recipientは既存データがあれば桁拡張のみ（縮小でないので安全）。
- Web側(CommonModule)とWorker側(SmtpAgent)のエンティティは**同一テーブルにマップ**。Cc/Bcc/Recipient桁は両方一致させること。
- BuildMessage/SendMail のシグネチャ変更で既存テスト(Property5/7/9)・Workerが影響→12.7/12.8/12.9で追従必須（コンパイル維持）。
- Kiro: アップグレード時は settings.json `http.proxy=http://sysproxy.oji-gr.com:80`（再発防止。詳細 maintenance-kiro-signin-20260623.md）。
- 新基盤3テーブルは db_common_dev。SMTP: 172.16.128.81:25 / @faxmail.com。共有 \\OJIADM23120073\app_share\PrintAgent。
- slnCoCore.sln: MainWeb/CommonModule/CommonModule.Tests。SmtpAgent.sln: SmtpAgent/SmtpAgent.Tests（別sln、\\OJIADM23120073\Labs\WindowsService\）。
- EnqueueAsync 最新IF: `EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body?, cc?, bcc?, pdfPath?)`。

## 主要変更ファイル（本日）
- `.kiro/specs/smtp-sender/requirements.md`・`design.md`・`tasks.md`（CC/BCC・複数宛先 反映）＋ `MaterialModule/Doc/specs/smtp-sender/` 同期コピー
- `MaterialModule/Doc/smtp-sender実送信テスト手順.md`（新規・実送信手順）
- （実装は次回。本日コード変更なし。Spec/手順書のみ）

## 申し送り
- 本日: タスク9完了・10.4 Spec同期・実送信(添付/FAX)実機OK。CC/BCC・複数宛先対応の Spec(req/design/tasks) を策定（Property 14/15追加、ALTER方針、シグネチャ確定）。
- 次回: **タスク12（CC/BCC・複数宛先）の実装に着手**（12.1 ALTER DDL から）。実装後ユーザーが ALTER実行→両slnビルド→テスト。
- 新セッションは「再開します、session-memoを確認」で本ファイルから。

---

## 追記（同日・継続セッション - タスク12 CC/BCC・複数宛先 実装完了）

### 本日の作業（前述のSpec策定に続く実装）
前回までで策定済みだった「CC/BCC・複数宛先(;区切り)対応」のSpec(タスク12〜14)を**実装完了**した。実装はサブエージェント委譲、tasks.md チェックボックスは直接更新（task管理ツールは引き続き未使用）。依存グラフ wave15〜19 の順で実施。

#### 完了タスク（すべて [x] 化済み・正本+コピー両方同期済み）
- **12.1** ALTER DDL作成: `MaterialModule/Doc/sql/alter_t_smtp_queue_cc_bcc.sql`（新規）
  - `cc nvarchar(1000) NULL` 追加 / `bcc nvarchar(1000) NULL` 追加 / `recipient` を `nvarchar(1000) NOT NULL` へ桁拡張
  - `COL_LENGTH` 冪等ガード付き、`USE db_common_dev; GO`。**新規CREATEではなくALTER**（既存テーブル前提）。実行はユーザー側
- **12.2** テーブル定義書更新: `t_smtp_queue` に cc/bcc 列追記・recipient を nvarchar(1000) に更新。ER図は列追加のみで参照関係に影響なく変更不要と判断
- **12.3 / 12.6** 両側エンティティ更新（同一テーブル `t_smtp_queue` に同一列マップ）
  - `CommonModule/Data/Entities/TSmtpQueue.cs` ・ `\\OJIADM23120073\Labs\WindowsService\SmtpAgent\Models\TSmtpQueue.cs`
  - Cc/Bcc（`[Column]`/`[MaxLength(1000)]`/`string?`）追加、Recipient を MaxLength(1000) に変更
- **12.4** `CommonModule/Services/ISmtpQueueService.cs`・`SmtpQueueService.cs`: EnqueueAsync に `cc`/`bcc`（既定null、body の後・pdfPath の前）追加。null→NULL登録、;区切りは分割せずそのまま登録
- **12.7** `SmtpAgent/Services/ISmtpSendService.cs`・`SmtpSendService.cs`:
  - `ResolveToAddress(profile, recipientToken)` は **1トークン解決の純粋関数のまま維持**
  - `BuildMessage`/`SendMail` を `IReadOnlyList<string> toAddresses, ccAddresses, bccAddresses` 受け取りに変更。To全件→To、CC/BCC全件→CC/Bcc。CC/BCCはFAX正規化なし、空コレクションはヘッダ未付与
- **12.9** `SmtpAgent/Workers/SmtpJobWorker.cs`:
  - recipient を `;`分割・trim・空除外 → 各トークン `ResolveToAddress` で To構築（有効0件/解決例外は status=9）
  - cc/bcc を `;`分割・trim・空除外（FAX正規化なし）で CC/BCC構築。NULL/空/0件は空リスト
  - `SendMail` を新シグネチャで呼び出し。状態遷移ロジック（2/3/9・heartbeat・楽観ロック）は維持
  - ヘルパ `private static List<string> SplitTokens(string? raw)` 追加
- **12.5*** Property 1 拡張（cc/bcc 保持: null→NULL、;含む値はそのまま）。`CommonModule.Tests/Services/SmtpQueueServicePropertyTests.cs`
- **12.8*** Property 5/7/9 を BuildMessage 新シグネチャに追従修正（SmtpAgent.Tests）
- **12.10*** Property 14（複数To解決＝各有効トークンの ResolveToAddress 結果集合と一致）新規。`SmtpAgent.Tests/MultipleToResolutionPropertyTests.cs`（Worker駆動＋StubでSendMail引数捕捉）
- **12.11*** Property 15（CC/BCC は分割・trim・空除外、FAX正規化せず付与）新規。`SmtpAgent.Tests/CcBccAssignmentPropertyTests.cs`
- **14.1*** `MaterialModule/Doc/smtp-sender実送信テスト手順.md` に追加パターンC（To複数;区切り）/D（CC単一）/E（CC複数+BCC）を追記。CC/BCCはFAX正規化されない旨の注記も追加
- **14.2** Spec を MaterialModule/Doc 側へ再同期（requirements/design/tasks の3ファイル、SHA256一致確認済み）
- **13** チェックポイント完了（ユーザー側で**ビルドOK・テスト全緑（エラーなし）確認済み**）

#### 重要な発見・付随修正
- Property14実装時、テスト共有スタブ `\\OJIADM23120073\Labs\WindowsService\SmtpAgent.Tests\WorkerTestSupport.cs` の `StubSmtpSendService` が旧シグネチャ（単一toAddress）のままで **SmtpAgent.Tests 全体がコンパイル不能**だった（12.8 が Property5/7/9 のみ更新し共有スタブを更新漏れ）。新シグネチャ（To/CC/BCC = IReadOnlyList<string>）に追従修正し、`LastToAddresses`/`LastCcAddresses`/`LastBccAddresses` 捕捉プロパティを追加（Property14/15 で活用）。

### 現在のSpec進捗（.kiro/specs/smtp-sender/tasks.md）
- タスク1〜9 完了 ✓
- タスク10: 10.4(Spec同期)完了。10.1〜10.3(*統合テスト=実送信/DB配置/並行運用)は未（10.1相当の実送信は前回実機OK）
- タスク11（最終チェックポイント）: **未**（理由: CC/BCC・複数宛先の**実送信動作確認が未実施**。下記次回タスク参照）
- **タスク12（CC/BCC・複数宛先）完了 ✓**、13 完了 ✓、14 完了 ✓

### 次回タスク（最優先: CC/BCC・複数宛先の実送信動作確認）
ユニット/プロパティテストは全緑だが、**実メール送信での確認が未実施**。手順書 `smtp-sender実送信テスト手順.md` の追加パターンに沿って実施する。
1. **ALTER DDL を db_common_dev に実行** — `MaterialModule/Doc/sql/alter_t_smtp_queue_cc_bcc.sql`（cc/bcc追加・recipient桁拡張）。※実行済みか要確認（本日時点で未確認）
2. SmtpAgent 起動（SkipSend=false）。Worker起動中はexeロックでビルド不可
3. パターンC（To複数 ;区切り→両宛先着信・To欄2件）/ D（CC単一→CC欄表示）/ E（CC複数;区切り+BCC→CCは全員可視・BCCは他受信者から不可視）を投入し着信確認
4. 各パターンで status 1→2→3 遷移を確認SELECTでチェック
5. 確認OKなら タスク11（最終チェックポイント）を完了にし、Spec再同期

### 注意（継続）
- ビルド・DDL・テストはユーザー側。ALTERは既存 t_smtp_queue への適用（db_common_dev）。
- Web側(CommonModule)とWorker側(SmtpAgent)のエンティティは同一テーブルにマップ。Cc/Bcc/Recipient桁は両方一致済み。
- 本日 ユーザー側ビルドOK・テスト全緑（エラーなし）確認済み。実送信のみ未確認。

### 本日の主要変更ファイル（タスク12実装）
- `MaterialModule/Doc/sql/alter_t_smtp_queue_cc_bcc.sql`（新規）
- `MaterialModule/Doc/テーブル定義書.md`（t_smtp_queue に cc/bcc・recipient桁更新）
- `CommonModule/Data/Entities/TSmtpQueue.cs`（Cc/Bcc追加・Recipient1000）
- `CommonModule/Services/ISmtpQueueService.cs`・`SmtpQueueService.cs`（EnqueueAsync cc/bcc）
- `CommonModule.Tests/Services/SmtpQueueServicePropertyTests.cs`（Property1拡張）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent\Models\TSmtpQueue.cs`（Cc/Bcc追加・Recipient1000）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent\Services\ISmtpSendService.cs`・`SmtpSendService.cs`（BuildMessage/SendMail リスト化）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent\Workers\SmtpJobWorker.cs`（;分割→To/CC/BCC構築）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent.Tests\WorkerTestSupport.cs`（スタブ新シグネチャ追従）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent.Tests\MultipleToResolutionPropertyTests.cs`（新規 Property14）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent.Tests\CcBccAssignmentPropertyTests.cs`（新規 Property15）
- `\\OJIADM23120073\Labs\WindowsService\SmtpAgent.Tests\BuildMessagePropertyTests.cs`・`PdfAttachmentPropertyTests.cs`（Property7/9 追従）
- `MaterialModule/Doc/smtp-sender実送信テスト手順.md`（パターンC/D/E追記）
- `.kiro/specs/smtp-sender/{requirements,design,tasks}.md` ＋ `MaterialModule/Doc/specs/smtp-sender/` 同期コピー（tasks のチェック更新）

### 申し送り
- 本日: タスク12（CC/BCC・複数宛先）の実装をすべて完了。ビルドOK・テスト全緑をユーザー確認済み。チェックポイント13クローズ。
- 次回: **CC/BCC・複数宛先の実送信動作確認**（手順書パターンC/D/E）→ OKならタスク11クローズ＆Spec再同期。
- 新セッションは「再開します、session-memoを確認」で本ファイルから。
