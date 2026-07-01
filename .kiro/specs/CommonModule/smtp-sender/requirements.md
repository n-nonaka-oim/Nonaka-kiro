# Requirements Document

smtp-sender（SMTP送信汎用基盤）

## Introduction

資材調達システム(MaterialModule)で実装・動作実証済みのメールtoFAX送信(SmtpAgent)を、全社の他モジュールからも利用できる**共通のSMTP送信基盤**として汎用化する。

本基盤は、送信元となる各モジュールが**共通送信キュー**(`t_smtp_queue`)に送信ジョブを投入し、オンプレ常駐の Worker Service (`SmtpAgent`) がそのキューのみをポーリングして SMTP 送信を実行する、疎結合な構成とする。SMTP 送信先のゲートウェイへメールを送ることで FAX 送信を行う「メールtoFAX」方式と、メールアドレス宛の通常メール送信の両方に対応する。

SMTP の接続情報(接続先ホスト・ポート・FAXゲートウェイドメイン)は共通設定マスタ(`m_smtp_config`)で**複数行の接続プロファイル**として一元管理する。各接続プロファイルは識別キー(`config_key`)を持ち、送信元モジュールは送信ジョブに `config_key` を指定して使用する接続プロファイルを選択する。一方、送信元アドレス・送信元名・宛先・件名・本文・添付PDFパスは**送信ジョブが保持**し、モジュールごと・送信内容ごとに可変とする。Worker の死活監視(`m_smtp_agent_control`)を含め、これらは資材固有DBから分離して共通DB `db_common_dev` に新設する。

今回のスコープは **SMTP 送信のみ**とする。印刷(Print)の共通化、帳票フォーマットのマスタ化(テンプレートエンジン)、および各モジュールからの実際の移行作業は本Specの対象外とし、PDF 生成は各モジュールの責務とする。既存の資材FAX送信経路(`t_order_reports.fax_status`)および既存 Print/Smtp ページは削除せず**並行運用**で残し、新基盤への移行・動作確認が完了した後に削除する。

## Glossary

- **SMTP送信基盤(SmtpSenderPlatform)**: 本Specで定義する全社共通のSMTP送信の仕組み全体。共通送信キュー・接続プロファイルマスタ・Worker・監視画面を含む。
- **SmtpAgent**: オンプレミスに常駐する .NET8 Worker Service。共通送信キューをポーリングして SMTP 送信(メールtoFAX含む)を実行する。配置場所は `\\OJIADM23120073\Labs\WindowsService\SmtpAgent`。
- **送信元モジュール(ProducerModule)**: 共通送信キューに送信ジョブを投入する各業務モジュール(MaterialModule など)。
- **共通送信キュー(SmtpQueue)**: 送信ジョブを保持する共通DBテーブル `t_smtp_queue`。
- **送信ジョブ(SmtpJob)**: `t_smtp_queue` の 1 レコード。1 件の送信要求を表す。送信元アドレス・送信元名・宛先(To)・CC・BCC・件名・本文・添付PDFパス・使用する接続プロファイルキー(`config_key`)を保持する。
- **宛先(To/Recipient)**: 送信ジョブの主宛先。`t_smtp_queue.recipient` 列で保持する。複数宛先区切り(`;`)で複数の宛先トークンを保持できる。少なくとも 1 件の有効な宛先を必須とする。
- **CC(CarbonCopy)**: 送信ジョブの CC 宛先。`t_smtp_queue.cc` 列で保持する。複数宛先区切り(`;`)で複数のメールアドレスを保持できる。任意項目であり、未指定(NULL/空)を許容する。
- **BCC(BlindCarbonCopy)**: 送信ジョブの BCC 宛先。`t_smtp_queue.bcc` 列で保持する。複数宛先区切り(`;`)で複数のメールアドレスを保持できる。任意項目であり、未指定(NULL/空)を許容する。
- **宛先トークン(RecipientToken)**: 宛先・CC・BCC の各列の値を複数宛先区切り(`;`)で分割した各要素。前後の空白を除去(trim)して扱う。trim 後に空文字となるトークンは無視する。
- **複数宛先区切り(RecipientDelimiter)**: 宛先(To)・CC・BCC の各列に複数の宛先を指定する際の区切り文字。セミコロン(`;`)とする。
- **接続プロファイルマスタ(SmtpConfig)**: 共通DBテーブル `m_smtp_config`。SMTP の接続情報を**複数行の接続プロファイル**として保持する。各行の列は `config_key`(PK)・`host`・`port`・`fax_domain` のみ。
- **接続プロファイル(ConnectionProfile)**: `m_smtp_config` の 1 レコード。1 つの SMTP 接続先設定(ホスト・ポート・FAXゲートウェイドメイン)を表す。
- **接続プロファイルキー(config_key)**: 接続プロファイルを識別する主キー。送信ジョブが使用する接続プロファイルを選択するために保持する(例: `Material`, `test`)。
- **死活監視レコード(AgentControl)**: 共通DBテーブル `m_smtp_agent_control`。SmtpAgent の最終応答時刻を保持する 1 行運用のテーブル。
- **監視画面(SmtpMonitor)**: 送信ジョブの状況と SmtpAgent の死活を表示する全モジュール横断の共通Web画面。
- **メールtoFAX(MailToFax)**: FAXゲートウェイのドメイン宛にメールを送信することで FAX 送信を行う方式。
- **FAXゲートウェイドメイン(FaxGatewayDomain)**: メールtoFAX で宛先に付与するドメイン(例: `@faxmail.com`)。接続プロファイルの `fax_domain` で保持する。空の場合は宛先をメールアドレスとして直送する(FAX番号変換・ドメイン付与を行わない)。
- **メール直送(DirectMail)**: 宛先をメールアドレスとしてそのまま使用する送信方式。FAX番号正規化・ドメイン付与を行わない。
- **共通DB(CommonDatabase)**: 全社共通テーブルを配置するデータベース `db_common_dev`。
- **送信ステータス(JobStatus)**: 送信ジョブの状態。待機=1 / 処理中=2 / 完了=3 / エラー=9。
- **死活閾値(HeartbeatThreshold)**: SmtpAgent を「応答なし」と判定するまでの最終応答からの経過時間。既定値は 30 秒。
- **テスト実施フラグ(TestSendFlag)**: 送信元モジュールが保持する、テスト送信を行うか否かの設定。テスト時は `test` 用接続プロファイル(`fax_domain` 空)を `config_key` に指定し、宛先にテスト用メールアドレスを設定して投入する。テスト用の送信パラメータは各モジュール側のマスタ/設定で保持する。

