# Requirements Document

## Introduction

発注処理まわりの送信（FAX）・印刷ジョブ投入を整理し、MaterialModule の監視画面を共通基盤へ集約するための要件を定義する。本 spec は **MaterialModule の関心事に集中** し、印刷の共通基盤（`t_print_queue` のスキーマ契約・PrintAgent の読取先・Common_PrintMonitor・カットオーバー手順）は別 spec `print-platform` が所有する。本 spec は当該共通基盤に **依存** する。

本 spec は次の点をまとめて扱う。

1. **二重FAXの根絶**: 発注承認時に旧FAX経路（`t_order_reports.fax_status`）と新FAX経路（`t_smtp_queue`）の双方にFAX用レコードが生成されている状態を解消し、FAXジョブを新経路（`t_smtp_queue`）へ一本化する。
2. **FAX監視の集約**: `t_order_reports.fax_status` を表示する旧FAX監視画面（Material_SmtpMonitor）を廃止し、FAX監視を CommonModule の Common_SmtpMonitor（`t_smtp_queue` ベース）へ集約する。
3. **PrintJobService の投入先変更（投入側実装）**: 承認済み発注の印刷ジョブについて、PrintJobService が印刷対象 PDF を生成・保存し、そのフルパス（`pdf_path`、必須）を付与して共通プリント基盤の共通キュー `t_print_queue`（db_common_dev）へ投入する（従来の `t_order_reports` へは生成しない）。投入先のスキーマ契約（`pdf_path` 必須・`print_payload` は持たない）・カットオーバー手順は `print-platform` に従う。
4. **PDF生成責務の移管（PrintAgent → MaterialModule）**: 従来 PrintAgent が担っていた帳票（発注書兼納入依頼書・工場入れ請求・入庫伝票 の3種）の QuestPDF レイアウト生成を送信側（MaterialModule）へ移管する。PrintAgent は印刷専用（`pdf_path` の生成済み PDF をサイレント印刷）となり、印刷イメージ（PDF）の生成は MaterialModule の責務とする。
5. **旧 Material_PrintMonitor の廃止／導線更新**: Material 側の印刷監視画面（Material_PrintMonitor）を廃止し、導線を共通プリント基盤が設置する Common_PrintMonitor へ更新する。

6. **FAX送信の接続プロファイル選定とテスト送信指定**: FAXジョブ投入時の config_key を本番 `fax`／テスト `test-fax` から選定する（旧 `Material` 廃止）。テスト送信の要否は承認画面（Approvals）の「FAXテスト送信」チェックボックスで**承認操作ごと（ジョブ単位）**に指定し、永続的・全体共有の状態を持たない（多人数同時運用での取り違え回避）。宛先解決・固定宛先モードの振る舞いは別 spec `smtp-sender` が所有する。 **【改訂 2026/07/08】** 現行実装は config_key 常に `fax`＋recipient を `m_send_config.test_fax_number` に上書きする方式（`test-fax` 選定は取り下げ）。詳細は R10 見出しの改訂ノート参照。

本 spec は **要件定義のみ** を対象とし、実装・コード変更は含まない。

### 依存関係（Dependencies）

本 spec は別 spec `print-platform`（共通プリント基盤）に依存する。以下は `print-platform` が **契約の発生元（所有者）** であり、本 spec は重複する受入基準を持たず、依存としてのみ参照する。

- **`t_print_queue` のスキーマ契約・DDL・既存データ移行**: `print-platform` Requirement 1〜3 が所有する。本 spec の PrintJobService 投入先（Requirement 4）は当該スキーマ契約に準拠する。
- **PrintJobService の投入インターフェース契約**（投入先・PrintStatus 初期値・`pdf_path` 付与（必須））: `print-platform` Requirement 4 が定義する。本 spec は当該契約に従って投入側を実装する範囲を所有する。なお、印刷イメージ（PDF）の生成そのものは `print-platform` の所有ではなく、本 spec（MaterialModule）の責務である（`print-platform` は生成済み PDF のパス受け渡し契約のみを所有）。
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
- 実DDL適用・ビルド・テスト・実送信・実印刷（いずれもユーザー側で実施）。

## Glossary

