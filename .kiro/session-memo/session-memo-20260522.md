# セッション備忘録（2026/05/22）

## 本日の完了作業

### 1. 受払台帳画面（stock-ledger-page）レイアウト確定
- 3段表示（数量/個数/ベール数）→ **2段表示（数量+個数）** に簡略化
- ベール数行（ダミー 0.000）を削除
- 個数のフォーマット: N3 → N0（整数表示）、単位は「個」固定
- 繰越列を削除 → 後に復活（年月日の右、計画の左に配置）

### 2. 列構成の変更
- 列順を「**計画（左）→ 実績（右）**」に変更
- 3段ヘッダー構成: 計画/実績 → 入庫/出庫/在庫 → 数量個数/単位
- 計画列の背景色: 薄いクリーム色（#f5f0d0 ヘッダー / #fdfbf0 データ）
- colgroup で列幅を固定（数値70px、単位30px で計画・実績統一）
- 繰越在庫列を追加（年月日 | 繰越 | 計画 | 実績）

### 3. 左側属性エリアの分離
- 左2列（品目情報）をデータテーブルから完全分離
- `d-flex` で横並びレイアウト: 属性エリア（罫線なし）+ データテーブル（罫線あり）
- 属性エリア幅: 220px
- 属性12項目: 品目コード、品目、仕入先、メーカー、濃度、比重、購買、在庫、納期、荷姿、入目、倉庫
- Bootstrap table-bordered の罫線問題を回避するため構造分離で解決

### 4. 表示モードフィルタ追加
- デフォルト: 在庫マイナス品目のみ表示
- ドロップダウンで「全件」に切替可能
- DisplayMode プロパティ（"minus" / "all"）

### 5. マイナスセルの視覚効果
- CSS `.sl-negative` で赤太字表示
- 対象: StockQty, StockCount, PlanStockQty, PlanStockCount がマイナスの場合

### 6. 発注推奨一覧ページ（OrderRecommendation）新規作成
- 在庫 < safety_stock_qty の品目を抽出
- 緊急度判定: High（マイナス在庫）/ Medium（安全在庫以下）/ Low
- 推奨発注数量計算: DefaultOrderQty > fixed lot > lot_for_lot
- ViewModel + PageModel + ビュー

### 7. マスタメンテナンスページ（MasterMaintenance）新規作成
- 5タブ構成: 品目/仕入先/購買条件/荷姿/倉庫
- 品目マスタ: インライン編集 + AJAX保存
- lead_time_days と default_delivery_days を統一（「納期(日)」表記）

### 8. 棚卸CSVからのデータ投入
- m_items.safety_stock_qty: 267件更新（4月末在庫個数）
- t_stock_ledgers: 636件挿入（2026/05/01 初期データ）

### 9. 排他制御・同時接続対応
- MItem エンティティ: `[Timestamp] row_version` プロパティ追加
- DB: `m_items` テーブルに `row_version ROWVERSION NOT NULL` カラム追加
- マスタメンテナンス保存: 楽観的ロック実装（RowVersion チェック + DbUpdateConcurrencyException）
- 計画データ保存（StockLedger AJAX）: トランザクション追加（BeginTransactionAsync）

### 10. Spec整備
- master-maintenance, order-recommendation, stock-ledger-page の3つをSpec化
- .kiro/specs/ + MaterialModule/Doc/specs/ の2箇所に配置
- .xkiro/ ディレクトリを削除（.kiro/ に統一）
- ステアリングファイル作成（.kiro/steering/project-rules.md）
- 排他制御ルールをステアリングに追記

### 11. ドキュメント整備
- Doc/発注点計算方法.md — 発注点計算式、ロットタイプ説明、出庫データ構成
- MaterialModule/Doc/specs/README.md — 更新ルール追記
- Doc/specs/ 重複フォルダ整理

### 12. トレンドベース消費予測（Phase 2）
- TrendBasedForecastProvider 新規作成（過去90日の出庫実績から日平均消費量算出）
- CompositeForecastProvider 新規作成（手動入力 + トレンド予測を合算）
- DI登録変更: ManualForecastProvider → CompositeForecastProvider
- m_forecast_sources に id=4 "trend" を追加
- t_consumption_forecasts に1488件のトレンド予測を生成済み

### 13. トリガーベースMRP計算
- MrpCalculationQueue（デバウンス付きキュー）新規作成
- MrpBackgroundService（バックグラウンドワーカー）新規作成
- 発注確定（Orders/Confirm）にMRPトリガー追加
- 工場入れ請求（Dispatches/Index）にMRPトリガー追加