## Requirements

### Requirement 1: 共通DBへの送信基盤テーブル配置

**User Story:** 全社の開発者として、SMTP送信に関わるテーブルを共通DBに配置してほしい。そうすれば資材固有DBに依存せず、どのモジュールからも送信基盤を利用できる。

#### Acceptance Criteria

1. THE SMTP送信基盤 SHALL 共通送信キュー(`t_smtp_queue`)・接続プロファイルマスタ(`m_smtp_config`)・死活監視レコード(`m_smtp_agent_control`)を共通DB(`db_common_dev`)に配置する。
2. THE 接続プロファイルマスタ SHALL 共通DB(`db_common_dev`)に複数行の接続プロファイルとして保持される。
3. THE 死活監視レコード SHALL 共通DB(`db_common_dev`)に 1 行のレコードとして保持される。
4. THE SMTP送信基盤 SHALL 資材固有DB(`db_material_dev`)の既存テーブル(`t_order_reports` 等)に依存せず動作する。
5. THE SMTP送信基盤 SHALL 接続プロファイルマスタと死活監視レコードがそれぞれ独立して存在することを許容する。

### Requirement 2: 接続プロファイルマスタによる接続情報の一元管理

**User Story:** 運用担当者として、SMTP の接続先をプロファイルとして複数管理したい。そうすれば本番FAX用とテスト用の接続を切り替えながら、接続情報を共通マスタで一元管理できる。

#### Acceptance Criteria

1. THE 接続プロファイルマスタ SHALL 各接続プロファイルについて、接続プロファイルキー(`config_key`)・接続先ホスト(`host`)・ポート(`port`)・FAXゲートウェイドメイン(`fax_domain`)を保持する。
2. THE 接続プロファイルマスタ SHALL 接続プロファイルキー(`config_key`)を主キーとして各接続プロファイルを一意に識別する。
3. THE 接続プロファイルマスタ SHALL 送信元アドレス・送信元名・テスト送信先・PDF保管先ディレクトリを保持しない。
4. WHERE 接続プロファイルの FAXゲートウェイドメイン(`fax_domain`)が設定されている、THE 接続プロファイル SHALL メールtoFAX 用の接続として扱われる。
5. WHERE 接続プロファイルの FAXゲートウェイドメイン(`fax_domain`)が空である、THE 接続プロファイル SHALL メール直送用の接続として扱われる。

