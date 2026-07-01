# Implementation Plan: smtp-sender（SMTP送信汎用基盤）

## Overview

設計(design.md)に基づき、SMTP送信汎用基盤を段階的に実装する。実装は「DBスキーマ(DDL)→ Worker/Web 共通エンティティ・DbContext → 投入サービス → SmtpAgent 送信ロジック → ポーリング/状態遷移 → 共通監視画面 → 統合テスト」の順で進め、各段階で動作確認できるようにする。

実装の中心は次の2つ。
- 新規 `CommonModule` プロジェクト（Area `Common`）: 共通エンティティ・`CommonDbContext`・`ISmtpQueueService`・共通監視画面 `SmtpMonitor`。
- 既存 `SmtpAgent`（`\\OJIADM23120073\Labs\WindowsService\SmtpAgent`、別ソリューションの .NET8 Worker）の改修: `t_order_reports` 依存を `t_smtp_queue` へ置換し、接続先を `db_common_dev` へ変更。

前提・運用ルール:
- DBスキーマの作成・実行はユーザー側で行う。タスクでは DDL SQL ファイル（`MaterialModule/Doc/sql/`）を作成するところまでを行い、実行はユーザーに依頼する。
- ビルドはユーザー側で行う。
- Correctness Properties 13個は FsCheck（`FsCheck.Xunit`）で最低100イテレーション実装し、各テストに `// Feature: smtp-sender, Property {n}` タグを付す。
- 既存 `t_order_reports.fax_status` 経路・既存 Print/Smtp ページは削除せず並行運用とする（削除タスクは含めない）。

## Tasks

- [x] 1. DBスキーマDDLとドキュメントの整備（共通DB `db_common_dev`）
  - [x] 1.1 3テーブルの DDL SQL ファイルを作成
    - `MaterialModule/Doc/sql/` に `t_smtp_queue`・`m_smtp_config`・`m_smtp_agent_control` の CREATE TABLE スクリプトを作成
    - `t_smtp_queue`: id(IDENTITY,PK)/module/config_key/from_address/from_name/recipient/subject/body(nvarchar(max))/pdf_path/status/picked_at/completed_at/error_message/created_at/updated_at/row_version(rowversion)
    - インデックス `ix_t_smtp_queue_status_created (status, created_at)`・`ix_t_smtp_queue_module (module)` を含める
    - `m_smtp_config`: config_key(PK)/host/port/fax_domain のみ（`from_address`/`from_name`/`test_fax_no`/`pdf_directory` を持たせない）
    - `m_smtp_agent_control`: id(IDENTITY,PK)/last_heartbeat_at/machine_name/updated_at
    - スクリプト冒頭に「実行はユーザーが `db_common_dev` に対して行う」旨をコメントで明記
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.7, 7.2, 8.5_

  - [x] 1.2 接続プロファイル例データと `t_smtp_queue` 版テスト送信SQLを作成
    - `m_smtp_config` の例データ INSERT を作成（`Material`: fax_domain=`@faxmail.com` / `test`: fax_domain 空）
    - 既存 `MaterialModule/Doc/sql/test_smtp_send.sql` を `t_smtp_queue` 版（`config_key`・`from_address`・`from_name` 列あり、`config_key=test`＋テスト用メール宛先）に更新
    - _Requirements: 2.4, 2.5, 8.1, 8.2_

  - [x] 1.3 テーブル定義書とER図を更新
    - `MaterialModule/Doc/テーブル定義書.md` に3テーブルの列名・日本語名・型・備考を追記
    - `MaterialModule/Doc/ER図.md` に `t_smtp_queue` / `m_smtp_config` / `m_smtp_agent_control` と `config_key` による参照関係を追記
    - _Requirements: 1.1, 2.1, 3.1_

