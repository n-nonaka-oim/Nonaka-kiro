# 実装計画: マスタメンテナンスページ

## 概要

マスタメンテナンスページ（MasterMaintenance/Index）のPageModel・ビューを実装する。5つのマスタテーブルをタブ切り替えで一覧表示し、品目マスタのみインライン編集・AJAX保存に対応する。

## タスク

- [x] 1. PageModel実装
  - [x] 1.1 タブ別データ取得（OnGetAsync）
    - Tabパラメータに応じたswitch分岐でデータ取得
    - items: IsActive=true, OrderBy ItemCode
    - suppliers: IsActive=true, OrderBy SupplierCode
    - purchase: IsActive=true, OrderBy ItemCode
    - packages: 全件, OrderBy Id
    - warehouses: 全件, OrderBy WarehouseCode
    - _要件: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9_
  - [x] 1.2 品目保存ハンドラ（OnPostSaveItemAsync）
    - [FromBody] ItemSaveRequest でJSON受信
    - FindAsyncで品目検索、未検出時エラーJSON返却
    - 全編集フィールドの反映、LeadTimeDays→DefaultDeliveryDays同値セット
    - LotSizeType null時 "lot_for_lot" デフォルト
    - UpdatedAt = DateTime.UtcNow
    - _要件: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 4.5, 4.6_
  - [x] 1.3 ItemSaveRequest DTO定義
    - Id, SafetyStockQty, StockMinimumQty, DefaultOrderQty, LeadTimeDays, DefaultDeliveryDays, OrderUnitQty, LotSizeType, FixedLotQty
    - _要件: 2.1_
  - [x] 1.4 認可設定
    - [Authorize(Policy = "DbPermissionCheck")] 属性付与
    - _要件: 9.1, 9.2_

- [x] 2. ビュー実装
  - [x] 2.1 タブナビゲーション
    - nav-tabs で5タブ表示、Tab パラメータに応じた active クラス切り替え
    - _要件: 1.1, 1.2, 1.3_
  - [x] 2.2 品目マスタテーブル（インライン編集）
    - 読み取り専用列: 品目コード、品目名
    - 編集列: 安全在庫、発注点、発注単位、デフォルト発注数、納期(日)、ロットタイプ、固定ロット数
    - 各行に保存ボタン、data-id属性でID保持
    - _要件: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [x] 2.3 仕入先マスタテーブル（読み取り専用）
    - 列: 仕入先コード、仕入先名、正式名称、TEL、FAX、住所、GR区分
    - null値は "-" 表示
    - _要件: 5.1, 5.2, 5.3_
  - [x] 2.4 購買条件テーブル（読み取り専用）
    - 列: 品目コード、仕入先コード、搬入先、メーカー、購買区分、有効
    - 購買区分: 1="在庫", 2="預託", other="-"
    - 有効: true="○", false="×"
    - _要件: 6.1, 6.2, 6.3, 6.4, 6.5_
  - [x] 2.5 荷姿マスタテーブル（読み取り専用）
    - 列: ID、荷姿名
    - _要件: 7.1, 7.2_
  - [x] 2.6 倉庫マスタテーブル（読み取り専用）
    - 列: 倉庫コード、倉庫名
    - _要件: 8.1, 8.2_
  - [x] 2.7 JavaScript（AJAX保存処理）
    - .btn-save-item クリックイベント
    - closest('tr') から data-field 属性で値収集
    - RequestVerificationToken ヘッダー付きPOST
    - 成功時: ボタン "✓" → 1.5秒後 "保存" に復帰
    - 失敗時: alert("保存失敗: " + message)
    - _要件: 4.1, 4.2, 4.3, 4.4_

---

## 追加タスク: 品目一覧の表示専用化・品目モーダル集約（2026/05/27 設計更新分）