### Requirement 3: 共通送信キューへのジョブ投入

**User Story:** 送信元モジュールの開発者として、共通送信キューに送信ジョブを投入したい。そうすれば Worker の実装を知らなくても SMTP 送信を依頼できる。

#### Acceptance Criteria

1. THE 共通送信キュー SHALL 各送信ジョブについて、モジュール識別(`module`)・接続プロファイルキー(`config_key`)・送信元アドレス(`from_address`)・送信元名(`from_name`)・宛先(`recipient`)・CC(`cc`)・BCC(`bcc`)・件名(`subject`)・本文(`body`)・添付PDFパス(`pdf_path`)・送信ステータス(`status`)・取得日時(`picked_at`)・完了日時(`completed_at`)・エラー内容(`error_message`)・作成日時(`created_at`)・更新日時(`updated_at`)・`row_version` を保持する。
2. WHEN 送信元モジュールが送信ジョブを投入する、THE 共通送信キュー SHALL 当該ジョブの送信ステータスを待機(1)として登録する。
3. THE 共通送信キュー SHALL 各送信ジョブを投入したモジュールをモジュール識別(`module`)の値で区別する。
4. WHEN 送信元モジュールが送信ジョブを投入する、THE 共通送信キュー SHALL 当該ジョブに使用する接続プロファイルキー(`config_key`)を保持する。
5. WHEN 送信元モジュールが送信ジョブを投入する、THE 共通送信キュー SHALL 当該ジョブの送信元アドレス(`from_address`)および送信元名(`from_name`)を保持する。
6. WHERE 送信ジョブに添付PDFパスが指定されない、THE SMTP送信基盤 SHALL 当該ジョブを添付なし送信として受け付ける。
7. THE 共通送信キュー SHALL 各送信ジョブに `row_version` カラムを保持し、楽観的ロックによる競合検出を可能にする。
8. THE 共通送信キュー SHALL 宛先(`recipient`)列に複数宛先区切り(`;`)で区切られた複数の宛先トークンを保持できる長さ(`nvarchar(1000)`)を持つ。
9. THE 共通送信キュー SHALL CC(`cc`)列および BCC(`bcc`)列を保持し、各列は複数宛先区切り(`;`)で区切られた複数のメールアドレスを保持できる長さ(`nvarchar(1000)`)を持つ。
10. THE 共通送信キュー SHALL CC(`cc`)列および BCC(`bcc`)列について NULL および空文字を許容する。
11. WHEN 送信元モジュールが送信ジョブを投入する、THE 投入ヘルパー(`EnqueueAsync`) SHALL CC(`cc`)およびBCC(`bcc`)を任意引数として受け付け、未指定の場合は当該列を NULL として登録する。
12. WHEN 送信元モジュールが送信ジョブを投入する、THE 投入ヘルパー(`EnqueueAsync`) SHALL 宛先(`recipient`)・CC(`cc`)・BCC(`bcc`)に複数宛先区切り(`;`)で区切られた複数の宛先を指定した値をそのまま当該列へ登録する。

### Requirement 4: 送信ジョブのポーリングと排他取得

**User Story:** 運用担当者として、SmtpAgent が共通送信キューのみを監視して順次処理してほしい。そうすれば送信元モジュールと Worker が疎結合に保たれる。

#### Acceptance Criteria

1. THE SmtpAgent SHALL 共通送信キュー(`t_smtp_queue`)のみをポーリング対象とする。
2. WHEN ポーリングを実行する、THE SmtpAgent SHALL 送信ステータスが待機(1)のジョブを作成日時の昇順で 1 件取得する。
3. WHEN 待機(1)のジョブを取得する、THE SmtpAgent SHALL 当該ジョブの送信ステータスを処理中(2)に更新し、取得日時を記録する。
4. IF 取得しようとしたジョブが他インスタンスによって既に取得されている(楽観的ロックの競合)、THEN THE SmtpAgent SHALL 当該ジョブをスキップして次のポーリングを継続する。
5. WHEN 待機(1)のジョブが存在しない、THE SmtpAgent SHALL 送信を行わず次のポーリングまで待機する。

### Requirement 5: 接続プロファイルの解決とSMTP送信の実行