- [x] 2. CommonModule プロジェクトと共通エンティティ・DbContext
  - [x] 2.1 CommonModule プロジェクトを新規作成
    - `clnCoCore` ソリューション内に `Microsoft.NET.Sdk.Razor` プロジェクト `CommonModule` を作成し、Area `Common` の構成（`Areas/Common/Pages/`）を用意
    - EF Core / FsCheck 等の必要パッケージ参照を追加し、`db_common_dev` 用接続文字列 `CommonDb` を利用する前提を設定
    - _Requirements: 11.1, 11.2_

  - [x] 2.2 共通エンティティを実装
    - `CommonModule/Data/Entities/` に `TSmtpQueue`・`MSmtpConfig`・`MSmtpAgentControl` を design.md のスキーマどおりに実装
    - `TSmtpQueue.RowVersion` に `[Timestamp]`、各列に `[Column]`/`[MaxLength]` を付与
    - _Requirements: 1.1, 2.1, 3.1, 3.7_

  - [x] 2.3 CommonDbContext を実装
    - `CommonModule/Data/CommonDbContext.cs` に `TSmtpQueue`/`MSmtpConfig`/`MSmtpAgentControl` の `DbSet` を定義
    - SMTP系3テーブルのみを対象とし、資材固有テーブルを参照しない
    - _Requirements: 1.1, 1.4, 1.5_

- [x] 3. 投入ヘルパー ISmtpQueueService とモジュール登録
  - [x] 3.1 ISmtpQueueService / SmtpQueueService を実装
    - `CommonModule/Services/` に `ISmtpQueueService`（`EnqueueAsync`）と実装 `SmtpQueueService` を作成
    - `status=1`・`created_at == updated_at = 現在時刻` を設定して INSERT
    - `module`/`configKey`/`fromAddress`/`recipient`/`subject` の空文字バリデーション（不正時 `ArgumentException`）。`config_key` 実在チェックは Worker 側に委ねる
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 7.1_

  - [x]* 3.2 投入不変条件のプロパティテスト
    - **Property 1: 投入されたジョブは待機状態で全項目が保持される**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 7.1**
    - EF Core InMemory で `EnqueueAsync` を検証。`// Feature: smtp-sender, Property 1` タグ、FsCheck 100イテレーション以上

  - [x] 3.3 CommonModuleExtensions と MainWeb への登録
    - `CommonModule/Extensions/CommonModuleExtensions.cs` に `AddCommonModule(configuration)`（`CommonDbContext`・`ISmtpQueueService`・Area登録）を実装
    - `MainWeb` の `ModuleRegistration.AddModules` に `AddCommonModule` を追加し、`CommonDb` 接続文字列を注入
    - _Requirements: 11.1, 11.2_

- [x] 4. SmtpAgent（Worker）のエンティティ・DbContext・接続先変更
  - [x] 4.1 Worker 側エンティティを実装（TOrderReport を置換）
    - `SmtpAgent/Models/` に `TSmtpQueue`（config_key/from_address/from_name 含む）・`MSmtpConfig`（config_key/host/port/fax_domain のみ）を新規実装し、`MSmtpAgentControl` を維持
    - Web側エンティティと同一テーブル・同一列にマップされるようスキーマを一致させる
    - _Requirements: 1.4, 2.1, 3.1, 4.1_

  - [x] 4.2 SmtpAgentDbContext を改修
    - `SmtpAgent/Data/SmtpAgentDbContext.cs` の `DbSet` を `TOrderReport` から `TSmtpQueue` へ差し替え、`MSmtpConfig`/`MSmtpAgentControl` を対象に設定
    - SMTP系3テーブルのみを対象とし、資材固有テーブルを参照しない
    - _Requirements: 1.4, 4.1_

  - [x] 4.3 接続文字列を db_common_dev へ変更
    - `SmtpAgent/appsettings.json` の接続先を `db_material_dev` から `db_common_dev` へ変更
    - PDF保管先ディレクトリの共通設定を廃止（ジョブの `pdf_path` を使用）
    - _Requirements: 1.1, 1.4, 7.2_

