# セッション備忘録（2026/04/23）

## 本日の進捗

### 1. 倉庫マスタ（m_warehouses）再設計・実装
- m_warehousesをDROP＋再作成（[dbNsASP].[dbo].[m_soko]を継承）
- 使用カラム: warehouse_code, conv_code, warehouse_name
- 将来: capacityカラムで満床率計算
- t_orders, t_order_entries: warehouse_code + warehouse_name を保持（結果テーブルのためリレーションなし）

### 2. warehouse_id → warehouse_code 移行（途中）
- **完了済み:**
  - TReceiving.cs → warehouse_code(nvarchar) + warehouse_name(nvarchar)
  - TDispatch.cs → warehouse_code(nvarchar) + warehouse_name(nvarchar)
  - TOrder.cs → warehouse_code(nvarchar) + warehouse_name(nvarchar)（既に対応済み）
  - TOrderEntry.cs → warehouse_code(nvarchar) + warehouse_name(nvarchar)（既に対応済み）
  - ReceivingService.cs → warehouse_code対応済み（TODO: StockService連携は保留）
  - DispatchService.cs → warehouse_code対応済み（TODO: StockService連携は保留）
  - IDispatchService.cs → SearchDispatchesAsync パラメータ warehouseCode(string)
  - DispatchCreateDto.cs → WarehouseCode(string)
  - ReceivingCreateDto.cs → WarehouseCode(string)

- **未対応（明日実施）:**
  - TStock.cs → warehouse_id(int) + FK → warehouse_code(string)に変更必要
  - IStockService.cs → パラメータ int warehouseId → string warehouseCode
  - StockService.cs → 全メソッド warehouse_id → warehouse_code
  - MaterialDbContext.cs → uq_t_stocks_01 ユニーク制約（ItemId, WarehouseId → WarehouseCode）
  - Dispatches/Index.cshtml.cs → SearchWarehouseId(int?) → SearchWarehouseCode(string?)、OnGetStockAsync パラメータ変更
  - Dispatches/Index.cshtml → DispatchInput.WarehouseId参照、倉庫ドロップダウンのvalue変更
  - t_stocks DBテーブル → ALTER warehouse_id → warehouse_code

### 3. 承認フロー設計（未着手）
- 承認後: output_typeに基づいて処理（0:DBエントリのみ, 1:印刷, 2:FAX, 3:印刷+FAX）
- 処理完了フラグ（is_processed）を設けて管理
- 差戻し: エントリ状態に戻す（t_ordersからt_order_entriesへ戻す）

---

## 明日の作業予定

### 1. warehouse_code移行の完了
- t_stocks: warehouse_id(int) → warehouse_code(nvarchar) + warehouse_name(nvarchar)
- TStock.cs エンティティ更新（FK削除、warehouse_code/warehouse_nameに変更）
- IStockService.cs / StockService.cs: int warehouseId → string warehouseCode
- MaterialDbContext.cs: ユニーク制約更新
- Dispatches/Index.cshtml.cs + Index.cshtml: warehouse_code対応
- DB ALTER TABLE t_stocks

### 2. m_items側もwarehouse_codeに変更（新規）
- m_items.warehouse_id(int FK) → warehouse_code(nvarchar)に変更
- MItem.cs エンティティ更新（Navigation property Warehouse削除 or 変更）
- ItemSelectDto.cs: WarehouseId(int?) → WarehouseCode(string?)
- MasterService.cs: GetActiveItemsAsync / GetItemDetailAsync / SearchItemsAsync 更新
- DB ALTER TABLE m_items

### 3. t_order_entry を t_order へ統合検討（新規・重要）
- 現在: t_order_entries（エントリ一時テーブル）→ 承認後 → t_orders（発注テーブル）
- 検討: t_ordersに統合し、処理ステータスで管理
  - エントリ状態 → 承認待ち → 承認済み → 発注済み → 受入完了 等
  - t_order_entriesテーブルを廃止し、t_ordersのステータスで全フロー管理
- メリット: テーブル間のデータ移動が不要、履歴追跡が容易
- 影響範囲: OrderEntryService, OrderService, ApprovalService, Create.cshtml, Approvals/Index.cshtml