**User Story:** 運用担当者として、SmtpAgent がジョブの接続プロファイルキーから接続情報を解決して送信してほしい。そうすればジョブごとに接続先を切り替えて送信できる。

#### Acceptance Criteria

1. WHEN 送信ジョブを送信する、THE SmtpAgent SHALL 当該ジョブの接続プロファイルキー(`config_key`)で接続プロファイルマスタを引き、接続先ホスト(`host`)・ポート(`port`)・FAXゲートウェイドメイン(`fax_domain`)を解決する。
2. IF 送信ジョブの接続プロファイルキーに該当する接続プロファイルが接続プロファイルマスタに存在しない、THEN THE SmtpAgent SHALL 当該ジョブを送信せずエラー(9)として記録する。
3. THE SmtpAgent SHALL 解決した接続先ホスト・ポート(既定 `172.16.128.81` / `25`)へ接続して送信する。
4. THE SmtpAgent SHALL 暗号化なし・SMTP認証なしで SMTP サーバへ接続する。
5. WHEN 送信ジョブを送信する、THE SmtpAgent SHALL 当該ジョブの送信元アドレス(`from_address`)および送信元名(`from_name`)を差出人として使用する。
6. WHEN 送信ジョブを送信する、THE SmtpAgent SHALL 当該ジョブの件名を SMTP メッセージの件名に設定する。
7. WHEN 送信が正常に完了する、THE SmtpAgent SHALL 当該ジョブの送信ステータスを完了(3)に更新し、完了日時を記録する。

### Requirement 6: 宛先の解決(メールtoFAX判定とメール直送)

**User Story:** 送信元モジュールの開発者として、宛先が FAX 番号でもメールアドレスでも、また接続プロファイルが FAX 用でもメール直送用でも、正しく送信先が決定されてほしい。そうすれば宛先種別や接続種別を都度意識せずにジョブを投入できる。

#### Acceptance Criteria

1. WHERE 送信ジョブの宛先が `@` を含む、THE SmtpAgent SHALL FAXゲートウェイドメインの設定に関わらず当該宛先をメールアドレスとしてそのまま送信先に使用する。
2. WHERE 選択された接続プロファイルの FAXゲートウェイドメイン(`fax_domain`)が空である、THE SmtpAgent SHALL 当該宛先をメールアドレスとしてそのまま送信先に使用し、FAX番号正規化・ドメイン付与を行わない。
3. WHERE 選択された接続プロファイルの FAXゲートウェイドメイン(`fax_domain`)が設定されており、かつ宛先が `@` を含まない、THE SmtpAgent SHALL 当該宛先を FAX 番号として正規化する。
4. WHEN FAX 番号を正規化する、THE SmtpAgent SHALL 数字以外の文字(ハイフン等)を除去する。
5. WHEN 正規化後の FAX 番号が先頭に `0` を持つ、THE SmtpAgent SHALL 先頭の `0` を `81` に置換する。
6. WHEN FAX 番号の正規化が完了する、THE SmtpAgent SHALL 正規化後の番号に FAXゲートウェイドメイン(`fax_domain`)を付与して送信先メールアドレスを生成する。
7. IF 送信ジョブの宛先が空、THEN THE SmtpAgent SHALL 当該ジョブを送信せずエラー(9)として記録する。
8. IF FAX 番号として正規化した結果が数字を 1 文字も含まない、THEN THE SmtpAgent SHALL 当該ジョブを送信せずエラー(9)として記録する。
9. WHEN 送信ジョブの宛先(`recipient`)を解決する、THE SmtpAgent SHALL 当該宛先を複数宛先区切り(`;`)で宛先トークンに分割し、各トークンの前後の空白を除去(trim)する。
10. WHEN 宛先(`recipient`)を宛先トークンに分割する、THE SmtpAgent SHALL trim 後に空文字となる宛先トークンを無視する。
11. WHEN 宛先(`recipient`)の各宛先トークンを解決する、THE SmtpAgent SHALL 受け入れ基準1〜6の宛先解決ロジック(① `@` 含む→直送 / ② `fax_domain` 空→直送 / ③ `fax_domain` 設定済かつ `@` 含まない→FAX正規化)を宛先トークンごとに適用して送信先を生成する。
12. WHEN 宛先(`recipient`)の全宛先トークンを解決する、THE SmtpAgent SHALL 生成した各送信先を SMTP メッセージの To 宛先として設定する。
13. IF 宛先(`recipient`)を分割した結果、有効な宛先トークンが 1 件も存在しない、THEN THE SmtpAgent SHALL 当該ジョブを送信せずエラー(9)として記録する。