以下は requirements.md（要件2, 2A, 3, 4, 10, 15）および design.md（品目マスタ一覧の表示専用化・品目モーダル集約）の更新に基づく実装タスク。上記の完了済みタスク（[x]）はそのまま残し、本グループを今回の変更分として追加する。

- [x] 10. 品目マスタ一覧テーブルの表示専用化（Index.cshtml）
  - [x] 10.1 1行目の編集用 `<input>` を読み取り専用テキスト表示に置換
    - 安全在庫(SafetyStockQty)・発注点(StockMinimumQty)・発注個数(OrderUnitQty)・標準発注数量(DefaultOrderQty)・納期(LeadTimeDays) の各セルから `<input data-field=...>` を削除し `@item.xxx` のテキスト表示に置換
    - 発注個数は `@((int)item.OrderUnitQty)`、納期は `@item.LeadTimeDays`（= default_delivery_days と同値）を表示
    - _要件: 2.1, 2.2, 3.3, 15.1_
  - [x] 10.2 2行目の `<select>`・`<input>` を読み取り専用テキスト表示に置換
    - ロットタイプ(LotSizeType) の `<select>` を `@item.LotSizeType` テキスト表示に置換
    - 固定ロット数(FixedLotQty) の `<input>` を `@item.FixedLotQty` テキスト表示に置換
    - 用途1/2/3 は既存の用途名表示（Usage1Name/Usage2Name/Usage3Name、null→"-"）を維持
    - _要件: 2.1, 2.2, 2.3, 15.1_

- [x] 11. 行操作セルの整理（Index.cshtml）
  - [x] 11.1 行内「保存」ボタン（.btn-save-item）を削除
    - 操作セル（rowspan=2）から `<button class="btn ... btn-save-item">保存</button>` を削除
    - 操作セルは「編集」ボタン（btn-outline-secondary、`onclick="MasterMaint.openItemModal(@item.Id)"`）のみとする
    - _要件: 2.4, 2.7, 15.2_
  - [x] 11.2 一覧上部ツールバーの「品目追加」ボタンを確認・整備
    - 「＋ 品目追加」ボタンが `onclick="MasterMaint.openItemModal()"`（引数なし＝新規モーダル起動）で存在することを確認。無ければ追加
    - _要件: 2.6_

- [x] 12. 不要なインライン保存 JavaScript の削除（Index.cshtml）
  - [x] 12.1 `.btn-save-item` の click イベントハンドラ（行内 AJAX 保存・handler=SaveItem 相当）を削除
    - `document.querySelectorAll('.btn-save-item').forEach(...)` のブロックを削除し、参照する補助コードがあれば併せて整理
    - _要件: 4.1, 4.2, 15.2, 15.4_

- [x] 13. 品目モーダルの新規・編集動作の整合確認（Index.cshtml / Index.cshtml.cs）
  - [x] 13.1 品目モーダル（itemModal / saveItemModal / openItemModal）の動作確認・必要に応じ修正
    - `openItemModal()`（新規）でフォームリセット・品目コード編集可、`openItemModal(id)`（編集）で handler=ItemDetail から現在値・RowVersion を初期化することを確認
    - `saveItemModal()` が id 有無で handler=CreateItem / handler=UpdateItem を選択し、RowVersion を送信することを確認。CSRF ヘッダ・Content-Type: application/json を付与
    - CreateItem/UpdateItem/ItemDetail 各ハンドラとの送受信フィールド整合を確認
    - _要件: 2A.1, 2A.2, 2A.3, 2A.4, 2A.5, 3.1, 3.2, 4.1, 4.2, 10.1, 10.2_
  - [x]* 13.2 レガシー OnPostSaveItemAsync / ItemSaveRequest の残置確認（任意・後方互換）
    - handler=SaveItem（OnPostSaveItemAsync）と ItemSaveRequest DTO をコード上残置し、UI から呼び出されないことを確認（コード変更は不要、参照のみ）
    - _要件: 15.4_

