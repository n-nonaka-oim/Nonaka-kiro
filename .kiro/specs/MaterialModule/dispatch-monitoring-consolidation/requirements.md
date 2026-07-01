# Requirements Document

## Introduction

発注処理まわりの送信（FAX）・印刷ジョブ投入を整理し、MaterialModule の監視画面を共通基盤へ集約するための要件を定義する。本 spec は **MaterialModule の関心事に集中** し、印刷の共通基盤（`t_print_queue` のスキーマ契約・PrintAgent の読取先・Common_PrintMonitor・カットオーバー手順）は別 spec `print-platform` が所有する。本 spec は当該共通基盤に **依存** する。

本 spec は次の点をまとめて扱う。

1. **二重FAXの根絶**: 発注承認時に旧FAX経路（`t_order_reports.fax_status`）と新FAX経路（`t_smtp_queue`）の双方にFAX用レコードが生成されている状態を解消し、FAXジョブを新経路（`t_smtp_queue`）へ一本化する。
2. **FAX監視の集約**: `t_order_reports.fax_status` を表示する旧FAX監視画面（Material_SmtpMonitor）を廃止し、FAX監視を CommonModule の Common_SmtpMonitor（`t_smtp_queue` ベース）へ集約する。
3. **PrintJobService の投入先変更（投入側実装）**: 承認済み発注の印刷ジョブを `t_order_reports` ではなく共通プリント基盤の共通キュー `t_print_queue` へ投入する。投入先のスキーマ契約・カットオーバー手順は `print-platform` に従う。
4. **旧 Material_PrintMonitor の廃止／導線更新**: Material 側の印刷監視画面（Material_PrintMonitor）を廃止し、導線を共通プリント基盤が設置する Common_PrintMonitor へ更新する。

本 spec は **要件定義のみ** を対象とし、実装・コード変更は含まない。

### 依存関係（Dependencies）

本 spec は別 spec `print-platform`（共通プリント基盤）に依存する。以下は `print-platform` が **契約の発生元（所有者）** であり、本 spec は重複する受入基準を持たず、依存としてのみ参照する。

- **`t_print_queue` のスキーマ契約・DDL・既存データ移行**: `print-platform` Requirement 1〜3 が所有する。本 spec の PrintJobService 投入先（Requirement 4）は当該スキーマ契約に準拠する。
- **PrintJobService の投入インターフェース契約**（投入先・PrintStatus 初期値・PrintPayload 付与）: `print-platform` Requirement 4 が定義する。本 spec は当該契約に従って投入側を実装する範囲を所有する。
- **PrintAgent の読取先変更**: `print-platform` Requirement 5 が所有する。本 spec は対象外とする。
- **Common_PrintMonitor（`/Common/PrintMonitor`）の設置・実装**: `print-platform` Requirement 8〜10 が所有する。本 spec は導線の更新先として参照するのみとする。
- **カットオーバー（移行手順・切替順序）**: `print-platform` Requirement 11 が所有する。本 spec の投入先切替は、当該カットオーバー手順の一部として `print-platform` の手順に従う。

### スコープ外（Non-Goals）

- `t_print_queue` のスキーマ契約・DDL・既存データ移行（→ `print-platform` 所有）。
- PrintAgent（Worker Service）の読取先変更および本体ロジック改修（→ `print-platform` 所有）。
- Common_PrintMonitor（`/Common/PrintMonitor`）の設置・実装（→ `print-platform` 所有）。
- 印刷ジョブの正本キュー切替に関するカットオーバー手順・切替順序の定義（→ `print-platform` 所有）。
- MainWeb・AuthModule への変更（参照のみ。プラットフォーム登録は当該プラットフォームモジュール側 spec が所有）。
- SmtpAgent（Worker Service）本体のロジック改修（前提として参照する）。
- 帳票レイアウト・PDF生成ロジックの変更。
- 実DDL適用・ビルド・テスト・実送信・実印刷（いずれもユーザー側で実施）。

## Glossary