- [x] 5. SmtpAgent 送信サービス（宛先解決・メッセージ組立・PDF添付）
  - [x] 5.1 ISmtpSendService と ResolveToAddress を実装
    - `SmtpAgent/Services/` に `ISmtpSendService` と `SmtpSendService` を作成し、`ResolveToAddress(profile, recipientRaw)` を実装
    - ①`@` 含む→直送、②`fax_domain` 空→直送（正規化なし）、③`fax_domain` 設定済かつ `@` なし→数字抽出＋先頭0→81＋ドメイン付与
    - 宛先が空、または③で数字を1文字も含まない場合は例外を送出
    - _Requirements: 2.4, 2.5, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 8.4_

  - [x]* 5.2 宛先解決のプロパティテスト
    - **Property 5: 宛先解決は宛先種別と接続プロファイルに応じた送信先アドレスを生成する**
    - **Validates: Requirements 2.4, 2.5, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 8.4**
    - 純粋関数として宛先文字列＋プロファイル（fax_domain 空/非空）を生成。`// Feature: smtp-sender, Property 5` タグ、100イテレーション以上

  - [x] 5.3 SendMail（メッセージ組立・差出人・件名・本文・PDF添付）を実装
    - `SmtpSendService.SendMail(profile, fromAddress, fromName, toAddress, subject, body, pdfPath)` を実装
    - 差出人=ジョブの `from_address`/`from_name`、件名=`subject`、接続先=`profile.Host`/`profile.Port`、暗号化・認証なし
    - `pdf_path` が非NULLかつ実在する場合のみ添付。実在しなければ添付なしで送信しログ記録
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 7.3, 7.4, 7.5_

  - [x]* 5.4 送信メッセージ組立のプロパティテスト
    - **Property 7: 送信メッセージの差出人と件名はジョブの値が設定される**
    - **Validates: Requirements 5.5, 5.6**
    - 組み立てた `MailMessage` の From/Subject を検証。`// Feature: smtp-sender, Property 7` タグ、100イテレーション以上

  - [x]* 5.5 PDF添付判定のプロパティテスト
    - **Property 9: PDF添付は指定パスが実在する場合に限り行われ、いずれの場合も送信される**
    - **Validates: Requirements 7.3, 7.4, 7.5**
    - pdf_path（null/実在/不在）を生成し、添付有無が「非NULLかつ実在」と同値であること・いずれも送信されることを検証。`// Feature: smtp-sender, Property 9` タグ、100イテレーション以上