- **PrintJobService**: `MaterialModule/Services/PrintJobService.cs`。承認済み発注を発注番号グループ単位で束ね、対象帳票の印刷イメージ（PDF）を生成・保存し、そのフルパス（`pdf_path`）付きで印刷ジョブを共通プリント基盤の `t_print_queue`（db_common_dev）へ投入する資材モジュールのサービス（現状は `t_order_reports` へ生成）。帳票レイアウト（QuestPDF）の生成も本サービス側の責務とする。
- **t_order_reports**: db_material_dev に存在する資材固有テーブル。従来は `print_status`（印刷状態）と `fax_status`（旧FAX状態）の両ステータスを保持する。本 spec では FAX 用レコードを生成せず、印刷ジョブの投入先としても使用しない。
- **t_print_queue**: db_common_dev の共通テーブル。印刷ジョブのキュー。スキーマ契約・DDL・移行は `print-platform` が所有する。本 spec は PrintJobService の投入先として当該契約に準拠して参照する。
- **t_smtp_queue**: db_common_dev に存在する共通テーブル。新FAX/メール送信ジョブのキュー。order-approval-fax-mail 機能が投入し、SmtpAgent が処理する。
- **旧FAX経路**: 承認時に `t_order_reports.fax_status=1`（待機）を立てる従来のFAX送信経路。
- **新FAX経路**: 承認時に `t_smtp_queue` へFAXジョブを投入する経路（order-approval-fax-mail 機能）。
- **Material_SmtpMonitor**: `MaterialModule/Areas/Material/Pages/SmtpMonitor`。`t_order_reports.fax_status` を表示する旧FAX監視画面（廃止対象）。
- **Common_SmtpMonitor**: `CommonModule/Areas/Common/Pages/SmtpMonitor`（`/Common/SmtpMonitor`）。`t_smtp_queue` ベースの新SMTP監視画面（FAX監視の集約先）。
- **Material_PrintMonitor**: `MaterialModule/Areas/Material/Pages/PrintMonitor`。`t_order_reports.print_status` を表示する従来の印刷監視画面（本 spec の廃止対象）。
- **Common_PrintMonitor**: `CommonModule/Areas/Common/Pages/PrintMonitor`（`/Common/PrintMonitor`）。共通プリント基盤の印刷監視画面。設置・実装は `print-platform` が所有する。本 spec は導線の更新先として参照する。
- **config_key（接続プロファイルキー）**: FAX/メール送信ジョブが使用する `m_smtp_config` の接続プロファイルキー。本 spec の FAX 投入では本番 `fax`（fax_domain=`@faxmail.com`・FAX送信モード）／テスト `test-fax`（fax_domain=完全アドレス・固定宛先モード）を選定する。旧 `Material`・`test` は廃止（`smtp-sender` 所有）。**【改訂 2026/07/08】** 現行実装では config_key は**常に `fax`**（`test-fax` 選定は取り下げ）。テスト送信は recipient を `m_send_config.test_fax_number` に上書きする方式（R10 改訂ノート参照）。
- **FAXテスト送信指定**: 承認画面（Approvals）の「FAXテスト送信」チェックボックスによる、当該承認操作で投入するFAXジョブを `config_key=test-fax`（固定のテスト宛先へ送信）とするか否かの選択。永続的・全体共有の状態としては保持せず、承認操作ごとに投入する各ジョブに対してのみ適用する（多人数同時運用での競合回避）。**【改訂 2026/07/08】** 現行実装では、テスト送信指定時は config_key は `fax` のまま **recipient を `m_send_config.test_fax_number` に上書き**する（`config_key=test-fax` は取り下げ）。ジョブ単位・非共有の性質は不変。
- **SmtpAgent**: `t_smtp_queue` のみを処理する Worker Service。リファクタ済みで `t_order_reports.fax_status` は処理しない。
- **PrintAgent**: 印刷ジョブを処理する Worker Service（別ソリューション: `\\OJIADM23120073\Labs\WindowsService\PrintAgent`）。読取先変更は `print-platform` が所有する。本 spec では参照のみ。
- **PrintStatus**: 印刷状態（`print-platform` の `t_print_queue` が保持する値）。1=待機, 2=処理中, 3=完了, 9=エラー。0=対象外 は廃止（投入側ゲート化により、印刷キューには印刷対象のみを投入するため「対象外」状態を持たない）。
- **FaxStatus**: `t_order_reports.fax_status`。0=FAX対象外, 1=待機, 2=処理中, 3=完了, 9=エラー（旧経路）。
- **OutputType**: 発注の出力区分。MaterialModule 側の送信パラメータであり、`t_print_queue` には保持されない（キューには印刷対象のみが投入されるため区分を持ち込まない）。値と意味は次のとおり。0=PDF を生成・保存するのみで印刷キュー（`t_print_queue`）・FAXキュー（`t_smtp_queue`）のいずれにも投入しない（保存のみ）／1=PDF生成・保存後に印刷キュー（`t_print_queue`）へ投入／2=PDF生成・保存後に FAXキュー（`t_smtp_queue`）へ投入（既存FAX経路）／3=PDF生成・保存後に印刷＋FAX の両キューへ投入。したがって印刷キューへの投入は OutputType ∈ {1, 3}、FAXキューへの投入は OutputType ∈ {2, 3}、OutputType=0 はどちらにも投入せず PDF 保存のみとなる。
- **pdf_path**: `t_print_queue` の列。投入側（MaterialModule）が生成・保存した印刷対象 PDF のフルパス。必須（NOT NULL）であり、PrintAgent の唯一の印刷ソースである（旧 PrintPayload（印刷用 JSON）は `print-platform` の契約改訂で廃止）。
- **印刷出力パスマスタ**: 印刷出力（PDF）の保存先ベースパスを保持する DB 管理のマスタ（設定／マスタテーブル）。コード変更なしに保存先を変更可能とする（現行値 `\\ojiadm23120073\app_share\PrintAgent`、将来のクラウド移行時はマスタ値の変更で対応）。Web 側（書込）と PrintAgent（読取）の双方から到達可能なパスを保持する。テーブル・DB 配置は設計フェーズで決定する。
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

