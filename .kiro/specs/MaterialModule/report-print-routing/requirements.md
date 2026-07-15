# 要件定義書

## はじめに

MaterialModule の帳票（発注書兼納入依頼書・入庫伝票・原材料工場入請求）について、PDF の**出力方式を3種類に整理**し、ページ・ユーザー・システム設定に応じて出し分ける改修。

- **PDFプリント**：操作ユーザーのローカルPC既定プリンタへ、ブラウザの印刷ダイアログで出力（Web が PDF を HTTP 配信）。
- **PDFエージェント**：サーバ登録プリンタへ、PrintAgent がサイレント出力。出力プリンタは**ユーザー毎に割当**（自己サービス設定）。
- **SMTPエージェント**：メール／FAX 送信（既存の発注承認送信＝共通送信キュー経由を踏襲）。

生成PDFは固定パス `\\OJIADM23120073\app_share\PrintAgent\`（既存 `m_print_output_path`）へ単一保管する。ユーザーが選択できるサーバ登録プリンタ一覧は CommonModule の `IPrinterQueryService`（別 spec `printer-list-query` で追加）から取得する。本改修は MaterialModule 内で完結し、clnCoCore（MainWeb/AuthModule/SharedCore/SharedInfrastructure）は変更しない。ページのアクセス制御（コンテンツ認可）は認可側で行う（本 spec の対象外）。

## 用語集

- **PDFプリント / PDFエージェント / SMTPエージェント**：上記3出力方式。
- **ユーザー印刷設定**：ユーザーが自分の PDFエージェント出力プリンタ（サーバ登録プリンタ名）を**帳票種別ごと**に設定・保持する情報。MaterialModule 側のマスタ（`m_user_print_setting`：`user_code`×`report_type`→`printer_name`）で保持。
- **帳票種別（report_type）**：帳票の識別コード（例：`order_approval`＝発注書兼納入依頼書、`dispatch_request`＝原材料工場入請求、`receiving`＝入庫伝票）。
- **システム印刷設定**：Dispatches(ii) の外部出力フラグと出力プリンタを保持するシステム設定。MaterialModule 側のマスタ（`m_print_system_setting`）で保持。
- **外部出力フラグ**：Dispatches「原材料工場入請求」の(ii) サーバ登録プリンタへの PDFエージェント出力の ON/OFF を、**システム設定**で制御する値（ユーザーは制御不可）。
- **テスト出力**：エージェント方式の疎通確認。本番フロー（承認・請求等）を経由せず即時に出力する。
- **出力区分（OutputType）**：発注の出力種別。0=出力なし／1=印刷／2=FAX／3=印刷+FAX。
- **PrintAgent**：サーバ/オンプレのサイレント印刷エージェント。`t_print_queue`（CommonModule `IPrintQueueService`）へ printer_name 指定で投入されたジョブを SumatraPDF で印刷する。
- **IPrinterQueryService**：CommonModule のサーバ登録プリンタ一覧 読み取りI/F（`printer-list-query`）。

## 要件

### 要件 1: 出力方式と対象帳票のマッピング

**ユーザーストーリー:** 資材担当者として、帳票ごとに適切な出力方式で印刷/送信されることで、業務に応じた出力先へ確実に届けたい。

#### 受入基準

1. THE 改修 SHALL 出力方式を PDFプリント／PDFエージェント／SMTPエージェント の3種に分類する。
2. THE Orders/Create（発注書兼納入依頼書）SHALL Approvals 承認後に、出力区分に従って出力する（0=出力なし／1=印刷=PDFエージェント／2=FAX=SMTPエージェント／3=印刷+FAX=両方）。
3. THE Dispatches（原材料工場入請求）SHALL 「請求」押下時に、(i) PDFプリント（ユーザー設定）と (ii) PDFエージェント（外部出力フラグON時のみ）を出力する。
4. THE Receivings（入庫伝票）SHALL 「入庫伝票」押下時に、PDFプリント（ユーザー設定）で出力する。
5. THE 生成PDF SHALL 固定パス（`m_print_output_path` の保存先）へ保管する。

### 要件 2: PDFプリント（ローカル既定・ダイアログ）

**ユーザーストーリー:** 現場ユーザーとして、自分のPCの既定プリンタへ手元で印刷できることで、追加の登録なしにすぐ出力したい。

#### 受入基準

1. WHEN PDFプリントを行う, THE Web(MainWeb) SHALL 生成PDFを HTTP レスポンス（`application/pdf`）としてブラウザへ配信する。
2. THE 改修 SHALL ブラウザへ UNC/ファイルパス（`file://\\...`）を渡さない（HTTPでバイトを渡す）。
3. WHEN ブラウザがPDFを受領した, THE クライアント SHALL 印刷ダイアログ経由でローカル既定プリンタへ印刷する（サイレントは要求しない）。
4. THE PDFプリント SHALL サーバ登録プリンタやユーザー印刷設定に依存しない。

