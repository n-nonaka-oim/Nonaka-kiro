# Requirements Document

order-approval-fax-mail（発注承認時の発注書 FAX送信）

## Introduction

資材調達システム(MaterialModule)において、発注承認（個別承認／一括承認）が行われた発注について、発注書PDFを**共通SMTP送信基盤(smtp-sender)経由で FAX送信（メールtoFAX）**する機能を追加する。本機能は **FAX送信のみ**を対象とし（仕入先へのメールアドレス送信は行わない）、「SMTP連携 案C（折衷・段階移行）」の第一弾である。FAX送信は常に新経路（共通送信キュー `t_smtp_queue` 経由）に一本化し、既存の `t_order_reports.fax_status` 経由のFAX送信は行わない（二重FAX回避）。一方、印刷経路（`PrintJobService`→`t_order_reports`→PrintAgent）は従来どおり並行して維持する。

送信の実体は、MaterialModule が発注書PDFを生成して共有フォルダに保管し、共通基盤の投入ヘルパー `ISmtpQueueService.EnqueueAsync` を呼び出して共通送信キュー(`t_smtp_queue`, `db_common_dev`)へ送信ジョブを投入することで実現する。実際のSMTP送信（FAX番号正規化・FAXゲートウェイドメイン付与・添付含む）は常駐Worker `SmtpAgent` が担う。FAXゲートウェイドメインは接続プロファイルキー `Material`(fax_domain=`@faxmail.com`)を用いる。smtp-sender 基盤は実装・実証済みであり、本Specのスコープは MaterialModule 側の「発注書PDF生成・保管」「送信要否判定」「FAX番号宛先の解決」「差出人/件名/本文の構築」「キューへのジョブ投入」「二重送信防止」「承認処理との統合」に限定する。

PDF生成は送信側(MaterialModule)の責務であり、既存の `OrderPdfService.GenerateGroupOrderPdfAsync`（発注番号グループ単位・QRコード付き）を用いる。SMTP送信そのものの仕様（ポーリング・FAX正規化・添付・死活監視・手動再送）は smtp-sender Spec の対象であり、本Specでは前提として参照する。

## Glossary

