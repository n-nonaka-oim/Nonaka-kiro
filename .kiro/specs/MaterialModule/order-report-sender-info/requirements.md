# 要件定義書

## はじめに

発注書兼納入依頼書 PDF（MaterialModule）に印字する**発注元（自社）情報**を、発注者本人の認証基盤情報（SharedCore）から取得することを主とする改修。発注者に紐づく会社名・工場名（主所属 Section）と、郵便番号・住所・電話番号・FAX番号・氏名（`ApplicationUser`）を印字し、SharedCore 側が空白/NULL の項目は従来マスタから補完（フィールド単位フォールバック）する。

あわせて、補完元マスタ `m_company_info` を `m_general_personal_info` に改名し、メールアドレス列を追加する。追加した `email` は発注承認メール（FAX含む）送信時の**差出人アドレスが未設定の場合のフォールバック**として利用する。

本改修は MaterialModule 内で完結し、clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure）は読み取り参照のみで変更しない。

## 用語集

- **発注書PDF**: 発注書兼納入依頼書 PDF。`OrderPdfService.GenerateOrderPdfAsync`（単票）および `GenerateGroupOrderPdfAsync`（グループ）で生成される。
- **発注元情報**: 発注書PDF 右上に印字する自社側の会社名・工場名・郵便・住所・TEL・FAX・担当。
- **発注者**: 発注（t_orders）を起票したユーザー。`t_orders.user_id` に**ログイン名（`User.Identity.Name` ＝ `ApplicationUser.UserName`）**が格納される。
- **ApplicationUser**: SharedCore の認証ユーザーモデル（dbAuthTest の `m_user`）。`postal_code`（郵便）・`address`（住所）・`fax_number`（FAX）・`extension_number`（内線）・`employee_code`・氏名各列を保持し、標準 `PhoneNumber`（TEL）・`Email`（メール）を持つ。
- **Section**: SharedCore の組織モデル。`Company`（会社名）・`Office`（事業所/工場名）・`Department`（部）・`Unit1..5` の階層を持つ。
- **主所属**: 発注者の `is_main = true` の所属。`IUserRepository.GetMainUserSectionAsync(userId)` で `Section` を含めて取得（`userId` は `ApplicationUser.Id`）。
- **UserManager**: ASP.NET Core Identity の `UserManager<ApplicationUser>`。`FindByNameAsync(userName)` でログイン名からユーザーを解決する（SharedCore 非改変で利用可能）。
- **補完マスタ**: 改名後の `m_general_personal_info`（旧 `m_company_info`）。MaterialModule の DB（db_material_dev）に属する。`user_code` で発注者に紐づき、該当が無ければ `user_code = "DEFAULT"` 行にフォールバックする。
- **フィールド単位フォールバック**: 発注元情報の各項目について、SharedCore の値が非空ならそれを、空白/NULL なら補完マスタの対応値を用いる解決方式（各項目独立）。
- **発注承認送信**: `DispatchEnqueueService.EnqueueOrderApprovalFaxAsync` による発注承認 FAX/メールの共通送信キュー投入処理。

## 要件

### 要件 1: 発注元情報の SharedCore からの取得

**ユーザーストーリー:** 資材担当者として、発注書PDF の発注元情報が発注者本人の登録情報（会社・工場・郵便・住所・TEL・FAX・氏名）で印字されることで、発注者ごとに正しい情報が相手先へ伝わるようにしたい。

#### 受入基準