- [x] 14. チェックポイント — 一覧表示専用化・モーダル集約の整合確認
  - すべてのテストが通ることを確認し、疑問があればユーザーに確認する。

- [x] 15. 品目モーダル保存ロジックの単体テスト・プロパティテスト（AuthModule.Tests 構成を踏襲する MaterialModule.Tests）
  - [x] 15.1 テストプロジェクト構成の確認・整備
    - AuthModule.Tests と同様の構成で品目モーダルハンドラ（CreateItem/UpdateItem/ItemDetail/DeleteUsage2/DeleteUsage3）のテスト土台を用意（InMemory もしくはテスト用 DbContext）
    - PBT ライブラリ（FsCheck もしくは CsCheck）を参照に追加
    - _要件: 2A.2, 2A.3_
  - [x] 15.2 OnPostCreateItemAsync の単体テスト
    - 正常系（全フィールド登録）、コード/名称未入力・コード重複のバリデーションエラー返却を検証
    - _要件: 2A.2, 2A.7_
  - [x] 15.3 OnPostUpdateItemAsync の単体テスト
    - 正常系（全フィールド更新・UpdatedAt=UtcNow）、品目未検出（success=false, message="品目が見つかりません"）を検証
    - _要件: 2A.3, 2A.6, 2A.7, 4.5, 4.6_
  - [x]* 15.4 Property 1 のプロパティベーステスト（納期同値）
    - **Property 1: 納期(日) の同値保持**
    - 任意の納期(日)入力について、保存後 lead_time_days == default_delivery_days となることを検証（CreateItem / UpdateItem 双方）
    - **Validates: Requirements 3.2**
  - [x]* 15.5 Property 3 のプロパティベーステスト（楽観的ロック）
    - **Property 3: 更新時の楽観的ロック整合性**
    - 任意の RowVersion 一致/不一致について、一致時のみ更新成功・不一致時は更新せず競合メッセージ返却を検証
    - **Validates: Requirements 10.1, 10.3**

- [x] 16. 用途マスタ削除ロジックの単体テスト・プロパティテスト
  - [x] 16.1 OnPostDeleteUsage2Async / OnPostDeleteUsage3Async の単体テスト
    - 未使用カテゴリは削除成功、使用中カテゴリは削除拒否メッセージ返却を検証
    - _要件: 14.7, 14.8_
  - [x]* 16.2 Property 2 のプロパティベーステスト（使用中削除拒否）
    - **Property 2: 用途2/用途3 の使用中削除拒否**
    - 任意の用途カテゴリについて、参照する品目が存在する場合は削除リクエストが拒否され該当カテゴリが残ることを検証
    - **Validates: Requirements 14.7, 14.8**

- [x] 17. 最終チェックポイント — すべてのテストが通ることを確認
  - すべてのテストが通ることを確認し、疑問があればユーザーに確認する。

## メモ

- `*` 付きサブタスクは任意（プロパティテスト等）であり、MVP では省略可能。
- 各タスクはトレーサビリティのため対応する要件を参照する。
- ビルド・テスト実行はユーザー側で行うため、本タスクには実装のみを含み、ビルド実行手順は含めない。
- PBT は C# 標準 PBT ライブラリ（FsCheck / CsCheck）を使用し、各テストに対象プロパティを示すコメント（Feature: master-maintenance, Property N: ...）を付与する。
- 正本（`.kiro/specs/master-maintenance/`）のみ更新。コピー側（`MaterialModule/Doc/specs/`）への反映はオーケストレータが行う。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["11.2", "13.2", "15.1"] },
    { "id": 1, "tasks": ["10.1"] },
    { "id": 2, "tasks": ["10.2"] },
    { "id": 3, "tasks": ["11.1"] },
    { "id": 4, "tasks": ["12.1"] },
    { "id": 5, "tasks": ["13.1", "15.2", "15.3", "16.1"] },
    { "id": 6, "tasks": ["15.4", "15.5", "16.2"] }
  ]
}
```