- **発注承認送信機能(OrderApprovalDispatch)**: 本Specで定義する MaterialModule 側の機能全体。発注承認を契機に発注書PDFを生成・保管し、共通送信キューへ送信ジョブを投入する一連の処理を指す。
- **送信投入サービス(DispatchEnqueueService)**: 発注承認送信機能の中核となる MaterialModule 内のサービス。送信要否判定・宛先解決・差出人/件名/本文の構築・PDF保管・キュー投入・二重送信防止を担う。
- **承認サービス(ApprovalService)**: 発注の承認処理を行う既存サービス(`MaterialModule/Services/ApprovalService.cs`)。個別承認(`ApproveOrderAsync`)・一括承認(`ApproveOrdersAsync`)を提供する。
- **印刷ジョブサービス(PrintJobService)**: 承認済み発注を発注番号グループ単位で束ね、既存の印刷/FAX用帳票管理レコード(`t_order_reports`)を作成する既存サービス(`IPrintJobService.CreateOrderApprovalJobsAsync`)。
- **発注書PDFサービス(OrderPdfService)**: 発注書PDFを生成する既存サービス(`IOrderPdfService`)。`GenerateGroupOrderPdfAsync(orderNoGroup)` で発注番号グループ単位のPDF(QRコード付き)を生成する。
- **発注(TOrder)**: 発注トランザクションの1レコード。`OrderNo`(発注番号)・`OutputType`(出力区分)・`SupplierCode`/`SupplierName`(仕入先)・`DestinationFax`(送付先FAX)等を保持する。
- **発注番号グループ(OrderNoGroup)**: 発注番号の先頭3セグメント(プラント-日付-グループ番号、例: `G201-260514-001`)で束ねた単位。既存の帳票・PDFはこの単位で束ねられる。
- **出力区分(OutputType)**: 発注の出力方法を表す区分。`0`=PDF生成のみ（印刷もFAXもせず、PDFの生成・保管のみ）、`1`=ローカルプリンタへPDFをサイレント印刷（PrintAgent経由。印刷のみ）、`2`=FAXのみ（PDFを添付し SmtpAgent経由でFAX送信。印刷なし）、`3`=上記1と2（ローカルプリンタへサイレント印刷＋SmtpAgent経由でFAX送信）。本機能では `2`/`3` を共通送信キュー経由のFAX送信対象とし、`3` のサイレント印刷は既存印刷経路で行う。
- **共通SMTP送信基盤(SmtpSenderPlatform)**: smtp-sender Specで定義された全社共通の送信基盤。共通送信キュー・接続プロファイルマスタ・SmtpAgent・監視画面を含む。
- **共通送信キュー(SmtpQueue)**: 送信ジョブを保持する共通DBテーブル `t_smtp_queue`(`db_common_dev`)。
- **投入ヘルパー(SmtpQueueService)**: 共通基盤が提供する送信ジョブ投入用インターフェース `ISmtpQueueService`。`EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body, cc, bcc, pdfPath, ct)` を提供する。
- **接続プロファイルキー(config_key)**: 使用するSMTP接続プロファイルを選択する識別キー。本機能では FAX送信用に `Material`(FAXゲートウェイドメイン `@faxmail.com`)を用いる（テスト送信時も同一の実FAX経路 `Material` を用いる）。
- **仕入先マスタ(SupplierMaster)**: 仕入先情報を保持するテーブル `m_suppliers`。`SupplierCode`・`Fax`・`Tel`・`AutoFaxType` 等を保持する。メールアドレス列は保持しない。
- **送付先FAX(DestinationFax)**: 発注(`TOrder.DestinationFax`)が保持する送付先のFAX番号。
- **宛先(Recipient)**: 送信ジョブの送信先。本機能ではFAX番号(`@` を含まない値)を設定する。
- **共有フォルダ(SharedFolder)**: 生成した発注書PDFを保管し、SmtpAgent から参照可能なネットワーク共有フォルダ。本機能では `\\OJIADM23120073\app_share\PrintAgent` 配下を用いる。
- **添付PDFパス(PdfPath)**: 共有フォルダに保管した発注書PDFのフルパス。`EnqueueAsync` の `pdfPath` 引数として渡す。
- **テスト送信(TestSend)**: 本番の仕入先FAX番号へ送らず、宛先(`recipient`)をダミーのFAX番号に上書きして送信する動作。実FAX経路(`config_key=Material`)を用いる。正常系テスト用のダミーFAX番号は `06-6487-1033`、エラーチェック用はありえない（無効な）FAX番号を指定できる。
- **送信履歴(DispatchHistory)**: 二重送信防止のために発注番号グループごとの送信投入実績を記録する MaterialModule 側の記録（新規の列またはテーブル、`row_version` 付き。具体構造は設計で確定）。
- **送信ステータス(JobStatus)**: 共通送信キューのジョブ状態。待機=1 / 処理中=2 / 完了=3 / エラー=9。
- **会社情報サービス(MasterService)**: 会社情報を取得する既存サービス。`IMasterService.GetCompanyInfoAsync(userId)` で発注者ベースの会社情報(`MCompanyInfo`)を取得する。

## Requirements

### Requirement 1: CommonModule への参照追加

**User Story:** MaterialModule の開発者として、共通SMTP送信基盤の投入ヘルパーを利用したい。そうすれば Worker の実装を知らずに発注書を送信依頼できる。

#### Acceptance Criteria

1. THE MaterialModule SHALL CommonModule をプロジェクト参照(ProjectReference)として追加する。
2. THE 発注承認送信機能 SHALL CommonModule の投入ヘルパー(`ISmtpQueueService`)を依存性注入(DI)経由で取得して使用する。
3. THE 発注承認送信機能 SHALL 共通送信キュー(`t_smtp_queue`)への列の読み書きを直接行わず、投入ヘルパー(`ISmtpQueueService.EnqueueAsync`)経由でのみ送信ジョブを投入する。

### Requirement 2: 発注承認を契機とする送信投入

**User Story:** 資材担当者として、発注を承認したときに発注書が仕入先へ自動で送信されてほしい。そうすれば承認後の手作業の送付を削減できる。

#### Acceptance Criteria

1. WHEN 承認サービスが個別承認(`ApproveOrderAsync`)で発注を承認しステータスを30(回答待ち)に更新する、THE 発注承認送信機能 SHALL 当該発注を含む送信対象について送信ジョブの投入を実行する。
2. WHEN 承認サービスが一括承認(`ApproveOrdersAsync`)で複数の発注を承認する、THE 発注承認送信機能 SHALL 承認された全発注を送信対象として送信ジョブの投入を実行する。
3. WHEN 送信ジョブの投入を実行する、THE 発注承認送信機能 SHALL 発注番号(`OrderNo`)が採番済みの発注のみを送信対象とする。
4. THE 発注承認送信機能 SHALL 既存の印刷ジョブ作成(`PrintJobService.CreateOrderApprovalJobsAsync`)を停止・置換せず、これに追加する形で送信ジョブを投入する。