- [x] 6. SmtpJobWorker（ポーリング・排他取得・状態遷移・heartbeat）
  - [x] 6.1 ポーリング取得と排他取得を実装
    - `SmtpAgent/Workers/SmtpJobWorker.cs` を改修し、`t_smtp_queue` の `status==1` を `created_at` 昇順で1件取得
    - 取得時 `status=2`・`picked_at=now`・`updated_at=now` で `SaveChangesAsync`、`DbUpdateConcurrencyException` はスキップ。待機なし時は送信せず次サイクル待機
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x]* 6.2 取得順序・遷移のプロパティテスト
    - **Property 2: ポーリング取得は待機ジョブのうち最古を取得し処理中へ遷移させる**
    - **Validates: Requirements 4.2, 4.3, 4.5**
    - InMemory でジョブ集合（status/created_at 各種）を生成。`// Feature: smtp-sender, Property 2` タグ、100イテレーション以上

  - [x]* 6.3 排他取得（at-most-once）のプロパティテスト
    - **Property 3: 同一ジョブは高々1インスタンスのみが取得に成功する（排他・at-most-once）**
    - **Validates: Requirements 4.4, 3.7**
    - rowversion 競合（2 DbContext での先行更新→後続で `DbUpdateConcurrencyException`）を検証。`// Feature: smtp-sender, Property 3` タグ、100イテレーション以上

  - [x] 6.4 プロファイル解決・宛先不正/例外のエラー化・送信実行・状態遷移を実装
    - ジョブの `config_key` で `m_smtp_config` を解決。該当なしは送信せず `status=9`＋`error_message`
    - `ResolveToAddress` で宛先決定。空/数字なしの例外を捕捉し `status=9`
    - 送信成功で `status=3`・`completed_at=now`。送信中例外は捕捉し `status=9`・`error_message`（500字truncate）
    - 自動リトライは行わない
    - _Requirements: 5.1, 5.2, 5.7, 6.7, 6.8, 10.1, 10.2_

  - [x]* 6.5 プロファイル解決失敗のプロパティテスト
    - **Property 4: 接続プロファイルが解決できないジョブは送信されずエラーになる**
    - **Validates: Requirements 5.1, 5.2**
    - config_key（存在/不在）＋プロファイル集合を生成。`// Feature: smtp-sender, Property 4` タグ、100イテレーション以上

  - [x]* 6.6 宛先不正エラーのプロパティテスト
    - **Property 6: 不正な宛先は送信されずエラー状態になる**
    - **Validates: Requirements 6.7, 6.8**
    - 空/数字なし文字列＋プロファイルを生成し送信モックで `status=9` を検証。`// Feature: smtp-sender, Property 6` タグ、100イテレーション以上

  - [x]* 6.7 送信成功遷移のプロパティテスト
    - **Property 8: 送信成功時は完了状態へ遷移し完了日時が記録される**
    - **Validates: Requirements 5.7**
    - 送信モック成功で `status=3`・`completed_at` 記録を検証。`// Feature: smtp-sender, Property 8` タグ、100イテレーション以上

  - [x]* 6.8 送信例外遷移のプロパティテスト
    - **Property 11: 送信処理中の例外はエラー状態として記録される**
    - **Validates: Requirements 10.1**
    - 任意例外メッセージを生成し `status=9`・`error_message`（500字以下）を検証。`// Feature: smtp-sender, Property 11` タグ、100イテレーション以上

  - [x] 6.9 heartbeat 更新を実装
    - ポーリング毎に `m_smtp_agent_control.last_heartbeat_at`(UTC)・`machine_name` を更新
    - 更新失敗は警告ログのみでポーリング処理を継続
    - _Requirements: 9.1, 9.2, 9.5_

  - [x]* 6.10 heartbeat のユニットテスト
    - 1回更新で `last_heartbeat_at` が現在UTC近傍・`machine_name` 設定（9.1/9.2）、更新例外時もループ継続（9.5）
    - _Requirements: 9.1, 9.2, 9.5_

- [x] 7. チェックポイント - SmtpAgent/CommonModule のテストを通す
  - すべてのテストが通ることを確認し、不明点があればユーザーに確認する。

- [x] 8. 共通監視画面 SmtpMonitor
  - [x] 8.1 一覧・フィルタ・サマリの PageModel を実装
    - `CommonModule/Areas/Common/Pages/SmtpMonitor/Index.cshtml.cs` に `[Authorize(Policy = "DbPermissionCheck")]` を付与
    - 全ジョブを `id` 降順でページング表示。status/module/キーワード/日付範囲フィルタ、status別件数サマリを構築
    - 一覧VMに module・status・error_message を含める
    - _Requirements: 11.3, 11.4, 11.5, 10.6_

  - [x]* 8.2 一覧レンダリングのプロパティテスト
    - **Property 13: 監視一覧は投入元を問わず全ジョブを識別可能に表示する**
    - **Validates: Requirements 11.3, 11.4, 11.5**
    - 複数module混在ジョブ集合を生成し、フィルタ未指定時に全件・module/status保持を検証。`// Feature: smtp-sender, Property 13` タグ、100イテレーション以上

  - [x] 8.3 死活判定を実装
    - `last_heartbeat_at` が現在(UTC)から30秒以内なら「ポーリング中」、超過なら「応答なし」。マシン名・最終応答時刻(JST)を表示
    - _Requirements: 9.3, 9.4_

  - [x]* 8.4 死活判定のプロパティテスト
    - **Property 10: 死活判定は最終応答からの経過時間が閾値以内かと同値である**
    - **Validates: Requirements 9.3, 9.4**
    - 経過秒（境界含む）を生成し Alive 判定が「閾値30秒以内」と同値であることを検証。`// Feature: smtp-sender, Property 10` タグ、100イテレーション以上

  - [x] 8.5 手動再送 OnPostResend を実装
    - status=9 または status=3 のジョブのみ status=1 に戻し、`picked_at`/`completed_at`/`error_message` をクリア。status=1/2 は変更しない
    - _Requirements: 10.3, 10.4, 10.5_

  - [x]* 8.6 手動再送のプロパティテスト
    - **Property 12: 手動再送は完了/エラーのジョブのみを待機へ戻し再取得可能にする**
    - **Validates: Requirements 10.2, 10.3, 10.4, 10.5**
    - 各 status のジョブを生成し、3/9 のみ 1 へ・1/2 不変を検証。`// Feature: smtp-sender, Property 12` タグ、100イテレーション以上

  - [x] 8.7 監視画面ビュー Index.cshtml を実装
    - 共通スタイル（Bootstrap5、site.css は変更しない）で一覧・フィルタ・サマリ・死活表示・再送操作・error_message 表示を描画
    - _Requirements: 11.3, 11.4, 11.5, 9.3, 9.4, 10.6_

  - [x]* 8.8 エラー内容表示のユニットテスト
    - `error_message` を持つジョブが一覧VM/画面で表示されることを検証
    - _Requirements: 10.6_

