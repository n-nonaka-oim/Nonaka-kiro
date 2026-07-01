# セッション備忘録（2026/05/28）

## 本日の完了作業

### 1. 発注計画ダッシュボード（OrderPlanning）全実装 + デバッグ
- Spec の tasks.md に基づき全10タスク実行完了
- ビルドエラー修正（IndexModel 名前空間衝突、JSパス、AJAX URL）
- 計画入庫を t_orders のみに変更（t_order_forecasts 除外）
- ステータス別セル背景色 + 凡例表示
- テーブルヘッダ統一（計画: 入庫/出庫/在庫 + 実績: 入庫/出庫/在庫）
- 発注エントリ作成後の台帳自動リフレッシュ
- DeliveryDate NULL / 同一日付重複レコードのバグ修正
- 台帳日付 + 発注日付 + 消費予測日付をマージして行生成

### 2. 不要ページ削除
- **OrderRecommendation** ページ削除（OrderPlanning に統合済み）
- **DeliveryMonitor** ページ削除（Orders/Confirm でカバー）
- 両ページの Spec フォルダ削除（.kiro/specs/ + MaterialModule/Doc/specs/）

### 3. purchase_type マスタ化
- `m_purchase_types` テーブル作成（1:在庫, 2:預託）
- `MPurchaseType` エンティティ + DbSet 追加
- ハードコード switch 式を全4箇所マスタ参照に置換
  - OrderService.cs, OrderPlanning/Index.cshtml.cs, StockLedger/Index.cshtml.cs, Mrp/Index.cshtml.cs

### 4. 品目用途列追加
- `m_usage_categories` テーブル作成（填料/薬品/染料/その他）
- `m_items` に `usage_1`(int), `usage_2`(nvarchar), `usage_3`(nvarchar) 追加
- usage_1: 649件を品目コード先頭2桁から自動セット
- usage_2: 521件を旧システム [dbNsShizai].[dbo].[m_gnz_yoto] からコピー
- `t_orders` に `usage_1`, `usage_2`, `usage_3` 追加 + 既存200件バックフィル
- OrderService: 発注作成時に品目マスタから用途を自動コピー

### 5. タンク残量チェックページ — Spec開始
- `.kiro/specs/tank-check/requirements.md` 作成（8要件）
- `MaterialModule/Doc/specs/tank-check/requirements.md` コピー作成

### 6. MaterialModule.Tests をソリューションに追加
- `dotnet sln slnCoCore.sln add MaterialModule.Tests\MaterialModule.Tests.csproj`

---

## 未完了（次回タスク）

### タンク残量チェックページ（最優先）
- requirements.md レビュー完了後 → design.md → tasks.md → 実装

### 発注計画ダッシュボード（残課題）
- 入庫ステータスの色表示が一部反映されない（要調査）
- 計画出庫インライン編集の動作確認
- try-catch デバッグ表示を本番用に戻す
- UX改善（レイアウト微調整）

### 受払台帳（StockLedger）
- 計画データ編集UI — 動作確認・微調整

### マスタメンテナンス
- 用途1〜3の編集UI追加（任意）

### 印刷・帳票
- 印刷対応
- 搬入部門への帳票自動出力（Worker Service）

### 将来機能（生産計画プロジェクト構築時）
- usage別集計・加重平均による所要計算
- 現場発注（B管理品）ページ
- マスタメンテナンスの機能拡充

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260528.md`（本ファイル）
- `.kiro/steering/project-rules.md`（プロジェクトルール — 自動読込）
- `.kiro/specs/tank-check/requirements.md` — 次回作業の起点
- `.kiro/specs/order-planning-dashboard/` — 残課題あり

### 主要変更ファイル（本日）
- `Areas/Material/Pages/OrderPlanning/Index.cshtml.cs` — ハンドラ全体
- `Areas/Material/Pages/OrderPlanning/Index.cshtml` — JSパス修正
- `Areas/Material/Pages/OrderPlanning/_LedgerPartial.cshtml` — ステータス色、ヘッダ変更
- `wwwroot/js/orderPlanning.js` — URL修正、発注後リフレッシュ
- `Data/Entities/MPurchaseType.cs` — 新規
- `Data/Entities/MUsageCategory.cs` — 新規
- `Data/Entities/MItem.cs` — usage_1/2/3 追加
- `Data/Entities/TOrder.cs` — usage_1/2/3 追加
- `Data/MaterialDbContext.cs` — DbSet追加（PurchaseTypes, UsageCategories）
- `Services/OrderService.cs` — マスタ参照化 + 用途コピー
- `Areas/Material/Pages/StockLedger/Index.cshtml.cs` — マスタ参照化
- `Areas/Material/Pages/Mrp/Index.cshtml.cs` — マスタ参照化
- `MaterialModule.Tests/OrderPlanning/` — using修正
- `Doc/sql/create_m_purchase_types.sql` — 新規
- `Doc/sql/add_usage_columns.sql` — 新規

### 削除ファイル（本日）
- `Areas/Material/Pages/OrderRecommendation/` — 全削除
- `Areas/Material/Pages/DeliveryMonitor/` — 全削除
- `.kiro/specs/order-recommendation/` — 全削除
- `.kiro/specs/delivery-monitor-page/` — 全削除
- `MaterialModule/Doc/specs/order-recommendation/` — 全削除
- `MaterialModule/Doc/specs/delivery-monitor-page/` — 全削除