### 4. t_orderに倉庫情報を保持
- warehouse_code, conv_code, warehouse_name をt_ordersに保持
- conv_codeの追加が必要（現在はwarehouse_code + warehouse_nameのみ）

### 5. 承認フロー実装
- output_typeに基づく処理（承認後）
- is_processedフラグ追加
- 差戻しフロー（エントリ状態に戻す）

---

## 現在のDB状態（2026/04/23時点）

### warehouse_code対応状況

| テーブル | カラム | 状態 |
|---|---|---|
| m_warehouses | warehouse_code, conv_code, warehouse_name | ✅ 完了（m_soko継承） |
| t_orders | warehouse_code, warehouse_name | ✅ 完了 |
| t_order_entries | warehouse_code, warehouse_name | ✅ 完了 |
| t_receivings | warehouse_code, warehouse_name | ✅ 完了 |
| t_dispatches | warehouse_code, warehouse_name | ✅ 完了 |
| t_stocks | warehouse_id(int) | ❌ 未対応 → warehouse_code に変更予定 |
| m_items | warehouse_id(int) | ❌ 未対応 → warehouse_code に変更予定 |

---

## ルール確認（継続）
- MaterialModule配下のみ変更対象（MainWeb等は変更しない）
- 作業前に要件・設計・これまでの修正内容を確認してから着手
- DB設計提案は先に行い、承認を得てから実装
- コードは複雑化しないように進める
- PowerShellでの部分置換は古いコードが残る問題あり → 全体書き直しが確実
- 発注エントリ関連の変更時は必ずバリデーションを追加する
- t_order_entry、t_ordersは結果テーブルなので他マスタとリレーションしない
- 購買条件がない品目は発注できない（ありえない）
- 1品目に複数購買条件がある場合は適用開始日が最新のものを採用し単一とする

---

## DB接続情報
- Server: OJIADM23120073\DEVELOPMENT
- Auth: SA / k13818
- DB: db_material_dev (dev), db_material_prod (prod)
- 参照DB: dbNsShizai（レガシー資材DB）, dbNsASP（レガシーASP DB）

---

## 参照ファイル一覧（明日の作業開始時に読むべきファイル）

### セッション備忘録
- `.kiro/specs/material-module/session-memo-20260421.md`
- `.kiro/specs/material-module/session-memo-20260422.md`
- `.kiro/specs/material-module/session-memo-20260423.md`（本ファイル）

### 設計ドキュメント
- `.kiro/specs/material-module/purchase-condition-design.md`
- `.kiro/specs/material-module/db-migration-mapping.md`

### エンティティ（warehouse_code関連）
- `MaterialModule/Data/Entities/TStock.cs` ← 要変更
- `MaterialModule/Data/Entities/MItem.cs` ← 要変更
- `MaterialModule/Data/Entities/TOrder.cs`
- `MaterialModule/Data/Entities/TOrderEntry.cs`
- `MaterialModule/Data/Entities/TReceiving.cs`
- `MaterialModule/Data/Entities/TDispatch.cs`
- `MaterialModule/Data/Entities/MWarehouse.cs`

### サービス（warehouse_code関連）
- `MaterialModule/Services/StockService.cs` ← 要変更
- `MaterialModule/Services/IStockService.cs` ← 要変更
- `MaterialModule/Services/MasterService.cs` ← 要変更（m_items warehouse_code対応）
- `MaterialModule/Services/ReceivingService.cs`
- `MaterialModule/Services/DispatchService.cs`
- `MaterialModule/Services/OrderService.cs`
- `MaterialModule/Services/OrderEntryService.cs`
- `MaterialModule/Services/ApprovalService.cs`

### DTO
- `MaterialModule/Models/Dtos/ItemSelectDto.cs` ← 要変更
- `MaterialModule/Models/Dtos/DispatchCreateDto.cs`
- `MaterialModule/Models/Dtos/ReceivingCreateDto.cs`

### ページ
- `MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml.cs` ← 要変更
- `MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml` ← 要変更

### DbContext
- `MaterialModule/Data/MaterialDbContext.cs` ← 要変更（ユニーク制約）