- [x] 9. チェックポイント - 監視画面のテストを通す
  - すべてのテストが通ることを確認し、不明点があればユーザーに確認する。

- [ ] 10. 統合テストとSpec同期
  - [x]* 10.1 実SMTP送信の統合テスト
    - `config_key=test`（fax_domain 空）＋テスト用メール宛先のジョブを投入し、`172.16.128.81:25` への直送（添付なし／PDF添付あり）を検証
    - _Requirements: 5.3, 5.4_

  - [ ]* 10.2 DB配置の統合テスト
    - `db_common_dev` に3テーブルが存在し、SmtpAgent が `db_common_dev` 接続で1ジョブを処理できることを検証
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ]* 10.3 並行運用の統合テスト
    - 既存 `t_order_reports.fax_status` 経路と新 `t_smtp_queue` 経路が同一環境で同時稼働できることを検証
    - _Requirements: 12.1, 12.2, 12.3_

  - [x] 10.4 Spec を MaterialModule/Doc 側に同期
    - `.kiro/specs/smtp-sender/` の requirements.md・design.md・tasks.md を `MaterialModule/Doc/specs/smtp-sender/` にコピー
    - _Requirements: （プロジェクトルール: Spec 2箇所配置）_

- [x] 11. 最終チェックポイント - 全テストを通す
  - すべてのテストが通ることを確認し、不明点があればユーザーに確認する。

