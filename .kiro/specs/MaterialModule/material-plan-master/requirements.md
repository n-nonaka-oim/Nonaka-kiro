# Requirements Document

## Introduction

本 spec は、予実管理（大テーマ）の **Phase 1** のみを対象とする最小スコープ機能である。原材料の**月次計画**を品目別に入力・保存し、四半期・半期・年度は月次を集計して表示専用で示す「計画の器＋入力画面」を提供する。

本 Phase は**プロトタイプ先行・最小単位・既存資産への非影響（新規追加のみ）**を方針とする。MaterialModule 内で完結させ、clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）は不変とする。DB は `db_material_dev` に新規テーブルを追加するのみで、既存テーブルは不変とする。

### 対象外（後続 Phase の別 spec）

以下は本 Phase の**対象外**であり、後続 Phase の別 spec で扱う。

- 実績連携（実績データの取り込み・突合）
- 実績3ヶ月平均の自動初期投入、当月実績単価の自動投入
- 見込み（forecast）版の運用
- 予実分析（計画対実績の差異分析・レポート）
- 原材料単価マスタ `m_purchase_conditions` を用いた単価自動設定（本 Phase では読み取り参照のみ可、未使用でも可）

## Glossary

- **Plan_Master_System**: 本 Phase で追加する原材料月次計画の入力・保存・集計表示を担うシステム（MaterialModule 配下）。
- **Plan_Table**: 新規追加するトランザクションテーブル `t_material_plans`（`db_material_dev`）。品目別・月次の計画数量／計画単価／計画金額を保持する。一意制約は `fiscal_year + year_month + item_id + plan_version`。
- **Plan_Version**: 計画の版を表す文字列カラム `plan_version`（`nvarchar(40)`）。本 Phase では `annual`（年計画）および `revised_h2`（下期修正）を用いる。将来 `forecast` 等の版を追加可能な自由文字列とする。
- **Fiscal_Period_Helper**: `year_month`（例: 202604）から**4月始まりの会計年度**に基づき `fiscal_year`・四半期（quarter）・半期（half）を算出する純粋関数ヘルパ。マスタ化は将来対応とする。
- **Plan_Grid_Page**: 新規追加する計画入力画面（`Areas/Material/Pages` 配下）。対象（`fiscal_year` ＋ `Plan_Version`）を選び、品目×12ヶ月（4月〜翌3月）のグリッドで数量・単価を入力し、金額と各集計を表示・保存する。
- **会計年度定義（Fiscal_Year_Definition）**: 会計年度は**4月〜翌3月**とする。上期＝4月〜9月、下期＝10月〜翌3月。四半期は Q1＝4〜6月、Q2＝7〜9月、Q3＝10〜12月、Q4＝翌1〜3月。
- **計画数量（planned_qty）**: 品目・月・版ごとの計画数量（`decimal`）。本 Phase では手入力。
- **計画単価（planned_unit_price）**: 品目・月・版ごとの計画単価（`decimal`）。本 Phase では手入力。
- **計画金額（planned_amount）**: `planned_qty × planned_unit_price` のスナップショット値（`decimal`）。保存対象。
- **Row_Version**: 楽観的ロック用のカラム `row_version`（`[Timestamp]`）。競合検出に用いる。
- **アップサート（Upsert）**: 一意キー（`fiscal_year + year_month + item_id + plan_version`）が一致する行があれば更新、なければ挿入する保存動作。
- **DbPermissionCheck**: 画面アクセスに要求される認可ポリシー（`[Authorize(Policy = "DbPermissionCheck")]`）。

### データ設計（前提）

新規テーブル `t_material_plans`（`db_material_dev`）の列構成を以下に定める（本 Phase の前提）。

| 列名 | 型 | 説明 |
| --- | --- | --- |
| id | int (PK, IDENTITY) | 主キー |
| fiscal_year | int | 会計年度（4月始まり） |
| year_month | int（例: 202604）または char(6) | 対象年月 |
| item_id | int (FK → m_items) | 品目ID |
| plan_version | nvarchar(40) | 版（`annual` / `revised_h2` 等） |
| planned_qty | decimal | 計画数量 |
| planned_unit_price | decimal | 計画単価 |
| planned_amount | decimal | 計画金額（数量×単価のスナップショット） |
| created_at | datetime | 作成日時 |
| updated_at | datetime | 更新日時 |
| row_version | timestamp（[Timestamp]） | 楽観ロック用 |