### 要件 3: PDFエージェント（サーバ登録プリンタ・サイレント・ユーザー割当）

**ユーザーストーリー:** 現場ユーザーとして、自分に割り当てたサーバ登録プリンタへ無確認で印刷されることで、確実にサイレント出力したい。

#### 受入基準

1. WHEN PDFエージェント出力を行う, THE 改修 SHALL CommonModule `IPrintQueueService.EnqueueAsync` に **printer_name を指定**して `t_print_queue` へ投入する。
2. THE printer_name SHALL 対象ユーザー×**帳票種別**のユーザー印刷設定（割当プリンタ）から解決する。
3. IF 対象ユーザー×帳票種別に割当プリンタが未設定, THEN THE 改修 SHALL 投入せず**クライアントにエラーを表示**する（サーバ既定への自動フォールバックはしない）。
4. THE PDFエージェント SHALL 生成PDFを固定保管パスに保存し、そのフルパスを投入ジョブの pdf_path に設定する（既存の生成・保存一元化＝二重生成回避を踏襲）。
5. WHERE Orders/Create（発注書）の PDFエージェント出力, THE printer_name SHALL 発注の発注者（`t_orders.user_id`）×帳票種別 `order_approval` のユーザー印刷設定から解決する。

### 要件 4: SMTPエージェント（メール/FAX 送信）

**ユーザーストーリー:** 資材担当者として、発注書をFAX/メールで送付できることで、仕入先へ確実に届けたい。

#### 受入基準

1. WHEN SMTPエージェント出力を行う, THE 改修 SHALL 既存の発注承認送信（`DispatchEnqueueService`→共通送信キュー）を踏襲して投入する。
2. THE SMTPエージェント SHALL 既存の宛先解決・差出人解決・二重送信防止の仕様を維持する。

### 要件 5: ユーザー印刷設定（自己サービス）

**ユーザーストーリー:** 現場ユーザーとして、自分の PDFエージェント出力プリンタを自分で設定できることで、管理者を介さず運用したい。

#### 受入基準

1. THE 改修 SHALL ユーザー印刷設定を保持するマスタ `m_user_print_setting`（`user_code`・`report_type`・`printer_name`・監査列・`row_version`）を MaterialModule 側に追加する。
2. THE 改修 SHALL ユーザー自身が自分の割当プリンタを**帳票種別ごとに**設定・変更できる**自己サービス画面**を提供する。
3. THE 自己サービス画面 SHALL 選択元プリンタ一覧を CommonModule `IPrinterQueryService.GetAvailablePrintersAsync` から取得して表示する。
4. THE 改修 SHALL ログインユーザー自身の設定のみを対象とする（他ユーザー分は編集しない）。
5. THE ユーザー印刷設定の更新 SHALL 楽観的ロック（`row_version`）で競合を検出する。
6. THE `m_user_print_setting` SHALL `user_code`×`report_type` を一意とする。
7. WHERE ページのアクセス可否（コンテンツ認可）, THE 制御 SHALL 認可側（m_content/r_content_auth）に委ね、本 spec では実装しない。

### 要件 6: 外部出力フラグ（システム設定）

**ユーザーストーリー:** システム管理者として、Dispatches のサーバプリンタ出力を ON/OFF できることで、運用状況に応じて自動印刷を制御したい。

#### 受入基準

1. THE 改修 SHALL Dispatches(ii) の外部出力フラグと出力プリンタを保持するマスタ `m_print_system_setting`（`report_type`・`external_output_enabled`・`printer_name`・監査列・`row_version`）を MaterialModule 側に追加する。
2. WHEN Dispatches「請求」押下時に `m_print_system_setting` の外部出力フラグが ON, THE 改修 SHALL (ii) のサーバ登録プリンタへ PDFエージェント出力を行う。
3. WHEN 外部出力フラグが OFF, THE 改修 SHALL (ii) の出力を行わない（(i) PDFプリントは実施）。
4. THE (ii) の出力プリンタ SHALL `m_print_system_setting.printer_name`（システム設定）で保持する（ユーザー割当ではない）。
5. THE ユーザー SHALL (ii) の出力有無・出力プリンタを変更できない。