- [ ] 12. CC/BCC・複数宛先（;区切り）対応
  - [x] 12.1 t_smtp_queue への ALTER DDL を作成
    - `MaterialModule/Doc/sql/` に `t_smtp_queue` 改修用 ALTER スクリプトを新規作成（`cc nvarchar(1000) NULL` 追加 / `bcc nvarchar(1000) NULL` 追加 / `recipient` を `nvarchar(1000)` へ拡張）
    - 新規 CREATE ではなく `ALTER TABLE`（既に `db_common_dev` に作成済みの前提）。スクリプト冒頭に「実行はユーザーが `db_common_dev` に対して行う」旨をコメントで明記
    - _Requirements: 3.8, 3.9, 3.10_

  - [x] 12.2 テーブル定義書・ER図を更新
    - `MaterialModule/Doc/テーブル定義書.md` の `t_smtp_queue` に `cc`/`bcc` 列（日本語名・型 `nvarchar(1000)`・NULL許容・備考）を追記し、`recipient` の桁を `nvarchar(1000)` に更新
    - `MaterialModule/Doc/ER図.md` は列追加のみで参照関係に影響がないため、必要に応じて列注記のみ更新
    - _Requirements: 3.1, 3.8, 3.9_

  - [x] 12.3 CommonModule の TSmtpQueue エンティティを更新
    - `CommonModule/Data/Entities/TSmtpQueue.cs` に `Cc`（`[Column("cc")]`/`[MaxLength(1000)]`/`string?`）・`Bcc`（同上）プロパティを追加
    - `Recipient` の `[MaxLength]` を 1000 に変更
    - _Requirements: 3.1, 3.8, 3.9, 3.10_

  - [x] 12.4 ISmtpQueueService.EnqueueAsync を改修
    - `CommonModule/Services/ISmtpQueueService.cs`・`SmtpQueueService.cs` の `EnqueueAsync` に `string? cc = null`・`string? bcc = null` 任意引数を追加（design.md の最終シグネチャに一致）
    - `cc`/`bcc` 未指定（null）時は当該列を NULL 登録。`;` 区切りを含む値は分割・整形せずそのまま該当列へ登録
    - _Requirements: 3.11, 3.12_

  - [x]* 12.5 投入時の cc/bcc 保持プロパティテストを拡張
    - **Property 1: 投入されたジョブは待機状態で全項目が保持される**（cc/bcc 保持を追加検証）
    - **Validates: Requirements 3.10, 3.11, 3.12**
    - 既存 `// Feature: smtp-sender, Property 1` テストに、cc/bcc 未指定→NULL登録・`;` 含む値はそのまま保持の検証を追加。EF Core InMemory、100イテレーション以上

  - [x] 12.6 SmtpAgent の TSmtpQueue エンティティを更新
    - `SmtpAgent/Models/TSmtpQueue.cs` に `Cc`/`Bcc`（`[Column]`/`[MaxLength(1000)]`/`string?`）を追加し、`Recipient` の `[MaxLength]` を 1000 に変更
    - Web側（CommonModule）エンティティと同一テーブル・同一列にマップされるようスキーマを一致させる
    - _Requirements: 3.8, 3.9, 1.4, 4.1_

  - [x] 12.7 ISmtpSendService / SmtpSendService を改修
    - `SmtpAgent/Services/ISmtpSendService.cs`・`SmtpSendService.cs` の `ResolveToAddress` は **1トークン解決の純粋関数のまま維持**
    - `BuildMessage`・`SendMail` を design.md の最終シグネチャ（To/CC/BCC を `IReadOnlyList<string>` で受け取る）に変更。To は解決済みアドレス群、CC/BCC は trim・空除外済みのメールアドレス群を `MailMessage.CC`/`MailMessage.Bcc` に全件設定
    - CC/BCC は FAX正規化を行わず、空コレクション時は該当ヘッダを付与しない
    - _Requirements: 6.11, 6.12, 13.1, 13.2, 13.6, 13.7, 13.8_

  - [x]* 12.8 既存 Property 5/7/9 テストをシグネチャ変更に追従して修正
    - **Property 5: 宛先解決（単一トークン）** / **Property 7: 差出人・件名** / **Property 9: PDF添付判定**
    - **Validates: Requirements 6.1-6.6 / 5.5, 5.6 / 7.3, 7.4, 7.5**
    - `BuildMessage` の新シグネチャ（To/CC/BCC リスト引数）に追従して呼び出しを修正し、コンパイル・100イテレーションを維持
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 5.5, 5.6, 7.3, 7.4, 7.5_

  - [x] 12.9 SmtpJobWorker を改修（複数To・CC/BCC構築）
    - `SmtpAgent/Workers/SmtpJobWorker.cs` で `recipient` を `;` 分割・trim・空除外し、各トークンを `ResolveToAddress` で解決して To リストを構築（有効0件/解決例外は `status=9`＋`error_message`）
    - `cc`/`bcc` をそれぞれ `;` 分割・trim・空除外して CC/BCC リストを構築（FAX正規化なし）。NULL/空/有効0件は該当ヘッダなし
    - 構築した To/CC/BCC リストを `SendMail`（内部で `BuildMessage`）へ渡す
    - _Requirements: 6.9, 6.10, 6.11, 6.12, 6.13, 13.3, 13.4, 13.5, 13.7, 13.8_

  - [x]* 12.10 複数To解決のプロパティテスト
    - **Property 14: 複数宛先(To)解決は各有効トークンの解決結果集合と一致する**
    - **Validates: Requirements 6.9, 6.10, 6.11, 6.12**
    - `;` 区切り（空トークン混在）の recipient ＋プロファイルを生成し、To集合＝各有効トークンの `ResolveToAddress` 結果集合に一致することを検証。`// Feature: smtp-sender, Property 14` タグ、100イテレーション以上

  - [x]* 12.11 CC/BCC付与の同値プロパティテスト
    - **Property 15: CC/BCC は分割・trim・空除外され、FAX正規化せずに付与される**
    - **Validates: Requirements 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8**
    - cc/bcc（null/空/`;`区切り・空白混在）＋プロファイル（fax_domain 空/非空）を生成し、NULL/空→ヘッダなし・値あり→trim・空除外・FAX正規化なしで CC/BCC 全件設定を検証。`// Feature: smtp-sender, Property 15` タグ、100イテレーション以上