### Requirement 7: PDF添付

**User Story:** 送信元モジュールの開発者として、共有フォルダに保管した PDF をフルパスで指定して添付送信したい。そうすれば共通設定に保管先を持たせずに帳票を相手に届けられる。

#### Acceptance Criteria

1. THE 送信ジョブ SHALL 添付する PDF を添付PDFパス(`pdf_path`)にフルパスで保持する。
2. THE SMTP送信基盤 SHALL PDF保管先ディレクトリの共通設定を保持しない。
3. WHERE 送信ジョブに添付PDFパスが指定され、かつ当該パスのファイルが実在する、THE SmtpAgent SHALL 当該 PDF を SMTP メッセージに添付して送信する。
4. WHERE 送信ジョブに添付PDFパスが指定されない、THE SmtpAgent SHALL 添付なしで送信する。
5. IF 送信ジョブに添付PDFパスが指定されているが当該パスのファイルが実在しない、THEN THE SmtpAgent SHALL 添付なしで送信し、その旨をログに記録する。

### Requirement 8: 送信側によるテスト送信の制御

**User Story:** テスト担当者として、本番FAX宛先に送らず特定のテスト用メールアドレスへ送りたい。そうすれば実運用に影響を与えずに送信動作を検証できる。

#### Acceptance Criteria

1. WHERE 送信元モジュールのテスト実施フラグが有効である、THE 送信元モジュール SHALL 送信ジョブの接続プロファイルキー(`config_key`)に `test` 用接続プロファイル(FAXゲートウェイドメインが空)を指定して投入する。
2. WHERE 送信元モジュールのテスト実施フラグが有効である、THE 送信元モジュール SHALL 送信ジョブの宛先(`recipient`)にテスト用メールアドレスを指定して投入する。
3. THE 送信元モジュール SHALL テスト用の送信パラメータ(テスト用メールアドレス等)を自モジュール側のマスタ/設定で保持する。
4. WHEN テスト送信のジョブを処理する、THE SmtpAgent SHALL 接続プロファイルの FAXゲートウェイドメインが空であるため宛先をメールアドレスとしてそのまま送信先に使用する。
5. THE 接続プロファイルマスタ SHALL 全送信ジョブの宛先を一律に上書きするテスト送信先を保持しない。

### Requirement 9: 死活監視

**User Story:** 運用担当者として、SmtpAgent が稼働中かどうかを画面で確認したい。そうすれば応答が止まったときに障害対応できる。

#### Acceptance Criteria

1. WHEN ポーリングを実行する、THE SmtpAgent SHALL 死活監視レコードの最終応答時刻(`last_heartbeat_at`)を現在時刻(UTC)に更新する。
2. WHEN ポーリングを実行する、THE SmtpAgent SHALL 死活監視レコードに稼働マシン名を記録する。
3. WHILE 死活監視レコードの最終応答時刻が現在時刻から死活閾値(既定30秒)以内である、THE 監視画面 SHALL SmtpAgent の状態を「ポーリング中」と表示する。
4. WHILE 死活監視レコードの最終応答時刻が現在時刻から死活閾値(既定30秒)を超過している、THE 監視画面 SHALL SmtpAgent の状態を「応答なし」と表示する。
5. IF 死活監視レコードの更新に失敗した、THEN THE SmtpAgent SHALL 当該失敗をログに記録し、ポーリング処理を継続する。

### Requirement 10: エラー時の扱いと手動再送

**User Story:** 運用担当者として、送信に失敗したジョブを画面から手動で再送したい。そうすれば自動リトライによる多重送信を避けつつ、確認のうえ再送できる。

#### Acceptance Criteria

1. IF 送信ジョブの送信処理中に例外が発生した、THEN THE SmtpAgent SHALL 当該ジョブの送信ステータスをエラー(9)に更新し、エラー内容を記録する。
2. THE SmtpAgent SHALL エラー(9)となった送信ジョブを自動的に再送しない。
3. WHEN 運用担当者が監視画面でエラー(9)のジョブを再送対象に指定する、THE 監視画面 SHALL 当該ジョブの送信ステータスを待機(1)に戻す。
4. WHEN 運用担当者が監視画面で完了(3)のジョブを再送対象に指定する、THE 監視画面 SHALL 当該ジョブの送信ステータスを待機(1)に戻す。
5. WHEN 送信ジョブの送信ステータスが待機(1)に戻される、THE SmtpAgent SHALL 当該ジョブを後続のいずれかのポーリングで再取得して送信する。
6. THE 監視画面 SHALL エラー(9)のジョブのエラー内容を運用担当者に表示する。

