# Requirements Document

## Introduction

原材料工場入請求画面（MaterialModule / `Areas/Material/Pages/Dispatches/Index.cshtml`）の未登録（pending）ビューにある「印刷」チェックボックス（`id="chkPdfOutput"`・送信プロパティ名 `PdfOutput`）は、現在マークアップ上で `checked` がハードコードされ、常に初期状態 ON で表示される。本機能では、この初期チェック状態をユーザーごとに設定した「印刷既定（ON/OFF）」に従って表示する。

設定値は既存の per-user 設定マスタ `m_user_order_setting`（1ユーザー1行）に列 `dispatch_print_default`（bit、既定 1=ON）を追加して保持し、既存列 `default_output_type` は変更しない。設定 UI は既存の自己サービス画面 `PrintSettings/Index` に集約し、既存「発注エントリ 既定出力区分」の近くに「原材料工場入請求 印刷 既定（ON/OFF）」チェックボックスを追加する。未設定時のフォールバックは現行踏襲で ON とする。

適用範囲は `chkPdfOutput` の初期チェック状態のみであり、ユーザーが画面で切り替えた値・請求時の `PdfOutput` 分岐・外部出力（PDFエージェント）・その他の挙動は一切変更しない。本機能は MaterialModule 内で完結し、clnCoCore（MainWeb / AuthModule / SharedCore）は変更しない。

## Glossary

- **MaterialModule**: 本機能を実装する資材モジュール（`\\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\MaterialModule`）。
- **Dispatches_Index_Page**: 原材料工場入請求画面 `Areas/Material/Pages/Dispatches/Index`（未登録ビュー）。
- **Pdf_Output_Checkbox**: `Dispatches_Index_Page` の「印刷」チェックボックス。`id="chkPdfOutput"`、送信プロパティ名 `PdfOutput`。
- **Dispatch_Print_Default**: ユーザーごとに設定する「原材料工場入請求 印刷 既定」の ON/OFF 値。保持列は `m_user_order_setting.dispatch_print_default`（bit、既定 1=ON）。
- **User_Order_Setting**: 既存の per-user 設定マスタ `m_user_order_setting`（1ユーザー1行、`user_code` 一意）。既存列 `default_output_type` と `row_version`（楽観的ロック用）を持つ。
- **Print_Settings_Page**: 既存の自己サービス設定画面 `Areas/Material/Pages/PrintSettings/Index`。本人が自分の設定を編集・保存する。
- **Fallback_Print_Default**: `Dispatch_Print_Default` が未設定の場合に適用する既定値 ON。

## Requirements

### Requirement 1: Dispatches 印刷チェックボックスの初期状態反映

**User Story:** 原材料工場入請求の担当者として、印刷チェックボックスの初期 ON/OFF を自分の既定設定で表示してほしい。毎回チェックを付け外しする手間を省くため。

#### Acceptance Criteria

1. WHEN ログインユーザーで `Dispatches_Index_Page` の未登録ビューを表示する、THE MaterialModule SHALL 当該ユーザーの `Dispatch_Print_Default` を解決し、その値に従って `Pdf_Output_Checkbox` の初期チェック状態を設定する。
2. WHERE `Dispatch_Print_Default` が ON である、THE MaterialModule SHALL `Pdf_Output_Checkbox` を初期チェック済み（checked）で表示する。
3. WHERE `Dispatch_Print_Default` が OFF である、THE MaterialModule SHALL `Pdf_Output_Checkbox` を初期未チェック（unchecked）で表示する。
4. IF ログインユーザーの `Dispatch_Print_Default` が未設定である、THEN THE MaterialModule SHALL `Fallback_Print_Default`（ON）を適用し、`Pdf_Output_Checkbox` を初期チェック済みで表示する。

### Requirement 2: 設定値の保持（既存マスタへの列追加）

**User Story:** システム担当者として、印刷既定の設定を既存のユーザー設定マスタに相乗りで保持したい。新規テーブルを増やさず、1ユーザー1行で一元管理するため。

#### Acceptance Criteria