**User Story:** 発注業務担当者として、承認済み発注の印刷ジョブが、印刷対象 PDF のフルパス（`pdf_path`）付きで共通プリント基盤の共通キュー（`t_print_queue`）に投入されてほしい。そうすれば印刷監視と処理が共通基盤上で完結する。

#### Acceptance Criteria

1. THE PrintJobService SHALL 印刷ジョブを `t_print_queue`（db_common_dev）に投入する。
2. THE PrintJobService SHALL 印刷キュー（`t_print_queue`）への投入を OutputType ∈ {1, 3}（印刷対象）のグループに限定する（OutputType=0 および 2 は印刷キューへ投入しない）。
3. THE PrintJobService SHALL `t_print_queue` への投入時に OutputType を渡さない（`print-platform` の投入契約（`IPrintQueueService.EnqueueAsync`）から OutputType 引数は削除されており、印刷対象か否かの判定は投入側が行い、キューには印刷対象のみが投入される）。
4. THE PrintJobService SHALL 印刷ジョブ投入時に、生成・保存した印刷対象 PDF のフルパスを `pdf_path`（必須・非空）として付与する。
5. THE PrintJobService SHALL 投入する印刷ジョブの PrintStatus を 1（待機）に設定する。
6. THE PrintJobService SHALL 印刷ジョブを `t_order_reports` に新規生成しない。
7. THE PrintJobService の投入 SHALL `print-platform` Requirement 4 で定義される投入インターフェース契約（投入先・PrintStatus 初期値・`pdf_path` 付与（必須）、`print_payload` は用いない）に準拠する。
8. WHERE PrintJobService（MaterialModule）から共通キュー `t_print_queue` へ投入する手段が必要となる、THE 投入経路の実装形態（CommonModule の投入サービス（IPrintQueueService 等）経由か直接アクセスか）SHALL 本 spec の設計フェーズで決定される。
9. THE PrintJobService の投入先切替 SHALL `print-platform` Requirement 11 のカットオーバー手順に従って実施される。
10. THE MainWeb SHALL 本変更により改変されない。

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
3. THE 本spec成果物 SHALL `.kiro/specs/MaterialModule/dispatch-monitoring-consolidation/` に単一正本として配置される（モジュール別コピーは持たない）。
4. THE 設計・実装 SHALL 基幹システム構築基準（`\\OJIADM23120073\Labs\sdoc\基幹システム構築基準.md`）に準拠する。
5. THE 本 spec SHALL `print-platform` と重複する受入基準（`t_print_queue` スキーマ・PrintAgent 読取先・Common_PrintMonitor 実装・カットオーバー手順）を保持せず、依存として参照する。

### Requirement 8: 印刷イメージ（PDF）生成の MaterialModule 所有

**User Story:** 発注業務担当者として、印刷対象の PDF（印刷イメージ）が MaterialModule 側で生成・保存されてほしい。そうすれば PrintAgent は印刷専用となり、帳票レイアウトの変更が資材モジュール内で完結する。

#### Acceptance Criteria

1. THE MaterialModule SHALL 承認済み発注グループ単位で対象帳票の印刷イメージ（PDF）を生成する。
2. THE MaterialModule SHALL 承認済み発注グループの PDF 生成・保存を OutputType によらず（0 を含め）行い、印刷キュー（`t_print_queue`）／FAXキュー（`t_smtp_queue`）への投入のみを OutputType（印刷=1/3・FAX=2/3）で判定する（PDF は常に保存され、キューへの投入は条件付きである）。
3. THE MaterialModule SHALL 生成対象帳票として発注書兼納入依頼書・工場入れ請求・入庫伝票 の3種を含める。
4. THE MaterialModule SHALL 生成・保存した PDF の保存先フルパスを、印刷キューへ投入する場合に `pdf_path` として `t_print_queue` へ付与する。
5. THE MaterialModule SHALL 帳票レイアウト（従来 PrintAgent の Documents 相当の QuestPDF レイアウト）の生成を本 spec の責務として所有する。
6. WHERE PrintAgent が `t_print_queue` の印刷ジョブを処理する、THE PrintAgent SHALL `pdf_path` の生成済み PDF をサイレント印刷し、PDF 生成を行わない（印刷専用、`print-platform` Requirement 5 所有）。