### Requirement 11: 監視画面の共通配置

**User Story:** 全社の運用担当者として、送信状況を全モジュール横断の共通画面で確認したい。そうすれば資材専用に限定されず、どのモジュールの送信も一元的に監視できる。

#### Acceptance Criteria

1. THE 監視画面 SHALL 全モジュール横断の共通画面として配置される。
2. THE 監視画面 SHALL 資材専用ページとして配置されない。
3. THE 監視画面 SHALL 共通送信キューの全送信ジョブを、投入元モジュールを問わず表示する。
4. THE 監視画面 SHALL 各送信ジョブの投入元モジュールを識別できる形で表示する。
5. THE 監視画面 SHALL 各送信ジョブの送信ステータス(待機/処理中/完了/エラー)を表示する。

### Requirement 12: 段階的移行と並行運用

**User Story:** 運用担当者として、既存の資材FAX送信経路を残したまま新基盤を導入したい。そうすれば移行中に送信が止まるリスクを避けられる。

#### Acceptance Criteria

1. THE SMTP送信基盤 SHALL 既存の資材FAX送信経路(`t_order_reports.fax_status`)を削除せず並行して残す。
2. THE SMTP送信基盤 SHALL 既存の Print ページおよび Smtp ページを削除せず並行して残す。
3. THE SMTP送信基盤 SHALL 共通送信キュー経由の送信と既存の資材FAX送信経路を同時に稼働できる。

### Requirement 13: CC・BCC の付与(複数宛先・メール直送前提)

**User Story:** 送信元モジュールの開発者として、送信ジョブに CC・BCC を複数指定したい。そうすれば関係者にメールの写しを同時に届けられる。

#### Acceptance Criteria

1. WHERE 送信ジョブの CC(`cc`)が未指定(NULL または空)である、THE SmtpAgent SHALL SMTP メッセージに CC ヘッダを付与しない。
2. WHERE 送信ジョブの BCC(`bcc`)が未指定(NULL または空)である、THE SmtpAgent SHALL SMTP メッセージに BCC ヘッダを付与しない。
3. WHERE 送信ジョブの CC(`cc`)が指定されている、THE SmtpAgent SHALL 当該 CC を複数宛先区切り(`;`)で宛先トークンに分割し、各トークンの前後の空白を除去(trim)する。
4. WHERE 送信ジョブの BCC(`bcc`)が指定されている、THE SmtpAgent SHALL 当該 BCC を複数宛先区切り(`;`)で宛先トークンに分割し、各トークンの前後の空白を除去(trim)する。
5. WHEN CC(`cc`)または BCC(`bcc`)を宛先トークンに分割する、THE SmtpAgent SHALL trim 後に空文字となる宛先トークンを無視する。
6. WHEN CC(`cc`)または BCC(`bcc`)の各宛先トークンを送信先に変換する、THE SmtpAgent SHALL 当該トークンを trim 後のメールアドレスとしてそのまま使用し、FAXゲートウェイドメインの設定に関わらず FAX 番号正規化・ドメイン付与を行わない。
7. WHEN CC(`cc`)の有効な宛先トークンが 1 件以上存在する、THE SmtpAgent SHALL 各トークンを SMTP メッセージの CC 宛先として設定する。
8. WHEN BCC(`bcc`)の有効な宛先トークンが 1 件以上存在する、THE SmtpAgent SHALL 各トークンを SMTP メッセージの BCC 宛先として設定する。

## スコープ外

- 印刷(Print)の共通化(別Specで対応)
- 帳票フォーマットのマスタ化(テンプレートエンジン)。PDF 生成は各モジュールの責務とする。
- 各モジュールからの実際の移行作業および既存経路の削除
- SMTP の暗号化・認証対応(固定IP許可・暗号化なし・認証なしの前提)
- 自動リトライ機能
- 送信元モジュール側のテスト用送信パラメータ(テスト用メールアドレス等)の管理機構。各モジュールの責務とする。
