# MaterialModule 開発セッションログ

## 最終更新: 2026-04-16

---

## デバッグ進捗

### ★ 現在: ステップ1 完了 — `/Material/Orders/Create` 動作確認OK

| # | ページ | 状態 |
|---|---|---|
| 1 | `/Material/Orders/Create` | **✅ 完了** |
| 2 | `/Material/Approvals` | 未着手 |
| 3 | `/Material/Receivings` | 未着手 |
| 4 | `/Material/Dispatches` | 未着手 |
| 5 | `/Material/Forecasts` | 未着手 |
| 6 | `/Material/Mrp` | 未着手 |
| 7 | `/Material/DeliveryMonitor` | 未着手 |

### ステップ1で動作確認済みの機能
- ✅ ページ表示
- ✅ 品目サジェスト検索（品目コード/品名、300msデバウンス、上限20件）
- ✅ キーボード操作（↑↓Enter Escape）
- ✅ 品目選択→入目・荷姿・納期日数の自動表示
- ✅ デフォルト数量(default_order_qty)の自動セット
- ✅ 数量×入目の計算表示
- ✅ デフォルト仕入先・倉庫・納期の自動設定
- ✅ 倉庫ドロップダウン（倉庫コード 倉庫名 表記）
- ✅ エントリ追加（一時テーブル t_order_entries）
- ✅ エントリリスト表示（起票日・数量F2統一）
- ✅ エントリ削除
- ✅ 数量変更時のdefault_order_qty更新確認Window（confirm→サーバー側更新）

### 次に確認すべき項目（明日）
1. 発注確定（エントリ→t_orders一括登録）の動作確認
2. ステップ2: `/Material/Approvals`（承認画面）
3. ステップ3以降

---

## 完了した作業

### 4/14: 要件定義・設計・実装
- requirements.md, design.md, tasks.md 作成
- 全17エンティティ + 10 DTO + 9サービス + 7ページ実装
- DI登録、ビルド成功

### 4/15-16: DB・データ移行・デバッグ
- db_material_dev 作成（MaterialModule専用）
- db_factory_dev 作成（工場共有マスタ）
- m_items: 656件（m_hinmokuから移行、package_type_id/warehouse_id/department_id/supplier_id紐付け）
- m_suppliers: 2236件（m_sap_shiiresakiから移行、仕入先得意先一覧.xlsx準拠カラム）
- m_warehouses: 38件（m_sokoから倉庫名・備考・容量移行）
- m_departments: 18件、m_delivery_locations: 85件、m_package_types: 10件
- r_item_departments: 1158件、r_item_warehouses: 659件（中間テーブル）
- m_items.default_order_qty: t_motoから月平均入庫数量算出
- m_items.supplier_id: 533/656件紐付け（m_gen_kobai_jyoken経由）
- 移行SP: usp_migrate_from_dbNsShizai（冪等、MERGE方式）

### 4/16: ページデバッグ・機能追加
- DbContext NullReferenceException修正（MOrderStatus自己参照、MDeliveryLocation nullable）
- appsettings.json接続文字列追加（MaterialDb, FactoryDb）
- FactoryDbContext新規作成（共有マスタ用）
- Create.cshtml: サジェスト検索、一時テーブル方式、搬入場所削除、倉庫表記変更
- fetchのURL: @Url.Page()で動的生成（パスベース/AuthTest対応）
- default_order_qty自動セット＋更新確認Window
- エントリリスト: 起票日追加、数量F2統一
- TOrderEntry: DatabaseGenerated Identity修正

---

## アーキテクチャ

### DB構成
| DB | 用途 | 接続文字列キー |
|---|---|---|
| db_material_dev | MaterialModule専用 | MaterialDb |
| db_factory_dev | 工場共有マスタ | FactoryDb |

### DbContext構成
| Context | DB | テーブル |
|---|---|---|
| MaterialDbContext | db_material_dev | m_items, m_package_types, m_order_statuses, m_forecast_sources, m_bom_*, t_orders, t_receivings, t_dispatches, t_stocks, t_stock_ledgers, t_consumption_forecasts, t_order_forecasts, t_order_entries |
| FactoryDbContext | db_factory_dev | m_warehouses, m_departments, m_suppliers, m_delivery_locations |

### プロジェクト構成
```
MaterialModule/
├── Areas/Material/Pages/ (7画面)
├── Data/ (MaterialDbContext, FactoryDbContext, Entities/)
├── Models/Dtos/ (10 DTO)
├── Services/ (9 interface + 9 implementation + IOrderEntryService)
├── Extensions/MaterialModuleExtensions.cs
└── MaterialModule.csproj
```

---

## 環境情報
- DBサーバー: OJIADM23120073\DEVELOPMENT
- プロジェクト: \\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\MaterialModule
- ソリューション: clnCoCore\slnCoCore.sln
- パスベース: /AuthTest
- fetchのURL: @Url.Page()で動的生成

## 注意事項
- PowerShellスクリプト経由での日本語書き込みは文字化けする → KiroのeditCode/fsWriteを使用
- appsettings.jsonはgit pullで上書きされる → MaterialDb, FactoryDb接続文字列の再追加が必要