### Requirement 3: 送信単位（発注番号グループ）

**User Story:** 資材担当者として、複数明細を1通の発注書としてまとめて送りたい。そうすれば既存の帳票と同じ単位で仕入先に届けられる。

#### Acceptance Criteria

1. THE 発注承認送信機能 SHALL 送信対象の発注を発注番号グループ(`OrderNo` の先頭3セグメント)単位で束ねる。
2. WHEN 発注を発注番号グループ単位で束ねる、THE 発注承認送信機能 SHALL 1つの発注番号グループにつき1件の送信ジョブを投入する。
3. WHEN 発注書PDFを生成する、THE 発注承認送信機能 SHALL 発注番号グループ単位で `OrderPdfService.GenerateGroupOrderPdfAsync(orderNoGroup)` を呼び出して1つのPDFを生成する。

### Requirement 4: 送信要否の判定

**User Story:** 資材担当者として、FAX送信が必要な発注だけを送信してほしい。そうすれば印刷のみの発注を誤ってFAX送信せずに済む。

#### Acceptance Criteria

1. WHERE 発注番号グループ内に出力区分(`OutputType`)が2(FAXのみ)または3(サイレント印刷+FAX)の発注が1件以上含まれる、THE 発注承認送信機能 SHALL 当該発注番号グループを共通送信キュー経由のFAX送信対象とする。
2. WHERE 発注番号グループ内の全発注の出力区分(`OutputType`)が0(PDF生成のみ)または1(サイレント印刷のみ)である、THE 発注承認送信機能 SHALL 当該発注番号グループの送信ジョブを投入しない。
3. WHEN 出力区分(`OutputType`)が3(サイレント印刷+FAX)の発注を処理する、THE 発注承認送信機能 SHALL 既存の印刷経路(`PrintJobService`→`t_order_reports`→PrintAgent)によるサイレント印刷を維持しつつ、FAX送信は共通送信キュー経由でのみ行う。
4. WHEN FAX送信を行う、THE 発注承認送信機能 SHALL 既存の帳票管理レコード(`t_order_reports.fax_status`)経由のFAX送信を行わず、常に共通送信キュー(`t_smtp_queue`)経由で送信する。
5. IF 送信対象の発注番号グループについて有効な宛先(FAX番号)を解決できない、THEN THE 発注承認送信機能 SHALL 当該発注番号グループの送信ジョブを投入せず、その旨をログに記録する。
6. WHEN 送信対象でない発注番号グループを処理する、THE 発注承認送信機能 SHALL 当該グループの承認処理を成功として継続する。

### Requirement 5: 宛先（FAX番号）の解決

**User Story:** 資材担当者として、仕入先のFAX番号へ正しく届けてほしい。そうすれば発注書を仕入先のFAXに送付できる。

#### Acceptance Criteria

1. WHEN 送信対象の発注番号グループの宛先を解決する、THE 発注承認送信機能 SHALL 当該グループの代表発注の仕入先コード(`SupplierCode`)で仕入先マスタ(`m_suppliers`)を引き、または発注の送付先FAX(`TOrder.DestinationFax`)からFAX番号を取得する。
2. WHEN FAX番号宛先を設定する、THE 発注承認送信機能 SHALL 取得したFAX番号(`@` を含まない値)を宛先(`recipient`)に設定する。
3. WHEN 宛先にFAX番号を設定する、THE 発注承認送信機能 SHALL FAX番号の正規化(数字抽出・先頭0→81・ドメイン付与)を自身で行わず、共通SMTP送信基盤(SmtpAgent)に委ねる。
4. IF 解決した宛先が空文字または空白のみである、THEN THE 発注承認送信機能 SHALL 当該発注番号グループの送信ジョブを投入せず、その旨をログに記録する。

> 設計で確定: 宛先FAX番号のソースとして仕入先マスタ(`m_suppliers.Fax`)と発注の送付先FAX(`TOrder.DestinationFax`)のどちらを優先・使用するか。

### Requirement 6: 発注書PDFの生成・保管・受け渡し

**User Story:** 資材担当者として、発注書PDFが共有フォルダに保管され、その実体が仕入先へ添付送信されてほしい。そうすれば相手が発注内容を確認できる。

