# Implementation Plan: SmtpMonitor ユーザー列対応（PrintMonitor ③-2 同型）

## Overview

`t_smtp_queue` に `user_code` 列を非破壊的に追加し、投入〜表示まで実行ユーザーを伝播・解決する。PrintMonitor ③-2 と同型で、DB（冪等 ALTER）→ エンティティ → サービス（省略可能引数）→ 投入元（MaterialModule）→ 表示（SmtpMonitor）の順に段階実装する。`clnCoCore`（MainWeb / AuthModule / SharedCore / SharedInfrastructure）は読み取り参照のみで一切変更しない。ビルド・テストはユーザー側で実施する（テストは任意）。

## Tasks

- [x] 1. DB スキーマとエンティティ
  - [x] 1.1 冪等 ALTER SQL を作成（C1）
    - `CommonModule/docs/sql/alter_t_smtp_queue_add_user_code.sql` を新規作成
    - `COL_LENGTH('dbo.t_smtp_queue', 'user_code') IS NULL` ガードで `user_code NVARCHAR(40) NULL` を追加（冪等・PRINT 通知）
    - 実行先 `db_common_dev`、適用はユーザーが実施する旨をヘッダに明記。既存 18 列・`row_version` は不変
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 1.2 `TSmtpQueue` に `UserCode` プロパティを追加（C2）
    - `UpdatedAt` の後・`RowVersion`（`[Timestamp]`）の直前に `[Column("user_code")][MaxLength(40)] public string? UserCode { get; set; }` を追加
    - 既存プロパティおよび `RowVersion` の定義は変更しない
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 2. サービス層への userCode 伝播
  - [x] 2.1 `EnqueueAsync` に省略可能引数を追加し実装（C3・C4）
    - `ISmtpQueueService.EnqueueAsync` の末尾（`CancellationToken ct = default` の後）に `string? userCode = null` を追加
    - `SmtpQueueService` 実装で `UserCode = string.IsNullOrWhiteSpace(userCode) ? null : userCode.Trim()` をセット（空白 null 正規化・非空白は Trim）
    - 既存の必須バリデーション・`status=1`・`created_at==updated_at`・`row_version` 制御は不変
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [-]* 2.2 `EnqueueAsync` の正規化・後方互換ユニットテスト（任意・スキップ）
    - InMemory `CommonDbContext`（一意 DB 名＋`IDisposable`）で `null`／空／空白 → `UserCode==null`、非空白 → Trim 値を確認
    - `userCode` 未指定の既存形呼び出しが成立し `UserCode==null` で登録されることを確認
    - _Requirements: 3.2, 3.3, 3.4_

- [x] 3. 投入元（MaterialModule）での実行ユーザー設定
  - [x] 3.1 SMTP 投入経路の洗い出しと PrintSettings への userCode 付与（C5）
    - MaterialModule 内の `ISmtpQueueService.EnqueueAsync` 全呼び出し元を洗い出す
    - `PrintSettings/Index.cshtml.cs` `OnPostTestMailAsync` に `userCode: User.Identity?.Name` を名前付きで追加（`ct:` も名前付き化）
    - _Requirements: 4.1, 4.2, 4.4_

  - [x] 3.2 FAX/メール送信経路へ userCode 付与（C5）
    - 3.1 で確定した FAX/メール送信経路（`DispatchEnqueueService` 等）へ実行ユーザーのログイン名を `userCode` として付与
    - 実行ユーザーを取得できない経路（バックグラウンド等で `User` 不在）は `userCode` 未指定のまま投入
    - _Requirements: 4.2, 4.3, 4.4_

- [x] 4. SmtpMonitor 表示
  - [x] 4.1 code-behind で氏名解決（C6）
    - `SmtpMonitor/Index.cshtml.cs` の primary constructor に `IUserRepository userRepository` を注入（`using SharedCore.Interfaces;`）
    - `JobRow` に `UserCode`／`UserName`（`string?`）を追加、`Select` 射影に `UserCode = r.UserCode` を追加
    - `ToListAsync` 後、`UserCode` を持つ行がある場合のみ `GetAllUsersAsync()` を1回呼び、`UserName`→`FullName` 辞書（`OrdinalIgnoreCase`）で `JobRow.UserName` を解決（ループ内 await なし）
    - _Requirements: 5.2, 5.3_

  - [-]* 4.2 （任意・スキップ）`FormatUserDisplay` を切り出し Property 1 テスト
    - 表示整形を `static FormatUserDisplay(string? userCode, string? userName)` として code-behind に切り出す場合のみ実施
    - **Property 1: ユーザー表示文字列の整形規則**（FsCheck、null/空/全角半角/記号を含む任意文字列で3分岐を検証・最低100反復）
    - タグ: `Feature: smtp-monitor-user-column, Property 1`
    - **Validates: Requirements 5.4, 5.5, 5.6**

  - [x] 4.3 cshtml に「ユーザー」列を追加（C7）
    - `SmtpMonitor/Index.cshtml` の「接続プロファイル」列直後・「差出人」列手前に見出し `<th>ユーザー</th>` とセルを追加
    - セルはインライン三項式で `-`／`UserCode`／`UserCode（UserName）` を出し分け
    - 空行メッセージの `colspan="14"` を `colspan="15"` に更新。キーワード検索は現状（宛先・件名）維持
    - _Requirements: 5.1, 5.4, 5.5, 5.6, 5.7_

- [x] 5. DB ドキュメント更新
  - [x] 5.1 テーブル定義書・ER図に `user_code` を追記
    - `.kiro/docs/db/テーブル定義書.md` の `t_smtp_queue` に `user_code`（NVARCHAR(40)・NULL可・投入ユーザーコード）を追記
    - `.kiro/docs/db/ER図.md` の `t_smtp_queue` 定義に `nvarchar user_code` を追記
    - _Requirements: 1.6, 1.7_

- [x] 6. Checkpoint - 変更範囲とデータ非破壊の確認
  - 変更が CommonModule（表示・サービス・エンティティ・SQL・docs）＋MaterialModule の投入元に閉じ、`clnCoCore` が不変であることを確認
  - 既存 NULL 行が「-」表示、既存列・`row_version` 非変更、排他制御ロジック不変を確認
  - すべてのテストが通ることを確認し、疑問があればユーザーに確認する
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

## Notes

- `*` 付きサブタスクは任意（テスト）。純粋関数がほぼ無いため property test は任意で、`FormatUserDisplay` を切り出す場合のみ Property 1 を対象とする（design 準拠）。
- **ビルド・テストはユーザー側で実施**（Kiro からビルドしない）。テストは管理外（任意）。
- **リポジトリ分離に注意**: CommonModule と MaterialModule は別 git リポジトリ、`.kiro` は Nonaka メタリポジトリ。タスク 3（MaterialModule）と他タスク（CommonModule）と docs（`.kiro`）はそれぞれ別コミットになる。
- **DB スキーマ変更**のためテーブル定義書・ER図の更新は必須（タスク 5）。ALTER の適用はユーザーが `db_common_dev` に対して実施する。
- 各タスクは design の Components（C1〜C7）＋docs に対応し、requirements の細目番号を参照する。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "5.1"] },
    { "id": 1, "tasks": ["2.1", "3.1", "4.1", "4.3"] },
    { "id": 2, "tasks": ["2.2", "3.2", "4.2"] }
  ]
}
```