### 14. MRPページ リファクタリング（完了）
- 発注リスト形式に変更（t_order_forecasts 未変換レコード表示）
- 列レイアウトを Orders/Create に踏襲: □, 緊急度, GR, 在庫区分, 品目コード, 品目名, 個数(編集可), 入目, 合計, 発注日(編集可), 納期(編集可), 送付先, 倉庫名, 出力区分, 操作
- アラートセクション復活（即発注・要発注のみ上部表示）
- 緊急度判定: 発注日≤今日=即発注(赤), ≤3日後=要発注(黄), 通常(灰)
- チェックボックス選択 + 選択発注
- インライン編集（個数、発注日、納期）+ 💾保存ボタン
- サーバーサイドページャー（20件/ページ、Orders/Createと同じ形式）
- 再計算ボタン（バックグラウンドキュー投入 + 3秒後自動リロード）
- t_order_forecasts.lot_size_type カラムを10→20文字に拡張
- MRP計算結果を9件生成（安全在庫割れ品目）
- ビルド確認OK

---

## 未完了（次回タスク）

### MRPページ リファクタリング（最優先）
- ~~アラートセクション復活（即発注、要発注の緊急度表示）~~ ✅
- ~~列レイアウトを Orders/Create のエントリリストに踏襲~~ ✅
- ~~発注数量は「個数」ベース~~ ✅
- ~~レコード単位で編集可能~~ ✅
- ~~選択分を発注 + レコード単位の発注ボタン~~ ✅
- ~~ページャーは Orders/Create と同じサーバーサイド形式~~ ✅
- ~~再計算ボタン設置~~ ✅
- **パフォーマンス改善が必要**（次回最優先）

### MRPページ パフォーマンス改善（最優先）
- ~~ページ表示が重い（アラート取得 + 発注リスト取得の負荷）~~ ✅
- 改善実施:
  - AlertService: N+1クエリ（~1300回）→ 3回の一括クエリに書き直し
  - AlertService: 在庫データソースを `t_stocks` → `t_stock_ledgers` に統一
  - AlertService: 判定基準を `stock_minimum_qty` → `safety_stock_qty` に統一
  - AlertService: Green（正常）を除外して返却（対象品目数を大幅削減）
  - LoadOrderListAsync: `Include` → `Select` で必要列のみ取得
  - 仕入先取得: エンティティ全体 → GrTypeのみ取得
- データ修正:
  - `default_order_qty` を全品目NULLにリセット（不正データ: 年間使用量が入っていた）
  - 発注数量は「安全在庫 - 現在在庫 = 不足分」で計算する方式に統一
  - MRP計算結果を再生成（9件、正しい数量）
- 残課題:
  - まだ表示が重い場合はインデックス追加を検討
  - `default_order_qty` は今後マスタメンテ画面で正しい値を手動設定

### 受払台帳画面
- 計画データの編集UI（AJAXハンドラ実装済み、UIからの呼び出し未実装）
- 印刷対応

### 発注推奨一覧
- 動作確認済み（問題なし）
- 将来: 発注ボタン（推奨一覧から直接発注画面へ遷移）

### マスタメンテナンス
- 動作確認済み（問題なし）
- 将来: 仕入先・購買条件タブの編集機能追加

### ナビメニュー バッジ表示（検討中）
- メニュー項目の横にリスト件数バッジを表示
- 内容更新時にフォントをBoldに変更
- 実装: MaterialModule側にAPI追加 + MainWeb側のナビにJS定期ポーリング
- MainWebの `_NavMenuPartial.cshtml` に手を入れる必要あり

### 残機能
1. 搬入部門への帳票自動出力（Worker Service）
2. 印刷・FAX送信（環境決定後）
3. OrderStatusText のハードコードをマスタから動的取得に変更
4. m_units（荷姿マスタ）— 後回し
5. 在庫照会画面 — 後回し

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260522.md`（本ファイル）
- `.kiro/steering/project-rules.md`（プロジェクトルール — 自動読込）

### Spec
- `.kiro/specs/stock-ledger-page/` — 受払台帳
- `.kiro/specs/master-maintenance/` — マスタメンテナンス
- `.kiro/specs/order-recommendation/` — 発注推奨一覧

### 主要変更ファイル（本日）
- `Areas/Material/Pages/StockLedger/Index.cshtml` — ビュー全面書き直し（繰越列、マイナス視覚効果）
- `Areas/Material/Pages/StockLedger/Index.cshtml.cs` — DisplayMode追加、トランザクション追加
- `Areas/Material/Pages/MasterMaintenance/Index.cshtml` — 新規（RowVersion対応）
- `Areas/Material/Pages/MasterMaintenance/Index.cshtml.cs` — 新規（楽観的ロック）
- `Areas/Material/Pages/OrderRecommendation/Index.cshtml` — 新規
- `Areas/Material/Pages/OrderRecommendation/Index.cshtml.cs` — 新規
- `Models/ViewModels/OrderRecommendationViewModel.cs` — 新規
- `Data/Entities/MItem.cs` — RowVersion追加
- `Doc/発注点計算方法.md` — 新規
- `.kiro/steering/project-rules.md` — 新規（排他制御ルール含む）
