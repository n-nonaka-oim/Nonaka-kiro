# Requirements Document

## Introduction

SmtpMonitor（`CommonModule/Areas/Common/Pages/SmtpMonitor/Index`）の送信ジョブ一覧には、現在「ユーザー（コード＋氏名）」を示す列が存在しない。誰がメール送信ジョブを投入したのかを一覧画面上で識別できないため、運用時の追跡・調査が困難である。

本機能は、PrintMonitor で既に実装済みの方式（③-2 相当）と同型の非破壊的アプローチを SMTP 側へ適用し、送信ジョブ一覧に「ユーザー」列を追加する。具体的には、`t_smtp_queue` へ `user_code` 列を冪等 ALTER で追加し、`TSmtpQueue` エンティティ・`ISmtpQueueService.EnqueueAsync` へ非破壊的にユーザーコードを伝播させ、投入元（MaterialModule の SMTP 投入経路）で実行ユーザーのログイン名をセットする。表示側は `IUserRepository` でユーザーコードを氏名へ解決し「コード（氏名）」形式で表示する。

変更は CommonModule 内（＋MaterialModule の投入元）で完結し、clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure）は読み取り参照のみとする。排他制御は既存の `row_version` を踏襲し、新規列追加のみで既存ロジックは不変とする。

## Glossary

- **SmtpMonitor_Page**: `CommonModule/Areas/Common/Pages/SmtpMonitor/Index` に配置される、SMTP 送信ジョブ一覧を表示する Razor Pages 画面。
- **Smtp_Queue_Table**: SMTP 送信ジョブを格納するデータベーステーブル `t_smtp_queue`。エンティティは `CommonModule.Data.Entities.TSmtpQueue`。
- **Smtp_Queue_Service**: SMTP 送信ジョブの投入を担うサービス `ISmtpQueueService`（実装含む）。投入メソッドは `EnqueueAsync`。
- **Smtp_Job_Row**: SmtpMonitor_Page の一覧に表示される 1 件の送信ジョブ行。Smtp_Queue_Table の 1 レコードに対応する。
- **User_Code**: 送信ジョブを投入した実行ユーザーのログイン名（`ApplicationUser.UserName` に対応する値）。Smtp_Queue_Table の `user_code` 列（NVARCHAR(40)、NULL 可）に格納される。
- **User_Repository**: `SharedCore` が提供するユーザー情報参照インターフェース `IUserRepository`。`GetAllUsersAsync()` で全ユーザー（`ApplicationUser`）を取得できる。
- **User_Display**: SmtpMonitor_Page の「ユーザー」列に表示する文字列。User_Code とその氏名（`ApplicationUser.FullName`）を「コード（氏名）」形式で表した表示値。
- **Enqueue_Source**: SMTP 送信ジョブを Smtp_Queue_Service 経由で投入する呼び出し元。MaterialModule の SMTP 投入経路（PrintSettings のテストメール送信、FAX/メール送信経路等）を含む。
- **Table_Definition_Doc**: `.kiro/docs/db/テーブル定義書.md`。
- **ER_Diagram_Doc**: `.kiro/docs/db/ER図.md`（または相当の ER 図ドキュメント）。

## Requirements

### Requirement 1: user_code 列のスキーマ追加

**User Story:** 運用担当者として、送信ジョブに投入ユーザーを記録できるようにしたい。そうすれば誰が送信したかを後から追跡できる。

#### Acceptance Criteria

1. THE Smtp_Queue_Table SHALL `user_code` 列（NVARCHAR(40)、NULL 許容）を保持する。
2. WHEN スキーマ追加スクリプトが実行され、かつ `user_code` 列が Smtp_Queue_Table に存在しない場合、THE スキーマ追加スクリプト SHALL `user_code` 列を追加する。
3. WHEN スキーマ追加スクリプトが実行され、かつ `user_code` 列が Smtp_Queue_Table に既に存在する場合、THE スキーマ追加スクリプト SHALL 列追加を行わずに正常終了する（冪等）。
4. THE スキーマ追加スクリプト SHALL 列の存在確認に `COL_LENGTH` を用いる。
5. THE スキーマ追加スクリプト SHALL Smtp_Queue_Table の既存の列（id/module/config_key/from_address/from_name/recipient/cc/bcc/subject/body/pdf_path/status/picked_at/completed_at/error_message/created_at/updated_at/row_version）を変更しない。
6. WHEN `user_code` 列が追加された場合、THE 開発者 SHALL Table_Definition_Doc を更新して `user_code` 列の列名・日本語名・型・備考を記載する。
7. WHEN `user_code` 列が追加された場合、THE 開発者 SHALL ER_Diagram_Doc を更新して Smtp_Queue_Table の定義に `user_code` を反映する。

### Requirement 2: TSmtpQueue エンティティへのプロパティ追加

**User Story:** 開発者として、`user_code` 列を EF Core エンティティで扱えるようにしたい。そうすればアプリケーションから読み書きできる。

#### Acceptance Criteria