- **PrintJobService**: `MaterialModule/Services/PrintJobService.cs`。承認済み発注を発注番号グループ単位で束ね、印刷ジョブ（PrintPayload付き）を生成する資材モジュールのサービス。本 spec の対象として、印刷ジョブを共通プリント基盤の `t_print_queue`（db_common_dev）へ投入する（現状は `t_order_reports` へ生成）。
- **t_order_reports**: db_material_dev に存在する資材固有テーブル。従来は `print_status`（印刷状態）と `fax_status`（旧FAX状態）の両ステータスを保持する。本 spec では FAX 用レコードを生成せず、印刷ジョブの投入先としても使用しない。
- **t_print_queue**: db_common_dev の共通テーブル。印刷ジョブのキュー。スキーマ契約・DDL・移行は `print-platform` が所有する。本 spec は PrintJobService の投入先として当該契約に準拠して参照する。
- **t_smtp_queue**: db_common_dev に存在する共通テーブル。新FAX/メール送信ジョブのキュー。order-approval-fax-mail 機能が投入し、SmtpAgent が処理する。
- **旧FAX経路**: 承認時に `t_order_reports.fax_status=1`（待機）を立てる従来のFAX送信経路。
- **新FAX経路**: 承認時に `t_smtp_queue` へFAXジョブを投入する経路（order-approval-fax-mail 機能）。
- **Material_SmtpMonitor**: `MaterialModule/Areas/Material/Pages/SmtpMonitor`。`t_order_reports.fax_status` を表示する旧FAX監視画面（廃止対象）。
- **Common_SmtpMonitor**: `CommonModule/Areas/Common/Pages/SmtpMonitor`（`/Common/SmtpMonitor`）。`t_smtp_queue` ベースの新SMTP監視画面（FAX監視の集約先）。
- **Material_PrintMonitor**: `MaterialModule/Areas/Material/Pages/PrintMonitor`。`t_order_reports.print_status` を表示する従来の印刷監視画面（本 spec の廃止対象）。
- **Common_PrintMonitor**: `CommonModule/Areas/Common/Pages/PrintMonitor`（`/Common/PrintMonitor`）。共通プリント基盤の印刷監視画面。設置・実装は `print-platform` が所有する。本 spec は導線の更新先として参照する。
- **SmtpAgent**: `t_smtp_queue` のみを処理する Worker Service。リファクタ済みで `t_order_reports.fax_status` は処理しない。
- **PrintAgent**: 印刷ジョブを処理する Worker Service（別ソリューション: `\\OJIADM23120073\Labs\WindowsService\PrintAgent`）。読取先変更は `print-platform` が所有する。本 spec では参照のみ。
- **PrintStatus**: 印刷状態。0=対象外, 1=待機, 2=処理中, 3=完了, 9=エラー。
- **FaxStatus**: `t_order_reports.fax_status`。0=FAX対象外, 1=待機, 2=処理中, 3=完了, 9=エラー（旧経路）。
- **OutputType**: 発注の出力区分。FAX対象判定（値 2 または 3）に使用される。
- **PrintPayload**: 印刷用 JSON。印刷ジョブに付与される入力データ。
- **MaterialDbContext**: db_material_dev に接続する資材モジュールの DbContext。
- **CommonDbContext**: db_common_dev に接続する CommonModule の DbContext。
- **DbPermissionCheck**: DB権限ベースの認可ポリシー（`[Authorize(Policy = "DbPermissionCheck")]`）。

## 前提（Assumptions）

- A1: SmtpAgent はリファクタ済みで `t_smtp_queue` のみ処理し、`t_order_reports.fax_status` は処理しない。したがって旧FAX経路に積まれた `fax_status=1`（待機）レコードは実送信されないが、待機レコードとして滞留し、二重FAXの潜在リスクおよび監視上の誤解を生む。
- A2: 新FAX経路（`t_smtp_queue` への投入）は order-approval-fax-mail 機能で実装済みであり、本 spec ではFAX送信の正本経路とみなす。
- A3: 印刷ジョブの共通キュー化（`t_print_queue` への移行、方針A）は別 spec `print-platform` が所有・確定済みである。本 spec はその契約に依存する。
- A4: `t_print_queue` の DDL 適用、および既存 `t_order_reports` 印刷データの移行は `print-platform` の手順に従いユーザーが db_common_dev に対して実施する。
- A5: PrintJobService の投入先切替は、`print-platform` Requirement 11 のカットオーバー手順の一部として、PrintAgent の読取先切替と協調して実施される。

## Requirements

### Requirement 1: FAXジョブの新経路一本化

**User Story:** 発注業務担当者として、発注承認時にFAXジョブが新経路（`t_smtp_queue`）にのみ生成されてほしい。そうすれば旧経路への待機レコード生成による二重FAXリスクと監視上の誤解がなくなる。

#### Acceptance Criteria

1. WHEN PrintJobService が発注承認に伴い印刷ジョブを生成する、THE PrintJobService SHALL FAX用レコードを `t_order_reports.fax_status` に生成しない。
2. WHERE 発注グループにFAX対象（OutputType が 2 または 3）の明細が含まれる、THE 新FAX経路（`t_smtp_queue`）SHALL 当該発注のFAXジョブを担う唯一の経路である。
3. IF 旧FAX経路（`t_order_reports.fax_status`）に待機レコードが存在する、THEN THE システム SHALL 当該レコードを新規FAX送信の対象として扱わない。

### Requirement 2: FAX監視の集約

**User Story:** 運用管理者として、FAX送信状況を新経路（`t_smtp_queue`）に基づく単一の監視画面で確認したい。そうすれば旧経路の滞留レコードに惑わされずに送信状況を把握できる。

#### Acceptance Criteria

1. THE Common_SmtpMonitor SHALL `t_smtp_queue` を唯一のデータソースとしてFAX送信ジョブの状況を表示する。
2. WHEN 利用者がFAX監視機能へアクセスする、THE システム SHALL Common_SmtpMonitor（`/Common/SmtpMonitor`）へ案内する。
3. WHERE Material_SmtpMonitor で提供していたFAX再送機能が必要とされる、THE Common_SmtpMonitor SHALL `t_smtp_queue` ベースで同等のFAX再送機能を提供する。