- [x] 13. チェックポイント - CC/BCC・複数宛先対応のテストを通す
  - すべてのテストが通ることを確認し、不明点があればユーザーに確認する。

- [ ] 14. 実送信再確認手順の更新とSpec再同期
  - [x]* 14.1 実送信テスト手順を CC/BCC・複数宛先版に追記
    - `MaterialModule/Doc/smtp-sender実送信テスト手順.md` に、To複数（`;`区切り）・CC/BCC 付きジョブの投入例・確認手順を追記（実送信の実施はユーザー側）
    - _Requirements: 5.3, 5.4, 6.12, 13.7, 13.8_

  - [x] 14.2 更新した Spec を MaterialModule/Doc 側に同期
    - 更新した `.kiro/specs/smtp-sender/` の requirements.md・design.md・tasks.md を `MaterialModule/Doc/specs/smtp-sender/` にコピー（10.4 と同様）
    - _Requirements: （プロジェクトルール: Spec 2箇所配置）_

## Notes

- `*` 付きサブタスクは省略可能（テスト）で、MVP優先時はスキップできる。コア実装タスクには `*` を付けていない。
- 各タスクは要件番号を参照し、プロパティテストは design.md の Correctness Property 番号を明示している。
- DBスキーマの作成・実行はユーザー側、ビルドもユーザー側で実施する（タスク内でビルド・実行は行わない）。
- 実SMTP送信・実FAXゲートウェイへの疎通確認は統合テストの自動化範囲で扱い、実プリンタ/実FAX機での手動確認はスコープ外（補足）。
- 既存経路・既存ページの削除タスクは含めない（並行運用方針、要件12）。
- 15個の Correctness Property はそれぞれ単一のプロパティテストとして実装する（Property 1/5/7/9/2/3/4/6/8/11/10/12/13/14/15）。Property 14/15 と Property 1 への cc/bcc 検証追加は CC/BCC・複数宛先対応（タスク12）で実装する。
- タスク12以降は CC/BCC・複数宛先（`;`区切り）対応の差分追加であり、`t_smtp_queue` は ALTER TABLE で `cc`/`bcc` 追加・`recipient` 桁拡張を適用する（実行はユーザー側）。タスク1〜11の完了状態は変更しない。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "2.1"] },
    { "id": 2, "tasks": ["2.2"] },
    { "id": 3, "tasks": ["2.3", "4.1"] },
    { "id": 4, "tasks": ["3.1", "4.2", "5.1"] },
    { "id": 5, "tasks": ["3.2", "3.3", "4.3", "5.2", "5.3"] },
    { "id": 6, "tasks": ["5.4", "5.5", "6.1"] },
    { "id": 7, "tasks": ["6.2", "6.3", "6.4"] },
    { "id": 8, "tasks": ["6.5", "6.6", "6.7", "6.8", "6.9"] },
    { "id": 9, "tasks": ["6.10", "8.1"] },
    { "id": 10, "tasks": ["8.2", "8.3"] },
    { "id": 11, "tasks": ["8.4", "8.5"] },
    { "id": 12, "tasks": ["8.6", "8.7", "8.8"] },
    { "id": 13, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 14, "tasks": ["10.4"] },
    { "id": 15, "tasks": ["12.1", "12.3", "12.6"] },
    { "id": 16, "tasks": ["12.2", "12.4", "12.7"] },
    { "id": 17, "tasks": ["12.5", "12.8", "12.9"] },
    { "id": 18, "tasks": ["12.10", "12.11", "14.1"] },
    { "id": 19, "tasks": ["14.2"] }
  ]
}
```