1. WHEN 発注書PDF を生成する, THE 発注書PDF SHALL `UserManager<ApplicationUser>.FindByNameAsync(発注者のログイン名 ＝ t_orders.user_id)` により発注者の `ApplicationUser` を解決する。
2. WHEN `ApplicationUser` を解決できた, THE 発注書PDF SHALL `IUserRepository.GetMainUserSectionAsync(ApplicationUser.Id)` により発注者の主所属 `Section` を取得する。
3. THE 発注書PDF SHALL 「会社名」を `Section.Company` から取得する。
4. THE 発注書PDF SHALL 「工場名（事業所名）」を `Section.Office` から取得する。
5. THE 発注書PDF SHALL 「郵便」を `ApplicationUser.PostalCode` から取得する。
6. THE 発注書PDF SHALL 「住所」を `ApplicationUser.Address` から取得する。
7. THE 発注書PDF SHALL 「TEL」を `ApplicationUser.PhoneNumber` から取得する。
8. THE 発注書PDF SHALL 「FAX」を `ApplicationUser.FaxNumber` から取得する。
9. THE 発注書PDF SHALL 「担当」を `ApplicationUser.LastName`（姓のみ）から取得する。
10. WHERE 単票PDF（`GenerateOrderPdfAsync`）およびグループPDF（`GenerateGroupOrderPdfAsync`）の双方において, THE 発注書PDF SHALL 同一の発注元情報解決ロジックを適用する。

### 要件 2: フィールド単位フォールバック

**ユーザーストーリー:** 資材担当者として、SharedCore に未入力の項目があってもマスタの値で補完されることで、発注書の発注元情報欄が空欄にならないようにしたい。

#### 受入基準

1. IF `Section.Company` が NULL または空白, THEN THE 発注書PDF SHALL 「会社名」を補完マスタの `company_name_1` から取得する。
2. IF `Section.Office` が NULL または空白, THEN THE 発注書PDF SHALL 「工場名」を補完マスタの `department_name_1` から取得する。
3. IF `ApplicationUser.PostalCode` が NULL または空白, THEN THE 発注書PDF SHALL 「郵便」を補完マスタの `zip_code` から取得する。
4. IF `ApplicationUser.Address` が NULL または空白, THEN THE 発注書PDF SHALL 「住所」を補完マスタの `address_1` から取得する。
5. IF `ApplicationUser.PhoneNumber` が NULL または空白, THEN THE 発注書PDF SHALL 「TEL」を補完マスタの `tel` から取得する。
6. IF `ApplicationUser.FaxNumber` が NULL または空白, THEN THE 発注書PDF SHALL 「FAX」を補完マスタの `fax` から取得する。
7. IF `ApplicationUser.LastName` が NULL または空白, THEN THE 発注書PDF SHALL 「担当」を従来スナップショット（`t_orders.user_last_name` ＝空なら `t_orders.user_name`）から取得する。
8. IF `FindByNameAsync` が発注者を解決できない（該当ユーザーなし）, THEN THE 発注書PDF SHALL 発注元情報の全項目を補完マスタ（担当のみ t_orders スナップショット）から取得する。
9. THE フィールド単位フォールバック SHALL 各項目を独立に判定する（ある項目がフォールバックしても他項目は SharedCore 値を優先する）。

### 要件 3: 受入工場（マスタ維持）

**ユーザーストーリー:** 資材担当者として、明細下部の受入工場が従来どおり表示されることで、既存帳票の表示が変わらないようにしたい。

#### 受入基準

1. THE 発注書PDF SHALL 「受入工場」を補完マスタの `simple_name` から取得する（従来どおり・本改修で変更しない）。

### 要件 4: 補完マスタの改名とメール列追加

**ユーザーストーリー:** 開発者として、補完マスタを用途に即した名称に改め、メールアドレスを保持できるようにすることで、送信時のフォールバックに備えたい。

#### 受入基準

1. THE 補完マスタ SHALL テーブル名を `m_company_info` から `m_general_personal_info` に改名する。
2. THE `m_general_personal_info` テーブル SHALL 既存の列構成（`id`・`user_code`・`simple_name`・`company_name_1`・`department_name_1`・`company_name_2`・`department_name_2`・`zip_code`・`address_1`・`address_2`・`tel`・`fax`・`is_active`・`created_at`・`updated_at`）を保持する。
3. THE `m_general_personal_info` テーブル SHALL メールアドレス列 `email`（`nvarchar(256)`・NULL 許可）を追加する。
4. THE エンティティ SHALL `MCompanyInfo` を `MGeneralPersonalInfo` に改名し、`[Table("m_general_personal_info")]` を指定し、`Email` プロパティ（`[Column("email")]`・nullable string）を追加する。
5. THE `MaterialDbContext` および `MasterService` SHALL 改名後のエンティティ・テーブルを参照するよう更新する。
6. WHERE テーブル改名・列追加は破壊的変更を伴う, THE スキーマ変更 SHALL 適用用 SQL を用意し、実行はユーザーが行う。