#### Acceptance Criteria

1. WHEN 送信対象の発注番号グループを処理する、THE 発注承認送信機能 SHALL `OrderPdfService.GenerateGroupOrderPdfAsync(orderNoGroup)` で発注書PDFを生成する。
2. WHEN 発注書PDFを生成する、THE 発注承認送信機能 SHALL 当該PDFを共有フォルダ `\\OJIADM23120073\app_share\PrintAgent` 配下に保管する。
3. WHEN 発注書PDFを共有フォルダに保管する、THE 発注承認送信機能 SHALL 発注番号グループを含む一意なファイル名で保管する。
4. WHEN 送信ジョブを投入する、THE 発注承認送信機能 SHALL 保管したPDFのフルパスを投入ヘルパーの添付PDFパス(`pdfPath`)引数として渡す。
5. THE 発注承認送信機能 SHALL 保管した発注書PDFを当面保持し、自動削除（後始末）を行わない。
6. IF 発注書PDFの生成または保管に失敗した、THEN THE 発注承認送信機能 SHALL 当該発注番号グループの送信ジョブを投入せず、その旨をログに記録する。

### Requirement 7: 差出人・件名・本文の構築

**User Story:** 仕入先として、誰からの何の発注書かが分かる形でFAXを受け取りたい。そうすれば問い合わせ先と内容を把握できる。

#### Acceptance Criteria

1. WHEN 送信ジョブを投入する、THE 発注承認送信機能 SHALL 会社情報サービス(`IMasterService.GetCompanyInfoAsync`)から取得した会社情報および発注担当者情報を用いて送信元アドレス(`from_address`)および送信元名(`from_name`)を構築する。
2. WHEN 送信ジョブを投入する、THE 発注承認送信機能 SHALL 発注番号グループおよび会社名等を含む定型の件名(`subject`)（例: 「発注書 {発注番号グループ}」）を設定する。
3. WHEN 送信ジョブを投入する、THE 発注承認送信機能 SHALL 定型文の本文(`body`)を設定する。
4. WHEN 送信ジョブを投入する、THE 発注承認送信機能 SHALL モジュール識別(`module`)に `material` を指定する。
5. IF 送信元アドレス(`from_address`)を構築できない、THEN THE 発注承認送信機能 SHALL 当該発注番号グループの送信ジョブを投入せず、その旨をログに記録する。

> 設計で確定: 件名・本文の最終文面。

### Requirement 8: テスト送信への切り替え

**User Story:** テスト担当者として、本番の仕入先へ送らずダミーのFAX番号へ送信したい。そうすれば実運用に影響を与えず送信動作とエラー処理を検証できる。

#### Acceptance Criteria

1. WHERE テスト送信が有効である、THE 発注承認送信機能 SHALL 送信ジョブの接続プロファイルキー(`config_key`)に実FAX経路の `Material` を指定する。
2. WHERE テスト送信が有効である、THE 発注承認送信機能 SHALL 送信ジョブの宛先(`recipient`)を仕入先のFAX番号ではなく設定されたダミーのFAX番号に上書きする。
3. WHERE テスト送信が有効かつ正常系テストである、THE 発注承認送信機能 SHALL 宛先(`recipient`)にダミーFAX番号 `06-6487-1033` を設定できる。
4. WHERE テスト送信が有効かつエラーチェック用である、THE 発注承認送信機能 SHALL 宛先(`recipient`)にありえない（無効な）FAX番号を設定できる。
5. WHERE テスト送信が無効である、THE 発注承認送信機能 SHALL 送信ジョブの接続プロファイルキー(`config_key`)に `Material` を指定し、宛先(`recipient`)に実際の仕入先FAX番号を設定する。
6. THE 発注承認送信機能 SHALL テスト送信の有効/無効およびダミーFAX番号を MaterialModule 側の設定(`appsettings` 等)で保持する。

### Requirement 9: 二重送信の防止

**User Story:** 資材担当者として、同じ発注を再承認しても発注書が二重に送られないようにしたい。そうすれば仕入先への重複送付を防げる。

#### Acceptance Criteria