1. THE MaterialModule SHALL `Dispatch_Print_Default` を `User_Order_Setting` の列 `dispatch_print_default`（bit、既定値 1=ON）に保持する。
2. THE MaterialModule SHALL `Dispatch_Print_Default` を `User_Order_Setting` の 1 ユーザー 1 行（`user_code` 一意）に相乗りで保持し、印刷既定専用の新規テーブルを作成しない。
3. THE MaterialModule SHALL `User_Order_Setting` の既存列 `default_output_type` の定義・値・保存挙動を変更しない。
4. THE MaterialModule SHALL 多人数同時更新の楽観的ロックに `User_Order_Setting` の既存 `row_version` 列を流用する。

### Requirement 3: 設定 UI（PrintSettings への集約）

**User Story:** 原材料工場入請求の担当者として、印刷既定を自己サービス画面で設定・保存したい。管理者に依頼せず自分で切り替えるため。

#### Acceptance Criteria

1. THE Print_Settings_Page SHALL 既存「発注エントリ 既定出力区分」の近くに「原材料工場入請求 印刷 既定（ON/OFF）」を表すチェックボックスを表示する。
2. WHEN Print_Settings_Page を表示する、THE MaterialModule SHALL ログインユーザーの `Dispatch_Print_Default` を解決し、当該チェックボックスの初期状態に反映する。
3. IF ログインユーザーの `Dispatch_Print_Default` が未設定である、THEN THE MaterialModule SHALL 当該チェックボックスを `Fallback_Print_Default`（ON）で初期表示する。
4. WHEN ユーザーが Print_Settings_Page で印刷既定を保存する、THE MaterialModule SHALL 本人の `User_Order_Setting` 行に `Dispatch_Print_Default` をアップサート（存在時は更新、未存在時は行作成）する。
5. IF 保存時に他ユーザーの先行更新による楽観的ロック競合が発生する、THEN THE MaterialModule SHALL 保存を行わず、既存作法の競合メッセージ「他のユーザーが先に更新しました。画面を再読み込みしてください。」を表示する。

### Requirement 4: 適用範囲の限定（挙動の非改変）

**User Story:** 保守担当者として、本変更が印刷チェックボックスの初期状態だけに限定されることを保証したい。既存の請求・出力挙動へ影響を与えないため。

#### Acceptance Criteria

1. THE Pdf_Output_Checkbox SHALL 要素 id を `chkPdfOutput`、送信プロパティ名を `PdfOutput` のまま維持する。
2. THE MaterialModule SHALL ユーザーが画面上で `Pdf_Output_Checkbox` を切り替えた値の送信・処理を現状のまま維持する。
3. THE Dispatches_Index_Page SHALL 請求時の `PdfOutput` の値による PDF 出力分岐処理を現状のまま維持する。
4. THE Dispatches_Index_Page SHALL 外部出力（PDFエージェント）およびその他の請求関連挙動を現状のまま維持する。

### Requirement 5: スコープと DB 文書整備

**User Story:** 開発者として、本機能を MaterialModule 内で完結させ、DB スキーマ変更を安全かつ文書化された形で適用したい。基盤の不変性と資料の整合を保つため。

#### Acceptance Criteria

1. THE MaterialModule SHALL 本機能の実装（列追加・エンティティ・UI・初期表示ロジック）を MaterialModule 内で完結させ、clnCoCore（MainWeb / AuthModule / SharedCore）を変更しない。
2. THE MaterialModule SHALL `User_Order_Setting` に列 `dispatch_print_default`（bit、既定 1）を追加する冪等な ALTER SQL（列存在チェック付き）を提供する。
3. WHEN `dispatch_print_default` 列が追加される、THE MaterialModule SHALL `.kiro/docs/db/テーブル定義書.md` を当該列定義（列名・日本語名・型・備考）で更新する。
4. WHEN `dispatch_print_default` 列が追加される、THE MaterialModule SHALL `.kiro/docs/db/ER図.md`（存在すれば `ER図.mmd` も）を当該列で更新する。