### 要件 5: メールアドレスの利用（送信時の差出人フォールバック）

**ユーザーストーリー:** 資材担当者として、送信設定に差出人アドレスが無い場合でも発注者のメールで送信されることで、発注承認メール（FAX）が差出人未設定で止まらないようにしたい。

#### 受入基準

1. THE 発注書PDF SHALL 発注元情報として「メールアドレス」を印字しない。
2. WHEN 発注承認送信で差出人アドレスを解決する, THE 発注承認送信 SHALL `m_send_config.from_address` を最優先で使用する。
3. IF `m_send_config.from_address` が NULL または空白, THEN THE 発注承認送信 SHALL 発注者の `ApplicationUser.Email` を差出人アドレスに使用する。
4. IF `ApplicationUser.Email` も NULL または空白, THEN THE 発注承認送信 SHALL 補完マスタ `m_general_personal_info.email` を差出人アドレスに使用する。
5. IF 上記いずれも NULL または空白, THEN THE 発注承認送信 SHALL 既存の `FaxDispatchOptions.FromAddress` を差出人アドレスに使用する（従来動作を維持）。

### 要件 6: 補完マスタの解決キー（後方互換）

**ユーザーストーリー:** 資材担当者として、従来どおり発注者に対応するマスタ行が引かれることで、既存の発注元情報の見え方が維持されるようにしたい。

#### 受入基準

1. THE 補完マスタの取得 SHALL `user_code == 発注者のログイン名（t_orders.user_id）` かつ `is_active = 1` の行を検索する。
2. IF 該当行が存在しない, THEN THE 補完マスタの取得 SHALL `user_code == "DEFAULT"` かつ `is_active = 1` の行を返す（従来動作を維持）。

### 要件 7: 変更スコープの限定（clnCoCore 非改変）

**ユーザーストーリー:** 開発者として、認証基盤（clnCoCore）に手を入れずに本機能を実現することで、他モジュールへの影響とリスクを避けたい。

#### 受入基準

1. THE 本改修 SHALL MaterialModule 配下のみを変更対象とする。
2. THE 本改修 SHALL SharedCore の `ApplicationUser`・`Section`・`IUserRepository`・`UserManager<ApplicationUser>` を読み取り参照のみで利用し、MainWeb / AuthModule / SharedCore / SharedInfrastructure を変更しない。
3. THE 本改修 SHALL 認証基盤ユーザー情報（dbAuthTest）へ**直接アクセスしない**（dbAuthTest への DbContext・接続文字列を MaterialModule に持たない）。取得は SharedCore の抽象（`IUserRepository` / `UserManager<ApplicationUser>`）経由に限定する（DBパス・テーブル名変更時のリスク回避）。
4. THE 発注者ごとの郵便・住所・TEL 等の編集UI（マイアカウント等）の追加・変更 SHALL 本改修のスコープ外とする（必要な場合は Auth/プラットフォーム側の別 spec が担う）。

### 要件 8: ドキュメント整合

**ユーザーストーリー:** 開発者として、スキーマ変更が定義書に反映されることで、以後の設計・運用でテーブル構成を正しく参照できるようにしたい。

#### 受入基準

1. WHEN `m_company_info` の改名・列追加を実施した, THE `.kiro/docs/db/テーブル定義書.md` SHALL `m_general_personal_info`（改名・`email` 列追加）を反映する。
2. WHEN テーブル構成に変更が生じた, THE `.kiro/docs/db/ER図.md` SHALL 必要に応じて更新する（テーブル名変更・列追加を反映）。