### Requirement 9: PDF保存先パスのマスタ管理

**User Story:** 運用管理者として、印刷出力（PDF）の保存先ベースパスを DB マスタで管理したい。そうすればオンプレからクラウドへの移行などでコード変更なしに保存先を変更できる。

#### Acceptance Criteria

1. THE MaterialModule SHALL 印刷出力（PDF）の保存先ベースパスを DB マスタ（印刷出力パスマスタ）で管理する。
2. WHEN 印刷出力パスマスタの値が変更される、THE MaterialModule SHALL コード変更なしに変更後の保存先ベースパスを使用する。
3. THE 印刷出力パスマスタ SHALL 現行の保存先ベースパス値として `\\ojiadm23120073\app_share\PrintAgent` を保持する。
4. THE 印刷出力パスマスタが保持する保存先 SHALL Web 側（書込）と PrintAgent（読取）の双方から到達可能なパスである。
5. THE 印刷出力パスマスタのテーブル定義・DB 配置 SHALL 本 spec の設計フェーズで決定される。

### Requirement 10: FAX送信の接続プロファイル選定と承認画面でのテスト送信指定

**User Story:** 発注業務担当者として、発注承認時にFAX送信を本番宛先へ送るか固定のテスト宛先へ送るかを承認画面で選べるようにしたい。そうすれば実運用に影響を与えずにFAX送信を検証でき、かつ多人数が同時に操作しても取り違え（本番宛先への誤送信・テスト指定の相互干渉）が起きない。

> **【改訂 2026/07/08：現行実装＝recipient 上書き方式／以下 AC の「config_key=test-fax」は取り下げ・読み替え】** 現行（実装 `ab31934`）の正は次のとおり。以下 AC1/AC3/AC6（`test-fax` 選定・宛先を上書きしない 前提）は**無効**とし、本ノートに読み替える。
> - config_key は **本番・テストとも常に `fax`**（`test-fax` は使用しない・`FaxDispatchOptions.TestConfigKey` 廃止）。
> - テスト送信時は MaterialModule が **recipient を送信設定マスタ `m_send_config.test_fax_number` に上書き**する（未設定はスキップ＋ログ）。本番は実FAX番号。
> - 送信元 From は `m_send_config.from_address`（無ければ `FaxDispatchOptions.FromAddress` フォールバック）。
> - テスト宛先値・From の管理は spec `send-config-master`（R1/R4/R5）が所有。`smtp-sender` の固定宛先(test-fax)モードには依存しない。
> - 「承認操作ごと（ジョブ単位）・非共有・承認画面のみで指定・Common_SmtpMonitor には設けない」は不変（AC2/AC5/AC7）。

#### Acceptance Criteria

1. WHEN MaterialModule がFAXジョブを `t_smtp_queue` へ投入する、THE MaterialModule SHALL 接続プロファイルキー（config_key）に、本番送信では `fax`、テスト送信では `test-fax` を指定する（旧 `Material` は使用しない）。
2. THE 承認画面（Approvals）SHALL 「FAXテスト送信」チェックボックスを提供し、承認操作ごとにテスト送信の要否を指定できる。
3. WHERE 承認操作で「FAXテスト送信」が指定される、THE MaterialModule SHALL 当該承認で投入する全FAXジョブの config_key を `test-fax` とする。
4. WHERE 承認操作で「FAXテスト送信」が指定されない、THE MaterialModule SHALL 当該承認で投入する全FAXジョブの config_key を `fax` とする。
5. THE MaterialModule SHALL テスト送信の指定を永続的・全体共有の状態（グローバルなトグル・DB永続の共有フラグ等）として保持せず、承認操作ごとに投入する各FAXジョブに対してのみ適用する。
6. WHERE config_key が `test-fax`（固定宛先モード）である、THE MaterialModule SHALL 宛先（recipient）に実FAX番号を渡してよく、テスト用宛先の上書きを MaterialModule 側で行わない（SmtpAgent が固定宛先モードで宛先を無視して固定のテスト宛先へ送信するため）。
7. THE MaterialModule SHALL FAXテスト送信の可否指定を共通監視画面（Common_SmtpMonitor 等）に設けず、承認画面（Approvals）でのみ指定する。
8. THE FAX宛先解決・固定宛先モードの振る舞い（config_key＝`fax`/`test-fax`／宛先形式検証／固定宛先送信）SHALL 別 spec `smtp-sender`（Requirement 6・8）が所有し、本 spec は投入側の config_key 選定と承認画面での指定を所有する。
