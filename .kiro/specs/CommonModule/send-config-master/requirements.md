# Requirements Document

## Introduction

本 spec は、CommonModule（全社共通送信基盤）に実装済みの「送信設定マスタ（send-config-master）」機能を、**単一正本として文書化**するものである。新機能の提案ではなく、**既に実装・コミット済みの事実（Unit1〜Unit4）に忠実に要件を起こす**位置づけであり、実装が権威である。

対象は、FAX／メールのテスト送信方式の再設計に伴い導入された次の要素である。

- 送信元アドレス（本番・テスト共通のシステムアドレス）とテスト送信先（テストFAX番号・テストメールアドレス）を、DBマスタで可視・編集可能に一元管理する「送信設定マスタ（`m_send_config`）」。
- 有効行を読み取るサービス（`ISendConfigService` / `SendConfigService`）。
- マスタを画面から編集する管理画面（`/Common/SendConfig`）。
- 投入側（実処理は別 spec 所有）に対して本マスタが提供する「送信設定の契約」。

旧「test-fax 固定アドレス方式」は取り下げられ、新方式は「recipient 上書き方式」＋「送信元 From はマスタ管理のシステムアドレス」に統一されている。

本書には、**実装済みの項目**と、要件として合意済みだが**未実装として残っている項目（管理画面の単発テスト送信ボタン／Mail テスト経路）**の両方を含める。各要件には実装状態を明記し、後段（design / tasks）で実装済み・未実装の区別を扱えるようにする。

### スコープ

- 所有モジュール: CommonModule（全社共通送信基盤）。対象DB: `db_common_dev`。
- Mail は「テスト疎通のみ」に限定する。発注書メール等の業務メール送信機能は本 spec の対象外（別途）。
- 常駐テストレコード（`t_smtp_queue` / `t_orders` への常駐）は廃案。テストは都度・使い捨てとする。
- MainWeb・AuthModule・SharedCore は変更不可（参照のみ）。成果物は CommonModule 内で完結する。
- DDL 適用・導線 SQL 実行・ビルド・テスト実行・実送信はユーザー側が行う。

## Glossary

- **送信設定マスタ**: 送信元アドレスとテスト送信先を1件（有効行）で保持する DB マスタ。テーブル `m_send_config`、エンティティ `MSendConfig`（CommonModule）。対象DB `db_common_dev`。
- **有効行**: `is_active = 1` の送信設定行。1行運用を前提とし、複数存在する場合は `id` 昇順の先頭を採用する。
- **送信元アドレス（from_address）**: 送信時の From に用いる、本番・テスト共通のシステム／組織アドレス。個人アドレスに依存しない。
- **テストFAX番号（test_fax_number）**: テストFAX送信時に recipient を上書きする固定の宛先FAX番号。
- **テストメールアドレス（test_email）**: テストメール送信時に recipient を上書きする固定の宛先メールアドレス。
- **row_version**: 画面編集の楽観的ロックに用いる行バージョン列（`[Timestamp]` / SQL `ROWVERSION`）。
- **送信設定サービス**: 送信設定マスタの有効行を読み取るサービス。インターフェース `ISendConfigService`、実装 `SendConfigService`（CommonModule）。
- **送信設定管理画面**: 送信設定マスタを閲覧・編集する Razor Pages 画面。`/Common/SendConfig`（Area `Common`）。
- **投入サービス**: 送信ジョブを投入（enqueue）する処理。実処理は別 spec（dispatch-monitoring-consolidation）が所有する。本書では「送信設定マスタが投入側へ提供する契約」としてのみ記述する。
- **config_key**: 送信経路種別を表すキー。FAX 投入では常に `fax`（NormalConfigKey）を用いる。Mail テストでは `mail` を用いる。
- **recipient 上書き方式**: テスト送信時に、config_key は通常（`fax` / `mail`）のまま、宛先（recipient）のみをマスタのテスト送信先へ差し替える方式。
- **DbPermissionCheck**: DB 登録内容に基づくページ単位の認可ポリシー。`m_content` / `r_content_auth`（対象DB `dbAuthTest`）に基づく。
- **単発テスト送信**: 管理画面から、常駐レコードを作らず使い捨てジョブ1件を enqueue して Agent 経路の疎通を確認する操作（未実装の残作業）。

## Requirements

### Requirement 1: 送信設定マスタ（m_send_config）の定義

**実装状態: 実装済み（Unit1・CommonModule `f687e13`）**

**User Story:** 送信基盤の運用担当として、送信元アドレスとテスト送信先を DB マスタで一元管理したい。ハードコードや個人アドレス依存による属人化を回避するため。

#### Acceptance Criteria