### 要件 7: Orders/Create 出力区分連動（承認後・同時投入）

**ユーザーストーリー:** 資材担当者として、承認時に出力区分どおりに印刷とFAXが行われることで、指定どおりの経路で発注書が処理されるようにしたい。

#### 受入基準

1. WHEN 発注が承認された（Approvals）, THE 改修 SHALL 出力区分に従い出力する：0=何もしない／1=PDFエージェント／2=SMTPエージェント／3=PDFエージェント+SMTPエージェント。
2. WHERE 出力区分が 3, THE 改修 SHALL PDFエージェント（印刷）と SMTPエージェント（FAX）を**同時に投入**する。
3. THE 出力区分3の同時投入 SHALL PDF の**二重生成を回避**する（既存の生成・保存一元化を踏襲）。

### 要件 8: Dispatches 2カ所出力

**ユーザーストーリー:** 現場ユーザーとして、原材料工場入請求を手元とサーバ登録プリンタの両方へ出せることで、必要な拠点で確実に紙出力したい。

#### 受入基準

1. WHEN Dispatches「請求」押下, THE 改修 SHALL (i) PDFプリント（ローカル既定）を実施する。
2. WHEN Dispatches「請求」押下 かつ 外部出力フラグON, THE 改修 SHALL (ii) PDFエージェント（サーバ登録プリンタ）を追加で実施する（合計2カ所）。
3. THE (i) と (ii) SHALL 同一の生成PDFを用い、二重生成を回避する。

### 要件 9: テスト出力（エージェント時のみ）

**ユーザーストーリー:** 現場ユーザーとして、印刷/送信の疎通を自分でテストできることで、本番前に出力先の正常性を確認したい。

#### 受入基準

1. WHERE 出力にエージェント方式（PDFエージェント／SMTPエージェント）を用いるページ, THE 改修 SHALL 「テスト出力」チェックボックスを提供する（PDFプリントのみのページには設けない）。
2. WHEN テスト出力チェックボックスが ON で実行された, THE 改修 SHALL 本番フロー（承認・請求等）を経由せず即時にテスト出力する。
3. WHERE テスト出力かつ PDFエージェント, THE 改修 SHALL 実行ユーザー自身の割当プリンタへ出力する。
4. WHERE テスト出力かつ SMTPエージェント, THE 改修 SHALL 送信先を**実行ユーザー自身のメールアドレス**にして本番宛先へは送らない（誤送信防止）。宛先解決順＝`ApplicationUser.Email`（操作ユーザーの account メール）→ 空なら `GetGeneralPersonalInfoAsync`（`user_code` 一致→無ければ `DEFAULT` 行）の `email`。
5. IF テスト出力かつ PDFエージェントで割当プリンタが未設定, THEN THE 改修 SHALL クライアントにエラーを表示する。

### 要件 10: 変更スコープ

**ユーザーストーリー:** 開発者として、変更範囲を限定することで、他モジュールへの影響を避けたい。

#### 受入基準

1. THE 本改修 SHALL MaterialModule 配下のみを変更対象とする。
2. THE 本改修 SHALL CommonModule の `IPrinterQueryService`・`IPrintQueueService`・送信系I/F を**インターフェース経由で利用**し、CommonModule の DbContext を直接参照しない。
3. THE 本改修 SHALL clnCoCore（MainWeb/AuthModule/SharedCore/SharedInfrastructure）を変更しない。
4. WHERE DBスキーマ変更（`m_user_print_setting` 追加・外部出力設定の保持先）を伴う, THE 変更 SHALL 適用用 SQL を用意し、実行はユーザーが行う。

### 要件 11: ドキュメント整合

**ユーザーストーリー:** 開発者として、スキーマ・設計の変更が定義書に反映されることで、以後の参照を正しく保ちたい。

#### 受入基準

1. WHEN `m_user_print_setting`・`m_print_system_setting` を追加した, THE `.kiro/docs/db/テーブル定義書.md`・`ER図.md` SHALL 反映する。