1. WHEN 送信対象の発注番号グループの送信ジョブを投入する、THE 発注承認送信機能 SHALL 当該発注番号グループについて送信投入済みであることを送信履歴(`DispatchHistory`)に記録する。
2. IF 既に送信投入済みの発注番号グループについて再度送信投入が要求された、THEN THE 発注承認送信機能 SHALL 送信履歴を参照して当該発注番号グループの送信ジョブを再投入せず、その旨をログに記録する。
3. WHEN 同一の承認操作内で同一の発注番号グループに属する複数の発注を処理する、THE 発注承認送信機能 SHALL 当該発注番号グループにつき送信ジョブを1件のみ投入する。

> 設計で確定: 送信履歴(`DispatchHistory`)の具体構造（新規テーブルか既存テーブルへの列追加か）。

### Requirement 10: 送信投入失敗時の扱い

**User Story:** 資材担当者として、送信の投入に失敗しても承認自体は完了してほしい。そうすれば送信トラブルで承認業務が止まらない。

#### Acceptance Criteria

1. IF 送信ジョブの投入処理中に例外が発生した、THEN THE 発注承認送信機能 SHALL 当該例外を記録し、承認サービスの承認処理を成功として完了させる。
2. WHEN 1つの発注番号グループの送信投入に失敗する、THE 発注承認送信機能 SHALL 他の発注番号グループの送信投入を継続する。
3. THE 発注承認送信機能 SHALL 共通送信キューへ投入したジョブの実送信失敗時の再送を自ら行わず、共通SMTP送信基盤の手動再送(監視画面)に委ねる。

### Requirement 11: 既存印刷経路との並行運用とFAX経路の一本化

**User Story:** 運用担当者として、既存の印刷送信を残したままFAX送信を新経路に一本化したい。そうすれば移行中に印刷が止まるリスクを避けつつ、FAXの二重送信を防げる。

#### Acceptance Criteria

1. THE 発注承認送信機能 SHALL 既存の印刷経路(`PrintJobService`→`t_order_reports`→PrintAgent)を削除せず並行して維持する。
2. THE 発注承認送信機能 SHALL FAX送信を常に共通送信キュー(`t_smtp_queue`)経由の新経路に一本化し、既存の `t_order_reports.fax_status` 経由のFAX送信を行わない。
3. THE 発注承認送信機能 SHALL 既存の `PrintJobService.CreateOrderApprovalJobsAsync` の印刷に関する動作を変更しない。

### Requirement 12: 排他制御・整合性の遵守

**User Story:** 運用担当者として、多人数同時操作でも送信投入が整合的に行われてほしい。そうすればデータ競合による不整合を防げる。

#### Acceptance Criteria

1. THE 発注承認送信機能 SHALL プロジェクト共通ルール(`.kiro/steering/project-rules.md`)の排他制御・楽観的ロック方針に従う。
2. WHERE 送信投入済みの記録を MaterialModule 側のエンティティに新規追加する、THE 発注承認送信機能 SHALL 当該エンティティに `row_version` カラム(`[Timestamp]`)を含める。
3. WHEN 承認処理と送信投入を同一の業務操作として実行する、THE 発注承認送信機能 SHALL 承認による発注の状態更新が確定した後に送信投入を行う。

## 未確定事項（設計フェーズで確定）

以下は設計フェーズで確定する論点である。

1. **宛先FAX番号のソース**: 仕入先マスタ(`m_suppliers.Fax`)と発注の送付先FAX(`TOrder.DestinationFax`)のどちらを優先・使用するか。Requirement 5 に反映する。
2. **送信履歴の具体構造**: 二重送信防止の送信履歴(`DispatchHistory`)を新規テーブルで持つか既存テーブルへの列追加で持つか（いずれも `row_version` 付き）。Requirement 9・12 に反映する。
3. **件名・本文の最終文面**: 定型件名・本文の最終的な文言。Requirement 7 に反映する。

## スコープ外

- 共通SMTP送信基盤(SmtpAgent)側のSMTP送信処理（ポーリング・FAX番号正規化・PDF添付・複数宛先/CC/BCC・死活監視・手動再送）。これらは smtp-sender Spec の対象とする。
- 既存の印刷経路(`t_order_reports`→PrintAgent)の削除・統廃合。印刷は従来どおり並行維持する。
- 発注書PDFのフォーマット変更（既存 `OrderPdfService` の出力を流用する）。
- 仕入先へのメール送信（メールアドレス宛先解決・メールtoメール送信）。本機能はFAX送信のみを対象とし、メール送信は将来対応の可能性として扱う。
- 共有フォルダに保管したPDFの自動削除（後始末）。当面は手動運用とする。
- 監視画面・再送UIの追加（共通基盤の監視画面を利用する）。