1. THE 送信設定マスタ SHALL テーブル名 `m_send_config` として対象DB `db_common_dev` に定義される。
2. THE 送信設定マスタ SHALL 列 `id`（INT・IDENTITY・主キー）、`from_address`（NVARCHAR(256)・NOT NULL）、`test_fax_number`（NVARCHAR(40)・NULL 許容）、`test_email`（NVARCHAR(256)・NULL 許容）、`is_active`（BIT・NOT NULL・既定値 1）、`created_at`（DATETIME2・NOT NULL）、`updated_at`（DATETIME2・NOT NULL）、`row_version`（ROWVERSION・NOT NULL）を保持する。
3. THE 送信設定マスタ SHALL 監査列として `created_at` と `updated_at` のみを保持する（`created_by` / `updated_by` は保持しない）。
4. THE 送信設定マスタ SHALL 有効行（`is_active = 1`）を1件採用する1行運用とし、将来複数行へ拡張する余地を残す。
5. THE エンティティ `MSendConfig` SHALL 各列を `[Column]` 属性で snake_case 名にマッピングし、`row_version` を `[Timestamp]` 属性で楽観的ロック列として定義する。
6. WHEN 初期セットアップ用の DDL（`create_m_send_config.sql`）が実行され、かつ有効行が1件も存在しない場合、THE DDL SHALL 有効な初期シード行を1件投入する。
7. WHERE テーブル `m_send_config` が既に存在する場合、THE DDL SHALL テーブルを再作成しない。

### Requirement 2: 送信設定サービス（有効行の読み取り）

**実装状態: 実装済み（Unit2・CommonModule `0d54cc5`）**

**User Story:** 投入側モジュールの開発者として、有効な送信設定を1件だけ安全に読み取りたい。送信元アドレスとテスト送信先を一貫した方法で取得するため。

#### Acceptance Criteria

1. THE 送信設定サービス SHALL インターフェース `ISendConfigService` のメソッド `GetActiveAsync(CancellationToken)` を提供する。
2. WHEN `GetActiveAsync` が呼び出された場合、THE 送信設定サービス SHALL 有効行（`is_active = 1`）を読み取り専用（AsNoTracking）で取得する。
3. WHEN 複数の有効行が存在する場合、THE 送信設定サービス SHALL `id` 昇順の先頭行を返す。
4. IF 有効行が1件も存在しない場合、THEN THE 送信設定サービス SHALL `null` を返す。
5. THE 送信設定サービス SHALL CommonModule の DI 登録（`AddCommonModule`）に Scoped ライフタイムで登録される。
6. THE 送信設定サービス実装 `SendConfigService` SHALL 他モジュールから直接生成されないよう `internal` として秘匿される。

### Requirement 3: 送信設定管理画面（/Common/SendConfig）

**実装状態: 実装済み（Unit4・CommonModule `30e9396`）**

**User Story:** 送信基盤の管理者として、送信元アドレスとテスト送信先を画面から閲覧・編集したい。SQL を直接操作せず、属人化を避けて可視・保守可能にするため。

#### Acceptance Criteria

1. THE 送信設定管理画面 SHALL Area `Common` の Razor Pages ページ `/Common/SendConfig`（`SendConfig/Index`）として提供される。
2. THE 送信設定管理画面 SHALL 認可ポリシー `DbPermissionCheck` を適用する。
3. WHEN 管理者がページを表示し、かつ有効行が存在する場合、THE 送信設定管理画面 SHALL 有効行1件の `from_address` / `test_fax_number` / `test_email` および `row_version` を編集フォームに表示する。
4. WHEN 管理者がページを表示し、かつ有効行が存在しない場合、THE 送信設定管理画面 SHALL 新規作成用の空フォームを表示する。
5. THE 送信設定管理画面 SHALL `from_address` を必須項目とし、メールアドレス形式（EmailAddress）で検証する。
6. WHERE `test_email` が入力された場合、THE 送信設定管理画面 SHALL メールアドレス形式（EmailAddress）で検証する。
7. WHEN 管理者が保存を実行し、かつ有効行が存在しない場合、THE 送信設定管理画面 SHALL `is_active = 1`・`created_at` / `updated_at` を現在時刻（UTC）とした行を新規作成する。
8. WHEN 管理者が保存を実行し、かつ有効行が存在する場合、THE 送信設定管理画面 SHALL 取得時の `row_version` を元値とした楽観的ロックで当該行を更新し、`updated_at` を現在時刻（UTC）に設定する。
9. IF 更新時に他ユーザーの先行更新による競合（`DbUpdateConcurrencyException`）が発生した場合、THEN THE 送信設定管理画面 SHALL メッセージ「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示する。
10. IF 更新対象の行が取得できない場合、THEN THE 送信設定管理画面 SHALL メッセージ「対象の送信設定が見つかりません。画面を再読み込みしてください。」を表示する。
11. WHEN 保存が成功した場合、THE 送信設定管理画面 SHALL 保存結果に応じた成功メッセージ（新規登録／更新）を表示する。
12. THE 導線登録 SQL（`register_send_config_content.sql`）SHALL 対象DB `dbAuthTest` の `m_content` に Area `Common`・page `SendConfig/Index` を登録する（未登録時のみ）。

### Requirement 4: 投入側へ提供する送信設定の契約（recipient 上書き方式）

**実装状態: 実装済み（本マスタ提供分・Unit3 は投入側 MaterialModule `ab31934`。投入の実処理は dispatch-monitoring-consolidation spec が所有）**

