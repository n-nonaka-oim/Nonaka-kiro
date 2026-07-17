# Requirements Document

## Introduction

自己サービス画面 `Areas/Material/Pages/PrintSettings/Index`（以下 PrintSettings 画面）の「帳票別 出力プリンタ」は、`order_approval`（発注書兼納入依頼書）／`dispatch_request`（原材料工場入請求）／`receiving`（入庫伝票）の3帳票について本人の出力プリンタを設定できる。しかし現状は、各帳票を扱うページへのアクセス権に関係なく、全帳票を設定・テスト印刷できてしまう。

本機能は、各帳票の設定可否を「その帳票を扱うページ（area=Material）にアクセス可能なユーザーか否か」で制御する。アクセス不可の帳票は一覧に行を表示しつつ編集を不可（プリンタ選択 select と「テスト印刷」ボタンを無効化）とし、あわせてサーバ側でも保存・テスト印刷の防御を行う。

本機能は MaterialModule 内（PrintSettings 画面）で完結する。clnCoCore（MainWeb / AuthModule / SharedCore）のソース・設定は変更せず、読み取り参照のみとする。DB スキーマ変更は行わない。既定出力区分・印刷既定（ページ別既定設定カード）は本機能の対象外（不変）とする。

## Glossary

- **PrintSettings_Page**: 自己サービス設定画面 `Areas/Material/Pages/PrintSettings/Index`。本人が自分の帳票別出力プリンタを表示・編集・テスト印刷する。
- **Report_Type**: 帳票種別。本機能の対象は `order_approval`／`dispatch_request`／`receiving` の3種。
- **Report_Page_Map**: Report_Type と、その帳票を扱うページ（area=Material）の対応。
  - `order_approval` → page `Orders/Create`
  - `dispatch_request` → page `Dispatches/Index`
  - `receiving` → page `Receivings/Index`
- **Content_Auth_Service**: `SharedCore.Interfaces.IContentAuthService`。アクセス可否判定に `IsAuthorizedForAnySectionAsync(maxRank, sectionIds, area, page)` を用いる（clnCoCore 側・読み取り参照のみ）。
- **Max_Rank**: 現ユーザーの権限ランク。Claim キー `max_rank`（`AuthModule.Constants.ClaimKeys` と同値）から取得する。
- **Section_Ids**: 現ユーザーの所属セクション ID 群。Claim キー `all_section_ids`（カンマ区切り、`AuthModule.Constants.ClaimKeys` と同値）から取得する。
- **SuperUser_Role**: ロール `SuperUser`。全 Report_Type にアクセス可能とみなす特別ロール。
- **Accessible_Report**: 現ユーザーが Report_Page_Map の対応ページにアクセス可能な Report_Type。
- **Inaccessible_Report**: 現ユーザーが Report_Page_Map の対応ページにアクセス不可な Report_Type。
- **Report_Row**: PrintSettings 画面の「帳票別 出力プリンタ」一覧における 1 Report_Type ぶんの行（プリンタ選択 select と「テスト印刷」ボタンを含む）。

## Requirements

### Requirement 1: 帳票別アクセス可否の判定

**User Story:** 管理者として、各帳票の出力プリンタ設定を「その帳票を扱うページにアクセスできるユーザーだけ」に限定したい。担当外の帳票の設定・テスト印刷を防ぐため。

#### Acceptance Criteria

1. WHEN PrintSettings_Page が表示または送信を処理する、THE PrintSettings_Page SHALL 各 Report_Type について Report_Page_Map で対応付くページを対象に Accessible_Report か Inaccessible_Report かを判定する。
2. WHEN アクセス可否を判定する、THE PrintSettings_Page SHALL Content_Auth_Service の `IsAuthorizedForAnySectionAsync` に area=`Material`・対応ページ・Max_Rank・Section_Ids を渡して判定結果を得る。
3. THE PrintSettings_Page SHALL Max_Rank を Claim `max_rank` から、Section_Ids を Claim `all_section_ids`（カンマ区切り）から取得する。
4. WHERE 現ユーザーが SuperUser_Role を持つ、THE PrintSettings_Page SHALL 全 Report_Type を Accessible_Report として扱う。
5. WHEN `order_approval` のアクセス可否を判定する、THE PrintSettings_Page SHALL page `Orders/Create` と page `Orders/Create/Index` の両方を対象として、いずれかがアクセス可能なら Accessible_Report とみなす。

### Requirement 2: アクセス不可帳票の表示と編集不可（案B）

**User Story:** 利用者として、担当外の帳票も一覧では確認できるが操作はできない状態にしたい。設定できる帳票と対象外の帳票を画面上で区別するため。

#### Acceptance Criteria

1. THE PrintSettings_Page SHALL Accessible_Report・Inaccessible_Report のいずれについても対応する Report_Row を一覧に表示する。
2. WHERE Report_Type が Inaccessible_Report である、THE PrintSettings_Page SHALL 当該 Report_Row のプリンタ選択 select を無効（disabled）で表示する。
3. WHERE Report_Type が Inaccessible_Report である、THE PrintSettings_Page SHALL 当該 Report_Row の「テスト印刷」ボタンを無効（disabled）で表示する。
4. WHERE Report_Type が Accessible_Report である、THE PrintSettings_Page SHALL 当該 Report_Row のプリンタ選択 select と「テスト印刷」ボタンを操作可能な状態で表示する。

### Requirement 3: 保存時のサーバ側防御

**User Story:** 管理者として、無効化を回避した改ざん送信でも担当外帳票の設定が変更されないようにしたい。クライアント側の無効化だけに依存しないため。

#### Acceptance Criteria

1. WHEN PrintSettings_Page が印刷設定の保存（OnPostAsync）を処理する、THE PrintSettings_Page SHALL 各入力の Report_Type について Accessible_Report か否かを判定する。
2. IF 送信された入力の Report_Type が Inaccessible_Report である、THEN THE PrintSettings_Page SHALL 当該 Report_Type に対する割当の追加・更新・削除を行わずスキップする。
3. WHEN Accessible_Report の割当が送信される、THE PrintSettings_Page SHALL 当該 Report_Type の割当を従来どおり保存する。

### Requirement 4: テスト印刷時のサーバ側防御

**User Story:** 管理者として、担当外帳票のテスト印刷を確実に拒否したい。無効化を回避した送信でも印刷キュー投入を防ぐため。

#### Acceptance Criteria

1. WHEN PrintSettings_Page がテスト印刷（OnPostTestPrintAsync）を処理する、THE PrintSettings_Page SHALL 指定された Report_Type について Accessible_Report か否かを判定する。
2. IF 指定された Report_Type が Inaccessible_Report である、THEN THE PrintSettings_Page SHALL テスト印刷を実行せず、印刷キューへの投入を行わずに拒否メッセージを表示する。
3. WHEN 指定された Report_Type が Accessible_Report である、THE PrintSettings_Page SHALL テスト印刷を従来どおり実行する。

### Requirement 5: スコープ制約

**User Story:** 開発担当として、本機能の変更範囲を PrintSettings 画面内に限定したい。他モジュール・DB・対象外機能への影響を避けるため。

#### Acceptance Criteria

1. THE PrintSettings_Page SHALL 本機能の実装を MaterialModule 内で完結させる。
2. THE PrintSettings_Page SHALL clnCoCore（MainWeb / AuthModule / SharedCore）のソース・設定を変更しない。
3. THE PrintSettings_Page SHALL DB スキーマを変更しない。
4. THE PrintSettings_Page SHALL 既定出力区分および印刷既定（ページ別既定設定カード）の挙動を変更しない。