1. THE TSmtpQueue エンティティ SHALL `UserCode` プロパティ（nullable 文字列）を保持する。
2. THE TSmtpQueue エンティティ SHALL `UserCode` プロパティを `[Column("user_code")]` で `user_code` 列へマッピングする。
3. THE TSmtpQueue エンティティ SHALL `UserCode` プロパティに最大長 40 の制約を付与する。
4. THE TSmtpQueue エンティティ SHALL 既存プロパティおよび `row_version`（`[Timestamp]`）の定義を変更しない。

### Requirement 3: EnqueueAsync への非破壊的なユーザーコード引数追加

**User Story:** 開発者として、送信ジョブ投入時にユーザーコードを渡せるようにしたい。そうすれば既存の呼び出しを壊さずにユーザーを記録できる。

#### Acceptance Criteria

1. THE Smtp_Queue_Service SHALL `EnqueueAsync` に任意の末尾引数 `string? userCode`（既定値 `null`）を追加する。
2. WHERE 既存の `EnqueueAsync` 呼び出しが `userCode` 引数を指定しない場合、THE Smtp_Queue_Service SHALL 従来と同一の動作で送信ジョブを投入する（後方互換）。
3. WHEN `EnqueueAsync` が空文字または空白のみの `userCode` を受け取った場合、THE Smtp_Queue_Service SHALL `user_code` を `null` として保存する（空白の null 正規化）。
4. WHEN `EnqueueAsync` が非空白の `userCode` を受け取った場合、THE Smtp_Queue_Service SHALL その値を Smtp_Queue_Table の `user_code` 列へ保存する。
5. THE Smtp_Queue_Service SHALL 既存の投入ロジック（差出人・宛先・件名・本文・CC・BCC・添付・ステータス・`row_version` 制御）を変更しない。

### Requirement 4: 投入元での実行ユーザー設定

**User Story:** 運用担当者として、実際にメールを送信したユーザーが記録されるようにしたい。そうすれば一覧で正しい投入者を確認できる。

#### Acceptance Criteria

1. WHEN Enqueue_Source が PrintSettings のテストメール送信として送信ジョブを投入する場合、THE Enqueue_Source SHALL 実行ユーザーのログイン名（`User.Identity.Name`）を `userCode` として Smtp_Queue_Service へ渡す。
2. WHERE Enqueue_Source が FAX/メール送信経路（DispatchEnqueueService 等）を通じて送信ジョブを投入する場合、THE Enqueue_Source SHALL 実行ユーザーのログイン名を `userCode` として Smtp_Queue_Service へ渡す。
3. IF Enqueue_Source が実行ユーザーのログイン名を取得できない場合、THEN THE Enqueue_Source SHALL `userCode` を指定せずに送信ジョブを投入する。
4. THE 変更対象の Enqueue_Source SHALL MaterialModule 内に限定される。

### Requirement 5: SmtpMonitor 一覧への「ユーザー」列表示

**User Story:** 運用担当者として、送信ジョブ一覧で投入ユーザーをコードと氏名で確認したい。そうすれば誰が送信したかを一目で把握できる。

#### Acceptance Criteria

1. THE SmtpMonitor_Page SHALL Smtp_Job_Row の一覧に「ユーザー」列を追加する。
2. THE SmtpMonitor_Page SHALL User_Repository の `GetAllUsersAsync()` を用いて User_Code を氏名（`ApplicationUser.FullName`）へ解決する辞書を構築する。
3. THE SmtpMonitor_Page SHALL User_Code と `ApplicationUser.UserName` の照合を大文字小文字を区別せず（OrdinalIgnoreCase）行う。
4. WHEN Smtp_Job_Row の User_Code が非空でありユーザー辞書に一致する場合、THE SmtpMonitor_Page SHALL User_Display を「コード（氏名）」形式で表示する。
5. IF Smtp_Job_Row の User_Code が `null` または空である場合、THEN THE SmtpMonitor_Page SHALL 「ユーザー」列に「-」を表示する。
6. IF Smtp_Job_Row の User_Code がユーザー辞書に一致しない場合、THEN THE SmtpMonitor_Page SHALL 「ユーザー」列に「-」を表示する。
7. THE SmtpMonitor_Page SHALL キーワード検索の対象を現状（宛先・件名）のまま維持する。

### Requirement 6: 変更範囲とデータ非破壊の保証

**User Story:** 保守担当者として、本変更が既存データと他モジュールを壊さないことを保証したい。そうすれば安全にリリースできる。

#### Acceptance Criteria

1. THE 変更 SHALL CommonModule（SmtpMonitor 表示・Smtp_Queue_Service・TSmtpQueue・ALTER SQL・docs）と MaterialModule の Enqueue_Source の範囲内で完結する。
2. THE 変更 SHALL clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure）を読み取り参照のみとし、変更しない。
3. WHERE 既存の Smtp_Job_Row の `user_code` が `null` である場合、THE SmtpMonitor_Page SHALL 「ユーザー」列に「-」を表示する。
4. THE 変更 SHALL 既存の排他制御方式（`row_version`）を踏襲し、新規列追加のみで既存の排他制御ロジックを変更しない。