一意制約：`fiscal_year + year_month + item_id + plan_version`。

## Requirements

### 要件 1: 会計期間の算出

**ユーザーストーリー:** 計画担当者として、対象年月から会計年度・四半期・半期を一貫した規則で算出したい。これにより、月次入力値を正しい会計期間へ集計できる。

#### 受け入れ基準（Acceptance Criteria）

1. WHEN 対象年月（year_month）が 4月〜12月 の範囲で与えられる, THE Fiscal_Period_Helper SHALL その年月の暦年を fiscal_year として算出する。
2. WHEN 対象年月（year_month）が 1月〜3月 の範囲で与えられる, THE Fiscal_Period_Helper SHALL 暦年から1を減じた値を fiscal_year として算出する。
3. WHEN 対象年月の月が 4〜6月 のいずれかである, THE Fiscal_Period_Helper SHALL 四半期を Q1 として算出する。
4. WHEN 対象年月の月が 7〜9月 のいずれかである, THE Fiscal_Period_Helper SHALL 四半期を Q2 として算出する。
5. WHEN 対象年月の月が 10〜12月 のいずれかである, THE Fiscal_Period_Helper SHALL 四半期を Q3 として算出する。
6. WHEN 対象年月の月が 1〜3月 のいずれかである, THE Fiscal_Period_Helper SHALL 四半期を Q4 として算出する。
7. WHEN 対象年月の月が 4〜9月 のいずれかである, THE Fiscal_Period_Helper SHALL 半期を上期として算出する。
8. WHEN 対象年月の月が 10月〜翌3月 のいずれかである, THE Fiscal_Period_Helper SHALL 半期を下期として算出する。
9. IF 対象年月の月が 1〜12 の範囲外である, THEN THE Fiscal_Period_Helper SHALL 入力値が不正である旨のエラーを返す。

### 要件 2: 月次計画の入力

**ユーザーストーリー:** 計画担当者として、対象の会計年度と版を選び、品目×12ヶ月のグリッドで計画数量と計画単価を入力したい。これにより、品目別の月次計画を作成できる。

#### 受け入れ基準（Acceptance Criteria）

1. WHEN 利用者が対象の fiscal_year と Plan_Version を選択する, THE Plan_Grid_Page SHALL 当該対象の品目×12ヶ月（4月〜翌3月）の入力グリッドを表示する。
2. WHEN 利用者が計画数量（planned_qty）を入力する, THE Plan_Grid_Page SHALL 入力された数量を当該品目・当該月・当該版のセルに保持する。
3. WHEN 利用者が計画単価（planned_unit_price）を入力する, THE Plan_Grid_Page SHALL 入力された単価を当該品目・当該月・当該版のセルに保持する。
4. WHEN 計画数量または計画単価が変更される, THE Plan_Grid_Page SHALL 当該セルの計画金額を planned_qty × planned_unit_price として算出し表示する。
5. WHERE 既存の計画データが対象（fiscal_year ＋ Plan_Version）に存在する, THE Plan_Grid_Page SHALL 保存済みの計画数量・計画単価・計画金額をグリッドへ読み込んで表示する。
6. IF 計画数量または計画単価に数値以外の値が入力される, THEN THE Plan_Grid_Page SHALL 当該入力を受理せず入力値が不正である旨を表示する。

### 要件 3: 集計表示（表示専用）

**ユーザーストーリー:** 計画担当者として、月次入力から四半期・半期・年度の合計を自動で確認したい。これにより、集計値を別途保持・入力せずに計画全体を把握できる。

#### 受け入れ基準（Acceptance Criteria）

1. WHEN グリッドの月次値が表示または更新される, THE Plan_Grid_Page SHALL 品目ごとに四半期合計（Q1〜Q4）を対象月次値の合計として算出し表示専用で表示する。
2. WHEN グリッドの月次値が表示または更新される, THE Plan_Grid_Page SHALL 品目ごとに半期合計（上期・下期）を対象月次値の合計として算出し表示専用で表示する。
3. WHEN グリッドの月次値が表示または更新される, THE Plan_Grid_Page SHALL 品目ごとに年度合計を12ヶ月の月次値の合計として算出し表示専用で表示する。
4. THE Plan_Master_System SHALL 四半期・半期・年度の集計値を Plan_Table に保存しない。
5. THE Plan_Master_System SHALL 月次値のみを保存し、集計値は月次値の合計として都度算出する。