### Requirement 3: 旧 Material_SmtpMonitor の廃止

**User Story:** 開発保守担当者として、`t_order_reports.fax_status` ベースの旧FAX監視画面を廃止したい。そうすれば監視画面が一本化され、二重管理がなくなる。

#### Acceptance Criteria

1. THE システム SHALL Material_SmtpMonitor（`MaterialModule/Areas/Material/Pages/SmtpMonitor`）を提供しない。
2. WHERE 既存メニュー・ナビゲーションに Material_SmtpMonitor への導線が存在する、THE システム SHALL 当該導線を除去する。
3. THE MaterialModule SHALL Material_SmtpMonitor の廃止に伴い不要となった `t_order_reports.fax_status` 参照コードを保持しない。

### Requirement 4: PrintJobService の投入先変更

**User Story:** 発注業務担当者として、承認済み発注の印刷ジョブが共通プリント基盤の共通キュー（`t_print_queue`）に投入されてほしい。そうすれば印刷監視と処理が共通基盤上で完結する。

#### Acceptance Criteria

1. THE PrintJobService SHALL 印刷ジョブを `t_print_queue`（db_common_dev）に投入する。
2. THE PrintJobService SHALL 印刷ジョブ投入時に PrintPayload（印刷用JSON）を付与する。
3. THE PrintJobService SHALL 投入する印刷ジョブの PrintStatus を 1（待機）に設定する。
4. THE PrintJobService SHALL 印刷ジョブを `t_order_reports` に新規生成しない。
5. THE PrintJobService の投入 SHALL `print-platform` Requirement 4 で定義される投入インターフェース契約（投入先・PrintStatus 初期値・PrintPayload 付与）に準拠する。
6. WHERE PrintJobService（MaterialModule）から共通キュー `t_print_queue` へ投入する手段が必要となる、THE 投入経路の実装形態（CommonModule の投入サービス経由か直接アクセスか）SHALL 本 spec の設計フェーズで決定される。
7. THE PrintJobService の投入先切替 SHALL `print-platform` Requirement 11 のカットオーバー手順に従って実施される。
8. THE MainWeb SHALL 本変更により改変されない。

### Requirement 5: 旧 Material_PrintMonitor の廃止と導線更新

**User Story:** 開発保守担当者として、`t_order_reports.print_status` ベースの旧印刷監視画面を廃止し、導線を共通プリント基盤の監視画面へ更新したい。そうすれば印刷監視が共通基盤に一本化され、二重管理がなくなる。

#### Acceptance Criteria

1. THE システム SHALL Material_PrintMonitor（`MaterialModule/Areas/Material/Pages/PrintMonitor`）を提供しない。
2. WHERE 既存メニュー・ナビゲーションに Material_PrintMonitor への導線が存在する、THE システム SHALL 当該導線を Common_PrintMonitor（`/Common/PrintMonitor`）へ更新する。
3. THE MaterialModule SHALL Material_PrintMonitor の廃止に伴い不要となった `t_order_reports.print_status` 参照コードを保持しない。
4. THE Common_PrintMonitor の設置・実装 SHALL `print-platform` が所有し、本 spec は導線の更新先として参照するのみとする。

### Requirement 6: 監視画面のスタイル整合

**User Story:** 利用者として、Material 側に残る監視画面が一貫したスタイルで表示されてほしい。そうすれば視認性と操作性が保たれる。

#### Acceptance Criteria

1. WHERE 本 spec の作業で Material 側（Area "Material"）に画面が残存または変更される、THE 当該画面 SHALL material-page スタイル（`<partial name="_MaterialStyles" />`、`container-fluid mt-3 px-4 material-page`、`font-size: 0.8rem`）に準拠する。
2. WHERE 監視画面が CommonModule（Area "Common"）に設置される、THE 当該画面のスタイル整合 SHALL `print-platform` が所有する。

### Requirement 7: モジュール改変原則・Spec配置の遵守

**User Story:** 開発保守担当者として、本 spec の作業がプロジェクトルールに準拠してほしい。そうすればモジュール境界とドキュメント整合が保たれる。

#### Acceptance Criteria

1. THE 本spec由来の変更 SHALL MainWeb および AuthModule のソース・設定を変更しない。
2. WHERE CommonModule のホスト登録（ModuleRegistration）変更が必要となる、THE システム SHALL 当該変更を CommonModule 側 spec の所有とし、本機能 spec から MainWeb へ変更を加えない。
3. THE 本spec成果物 SHALL `.kiro/specs/dispatch-monitoring-consolidation/`（正本）と `MaterialModule/Doc/specs/dispatch-monitoring-consolidation/`（コピー）の2箇所に同一内容で配置される。
4. THE 設計・実装 SHALL 基幹システム構築基準（`\\OJIADM23120073\Labs\sdoc\基幹システム構築基準.md`）に準拠する。
5. THE 本 spec SHALL `print-platform` と重複する受入基準（`t_print_queue` スキーマ・PrintAgent 読取先・Common_PrintMonitor 実装・カットオーバー手順）を保持せず、依存として参照する。
