# Requirements Document

## Introduction

発注エントリ画面（Orders/Create）の登録モーダル内にある出力区分セレクトの既定値は、現在「3（印刷/FAX）」がハードコードされている。本機能では、この既定値をユーザーごとに設定可能とし、モーダルを開いた際の初期選択にユーザー固有の「既定出力区分」を反映する。設定は既存の自己サービス画面 `PrintSettings/Index` に集約し、保持先として新規テーブル `m_user_order_setting` を用いる。未設定時は現行踏襲で「3（印刷/FAX）」をフォールバックとする。本機能は MaterialModule 内で完結し、clnCoCore（MainWeb / AuthModule / SharedCore）は変更しない。

## Glossary

- **Order_Entry_Modal**: 発注エントリ画面 `Areas/Material/.../Orders/Create` の登録モーダル。出力区分セレクト（`asp-for="Order.OutputType"`）を含む。
- **Output_Type**: 出力区分コード。値域は 0=出力なし / 1=印刷 / 2=FAX / 3=印刷/FAX の 4 値。
- **Default_Output_Type**: ユーザーごとに設定する既定の出力区分。値域は Output_Type と同じ 0/1/2/3。
- **User_Order_Setting**: ユーザーの発注関連設定を保持する新規テーブル `m_user_order_setting`（1ユーザー1行、キー = user_code）。
- **Print_Settings_Page**: 既存の自己サービス設定画面 `Areas/Material/Pages/PrintSettings/Index`。本人が自分の設定を編集・保存する。
- **Fallback_Output_Type**: Default_Output_Type が未設定・不正な場合に適用する既定値「3（印刷/FAX）」。
- **User_Code**: ログイン中のユーザーを一意に識別するコード。

## Requirements

### Requirement 1: 発注エントリモーダルの既定出力区分初期表示

**User Story:** 発注担当者として、発注エントリの登録モーダルを開いたとき、自分の既定出力区分が初期選択されていてほしい。毎回手動で選び直す手間を減らすため。

#### Acceptance Criteria

1. WHEN Order_Entry_Modal が開かれ、かつ User_Order_Setting に該当 User_Code の Default_Output_Type が存在する、THE Order_Entry_Modal SHALL 出力区分セレクトの初期選択値を当該 Default_Output_Type に設定する。
2. IF Order_Entry_Modal が開かれた時点で該当 User_Code の Default_Output_Type が存在しない、THEN THE Order_Entry_Modal SHALL 出力区分セレクトの初期選択値を Fallback_Output_Type（3）に設定する。
3. IF 取得した Default_Output_Type の値が 0/1/2/3 のいずれでもない、THEN THE Order_Entry_Modal SHALL 出力区分セレクトの初期選択値を Fallback_Output_Type（3）に設定する。
4. WHEN 発注担当者が Order_Entry_Modal 内で出力区分を初期選択値から変更する、THE Order_Entry_Modal SHALL 変更後の値を当該エントリの出力区分として保持する。
5. THE Order_Entry_Modal SHALL 既存の発注登録・保存挙動を Default_Output_Type の初期表示以外について変更せず維持する。

### Requirement 2: 既定出力区分の保持

**User Story:** システム管理者として、ユーザーごとの既定出力区分を1ユーザー1行で永続化したい。多人数同時利用でも設定が正しく保たれるようにするため。

#### Acceptance Criteria

1. THE User_Order_Setting SHALL User_Code を主キーとして 1 ユーザーにつき 1 行で Default_Output_Type を保持する。
2. THE User_Order_Setting SHALL Default_Output_Type として 0/1/2/3 のいずれかの値のみを保持する。
3. THE User_Order_Setting SHALL 楽観的ロック用の row_version 列（[Timestamp]）を保持する。
4. WHEN User_Order_Setting の行が新規作成される、THE User_Order_Setting SHALL created_at と updated_at を記録する。
5. WHEN User_Order_Setting の既存行が更新される、THE User_Order_Setting SHALL updated_at を更新後の時刻に設定する。

### Requirement 3: 既定出力区分の設定UI（PrintSettings への集約）

**User Story:** 発注担当者として、既存の帳票設定画面から自分の既定出力区分を選んで保存したい。設定場所を1画面に集約して分かりやすくするため。

#### Acceptance Criteria

1. THE Print_Settings_Page SHALL 本人の Default_Output_Type を選択するための select（選択肢 0=出力なし / 1=印刷 / 2=FAX / 3=印刷/FAX）を表示する。
2. WHEN Print_Settings_Page が表示され、かつ該当 User_Code の Default_Output_Type が存在する、THE Print_Settings_Page SHALL select の初期選択値を当該 Default_Output_Type に設定する。
3. IF Print_Settings_Page 表示時に該当 User_Code の Default_Output_Type が存在しない、THEN THE Print_Settings_Page SHALL select の初期選択値を Fallback_Output_Type（3）に設定する。
4. WHEN 発注担当者が select で 0/1/2/3 のいずれかを選択して保存を実行する、THE Print_Settings_Page SHALL 当該 User_Code の Default_Output_Type を選択値で User_Order_Setting に保存する。
5. IF 保存要求の Default_Output_Type が 0/1/2/3 のいずれでもない、THEN THE Print_Settings_Page SHALL 保存を拒否し、入力が不正である旨を表示する。
6. IF 保存時に row_version の不一致による DbUpdateConcurrencyException が発生する、THEN THE Print_Settings_Page SHALL 「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示する。

### Requirement 4: スコープと文書整備

**User Story:** 開発者として、本機能を MaterialModule 内で完結させ、DB変更を関連文書に反映したい。モジュール改変原則を守り、DB定義の整合を保つため。

#### Acceptance Criteria

1. THE MaterialModule SHALL 本機能の実装（テーブル・エンティティ・UI・初期表示ロジック）を MaterialModule 内で完結させ、clnCoCore（MainWeb / AuthModule / SharedCore）を変更しない。
2. THE MaterialModule SHALL `m_user_order_setting` を作成する冪等なスキーマ定義SQL（create_m_user_order_setting.sql）を提供する。
3. WHEN `m_user_order_setting` テーブルが追加される、THE MaterialModule SHALL `.kiro/docs/db/テーブル定義書.md` を当該テーブル定義で更新する。
4. WHEN `m_user_order_setting` テーブルが追加される、THE MaterialModule SHALL `.kiro/docs/db/ER図.md` を当該テーブルのリレーションで更新する。