**User Story:** 投入側モジュールの開発者として、本番／テストで送信元アドレスと宛先をマスタから一貫して決定したい。テスト送信を本番経路と同一の config_key で疎通確認するため。

#### Acceptance Criteria

1. THE 送信設定マスタ SHALL 投入側に対して、送信元 From として用いる `from_address` を有効行から提供する。
2. WHEN 投入側が有効行を取得できた場合、THE 投入側 SHALL 送信元 From にマスタの `from_address` を用いる（契約）。
3. IF 有効行の `from_address` が取得できない場合、THEN THE 投入側 SHALL フォールバックとして `FaxDispatchOptions.FromAddress` を用いる（契約）。
4. THE 投入側 SHALL FAX 投入において config_key を常に `fax`（NormalConfigKey）とする（契約）。
5. WHILE テスト送信が有効な場合、THE 投入側 SHALL recipient を有効行の `test_fax_number` に上書きする（契約）。
6. IF テスト送信が有効かつ `test_fax_number` が未設定の場合、THEN THE 投入側 SHALL 当該投入をスキップし、ログを記録する（契約）。
7. WHILE テスト送信が無効（本番送信）な場合、THE 投入側 SHALL recipient を実際の宛先FAX番号とする（契約）。

### Requirement 5: 承認画面からの全経路テスト送信（FAXテスト送信）

**実装状態: 実装済み（投入側連携・MaterialModule `ab31934`）**

**User Story:** 資材の承認担当として、承認画面から上流〜下流の全経路をテスト送信で確認したい。実宛先に送らずにテスト宛先で経路全体の疎通を検証するため。

#### Acceptance Criteria

1. WHEN 承認画面で「FAXテスト送信」が選択されて投入が行われた場合、THE 投入側 SHALL Requirement 4 の recipient 上書き方式に従い recipient を `test_fax_number` に上書きする（契約）。
2. THE テスト送信 SHALL 常駐テストレコードを作成せず、都度・使い捨ての投入として扱う。

### Requirement 6: 管理画面からの単発テスト送信（Agent 単体疎通）

**実装状態: 未実装（残作業・次アクション優先度1）**

**User Story:** 送信基盤の管理者として、管理画面のボタンから使い捨てのテスト送信を1件だけ実行したい。SmtpAgent の経路が単体で疎通するかを、常駐レコードを残さずに確認するため。

#### Acceptance Criteria

1. THE 送信設定管理画面 SHALL 単発テスト送信を実行するボタンを提供する。
2. WHEN 管理者が単発テスト送信（FAX）を実行した場合、THE 送信設定管理画面 SHALL config_key `fax`・宛先を有効行の `test_fax_number` とした使い捨てジョブを1件 enqueue する。
3. WHEN 管理者が単発テスト送信（Mail）を実行した場合、THE 送信設定管理画面 SHALL config_key `mail`・宛先を有効行の `test_email` とした使い捨てジョブを1件 enqueue する。
4. THE 単発テスト送信 SHALL 常駐レコード（`t_smtp_queue` / `t_orders` への常駐）を作成しない。
5. IF 対象のテスト送信先（`test_fax_number` または `test_email`）が未設定の場合、THEN THE 送信設定管理画面 SHALL enqueue を行わず、宛先未設定である旨のメッセージを表示する。

### Requirement 7: Mail テスト経路（config_key=mail／テスト疎通限定）

**実装状態: 未実装（残作業・次アクション優先度2）**

**User Story:** 送信基盤の管理者として、メール送信経路（SmtpAgent 経由）が疎通するかをテストしたい。発注書メール等の業務送信機能とは切り離し、疎通確認のみを行うため。

#### Acceptance Criteria

1. WHEN Mail テスト送信が実行された場合、THE 投入側 SHALL config_key `mail`・宛先を有効行の `test_email` とした使い捨てジョブを1件 enqueue して SmtpAgent 経路を疎通確認する（契約）。
2. IF Mail テスト送信時に `test_email` が未設定の場合、THEN THE 投入側 SHALL enqueue を行わず、宛先未設定である旨をログに記録する（契約）。
3. THE Mail テスト経路 SHALL テスト疎通のみを対象とし、発注書メール等の業務メール送信機能を含まない。

### Requirement 8: 変更範囲とプロジェクト制約の遵守

**実装状態: 実装済み（全 Unit 共通の前提）**

**User Story:** プロジェクトの保守者として、本機能の成果物が定められた変更範囲と排他制御方針に従うことを保証したい。共通基盤の一貫性と安全な同時運用を維持するため。

#### Acceptance Criteria

1. THE 送信設定マスタ機能の成果物 SHALL CommonModule 内で完結し、MainWeb・AuthModule・SharedCore を変更しない。
2. THE 送信設定マスタ SHALL 対象DB `db_common_dev` に配置される。
3. THE 導線登録 SHALL 対象DB `dbAuthTest` に対して行われる。
4. THE 送信設定マスタの画面編集 SHALL 排他制御として `row_version` による楽観的ロックを用いる。
5. THE DDL 適用・導線 SQL 実行・ビルド・テスト実行・実送信 SHALL ユーザー側の作業として扱う。