### 要件 4: 計画の保存（アップサート）

**ユーザーストーリー:** 計画担当者として、入力した月次計画を保存したい。これにより、次回以降も同じ計画を編集・参照できる。

#### 受け入れ基準（Acceptance Criteria）

1. WHEN 利用者が保存を実行する, THE Plan_Master_System SHALL 各品目・各月・当該版の計画数量・計画単価・計画金額を Plan_Table に保存する。
2. WHEN 保存対象の一意キー（fiscal_year ＋ year_month ＋ item_id ＋ plan_version）に一致する行が存在する, THE Plan_Master_System SHALL 当該行を更新する。
3. WHEN 保存対象の一意キーに一致する行が存在しない, THE Plan_Master_System SHALL 新規行を挿入する。
4. WHEN 計画を保存する, THE Plan_Master_System SHALL planned_amount に planned_qty × planned_unit_price の値を保存する。
5. WHEN 新規行を挿入する, THE Plan_Master_System SHALL created_at と updated_at に保存時刻を設定する。
6. WHEN 既存行を更新する, THE Plan_Master_System SHALL updated_at に保存時刻を設定する。

### 要件 5: 排他制御（楽観的ロック）

**ユーザーストーリー:** 計画担当者として、複数人が同時に編集しても他者の更新を意図せず上書きしないようにしたい。これにより、更新の取りこぼしを防げる。

#### 受け入れ基準（Acceptance Criteria）

1. WHEN 計画データをグリッドへ読み込む, THE Plan_Master_System SHALL 各行の row_version をクライアントへ返却する。
2. WHEN 利用者が保存を実行する, THE Plan_Grid_Page SHALL 読み込み時に受領した row_version を保存要求に含めて送信する。
3. IF 保存時に送信された row_version が Plan_Table の現在値と一致しない, THEN THE Plan_Master_System SHALL 当該保存を中止し「他のユーザーが先に更新しました。画面を再読み込みしてください。」というメッセージを返す。
4. WHEN 保存が成功する, THE Plan_Master_System SHALL 更新後の row_version をクライアントへ返却する。

### 要件 6: 認可とスコープ制約

**ユーザーストーリー:** システム管理者として、権限を持つ利用者のみが計画入力画面を利用でき、かつ既存資産へ影響しないようにしたい。これにより、安全に新機能を追加できる。

#### 受け入れ基準（Acceptance Criteria）

1. WHERE 利用者が DbPermissionCheck ポリシーを満たす, THE Plan_Grid_Page SHALL 計画入力画面へのアクセスを許可する。
2. IF 利用者が DbPermissionCheck ポリシーを満たさない, THEN THE Plan_Grid_Page SHALL 計画入力画面へのアクセスを拒否する。
3. THE Plan_Master_System SHALL 新規テーブル `t_material_plans` を `db_material_dev` へ追加し、既存テーブルを変更しない。
4. THE Plan_Master_System SHALL 機能の実装・設定・リソースを MaterialModule 内で完結させ、clnCoCore（MainWeb / AuthModule / SharedCore / SharedInfrastructure 等）を変更しない。
5. WHERE 原材料単価マスタ `m_purchase_conditions` を参照する, THE Plan_Master_System SHALL 当該マスタを読み取りのみで参照する。

### 要件 7: 画面デザイン準拠

**ユーザーストーリー:** 利用者として、他の資材画面と統一された見た目で計画入力画面を使いたい。これにより、一貫した操作感を得られる。

#### 受け入れ基準（Acceptance Criteria）

1. THE Plan_Grid_Page SHALL ページ先頭に `_MaterialStyles` パーシャルを含める。
2. THE Plan_Grid_Page SHALL コンテナに `material-page` クラスと 0.8rem のフォントサイズを適用する。
3. THE Plan_Grid_Page SHALL 計画入力グリッド（テーブル）に 0.75rem のフォントサイズを適用する。
