# セッション備忘録（2026/05/11）

## 本日の確認事項

### Kiro再インストール後の状態確認
- ソリューションビルド: ✅ 動作OK
- MaterialModule/Doc 全資料確認済み
- Nonaka/Doc 全資料確認済み（初期設計アーカイブ）
- .xkiro/specs/material-module/ のrequirements.md/design.md/tasks.md 確認済み

---

## 残務一覧（優先度順）

### 【高】未実装機能

| # | 項目 | 概要 | 備考 |
|---|---|---|---|
| 1 | StockService エラー修正 | 在庫レコード未存在時の新規作成が正しく動作するか確認 | 05/08で修正済み→動作確認必要 |
| 2 | 表記変更「数量」→「個数」 | 全ページで統一 | 「個数」×「入目」=「合計数量」 |
| 3 | 単位マスタ m_units | KKGは固形重量でbase_value=1、数値の入目値はそのまま使用 | テーブル設計→実装 |
| 4 | 在庫照会画面 | 品目×倉庫×入目の在庫一覧 | 新規ページ |
| 5 | 受払台帳画面 | 日次・月次・年次集計表示 | 新規ページ |

### 【中】未実装機能

| # | 項目 | 概要 | 備考 |
|---|---|---|---|
| 6 | 搬入部門への帳票自動出力 | t_dispatches.status=1を監視→所定プリンタに出力 | Worker Service（別プロジェクト） |
| 7 | 印刷・FAX送信機能 | サイレントプリント・SMTP送信 | 実行環境（オンプレ/クラウド）決定後 |
| 8 | 納期監視画面（DeliveryMonitor） | 動作確認未実施 | 既存実装あり |
| 9 | MRP/Forecasts画面 | 動作確認未実施 | 既存実装あり |

### 【低】将来対応

| # | 項目 | 概要 | 備考 |
|---|---|---|---|
| 10 | m_company_info のdbAuthTestへの移行 | SharedCore経由で全モジュールから取得可能に | 将来 |
| 11 | m_departments のm_sectionへの完全統合 | 発注画面等の他画面も段階的に移行 | 出庫画面は移行済み |
| 12 | BOM展開・生産計画連携 | ProductionPlanProvider / BomExplosionProvider | 将来フェーズ |

---

## 実装済み機能一覧（完了）

| ページ | 機能 | 状態 |
|---|---|---|
| Orders/Create | 発注エントリ・確定（購買条件ベース品目選択） | ✅ |
| Approvals/Index | 承認・差戻し・一括承認・Excel出力 | ✅ |
| Orders/Confirm | 注文確定（FAX返信確認後） | ✅ |
| Orders/Search | 発注データ検索・Excel出力・PDF出力 | ✅ |
| JobQueue/Index | 印刷キュー・PDFダウンロード | ✅ |
| Receivings/Index | 入庫管理・入庫伝票PDF | ✅ |
| Dispatches/Index | 出庫/工場入請求・PDF・SharedCore連携 | ✅ |
| 発注書PDF | QuestPDF A4縦（承認者○印・注記） | ✅ |
| 楽観的ロック | OrderStatusHelper（全ステータス変更） | ✅ |
| 在庫管理 | 移動平均法・入目別・t_stocks/t_stock_ledgers | ✅ |

---

## 現在のDB状態（db_material_dev: 20テーブル）

### マスタ（12テーブル）
m_bom_details, m_bom_headers, m_company_info, m_delivery_locations,
m_forecast_sources, m_items, m_package_types, m_purchase_conditions,
m_report_notes, m_suppliers, m_user_preferences, m_warehouses

### トランザクション（8テーブル）
t_consumption_forecasts, t_dispatches, t_order_forecasts, t_order_reports,
t_orders, t_receivings, t_stock_ledgers, t_stocks

---

## ステータスフロー（確定仕様）

| order_status | 表示名 | タイミング |
|---|---|---|
| 10 | エントリ | 新規入力 |
| 15 | 差戻し | 差戻し |
| 20 | 承認待ち | 発注確定後 |
| 30 | 承認済み | 承認後 |
| 40 | 発注済み | output_type処理後 |
| 50 | 注文確定 | 先方FAX返信確認後（手動） |
| 60 | 入庫済み | 納入→倉庫入れ |

---

## ルール確認（継続）
- MaterialModule配下のみ変更対象
- 作業前・終了前にMaterialModule/Docを確認
- DB設計提案は先に行い、承認を得てから実装
- ビルドはユーザーの指示があった時のみ実行
- t_ordersは結果テーブル（FK制約なし）
- m_purchase_conditionsは読み取り専用
- 出庫はt_ordersと切り離し（在庫ベース）
- 楽観的ロック（OrderStatusHelper）を全ステータス変更に適用
- ユーザー情報はSharedCore（IUserRepository）経由で取得
- 送付先名称はm_suppliers.formal_nameから取得

---

## 開発ロードマップ
- 2026年内: 開発完了
- 2027年: テスト・改修
- 2028年1月: リリース
- MaterialModuleは受払の標準モジュール、他製品にも展開予定

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260511.md`（本ファイル）
- `MaterialModule/Doc/session-memo-20260508.md`（前回）

### 主要サービス
- `MaterialModule/Services/StockService.cs` — 在庫管理（動作確認必要）
- `MaterialModule/Services/OrderService.cs` — 発注管理
- `MaterialModule/Services/ApprovalService.cs` — 承認管理
- `MaterialModule/Services/OrderStatusHelper.cs` — 楽観的ロック

### 主要ページ
- `MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml` + `.cs`
- `MaterialModule/Areas/Material/Pages/Orders/Create.cshtml` + `.cs`
- `MaterialModule/Areas/Material/Pages/Approvals/Index.cshtml` + `.cs`
- `MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml` + `.cs`
