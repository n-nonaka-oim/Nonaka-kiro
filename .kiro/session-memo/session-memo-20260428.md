# セッション備忘録（2026/04/28）

## 本日の進捗

### 1. ステータスフロー拡張（完了）
| order_status | 表示名 | タイミング |
|---|---|---|
| 10 | エントリ | 新規入力 |
| 15 | 差戻し | 差戻し |
| 20 | 承認待ち | 発注確定後 |
| 30 | 承認済み | 承認後 |
| 40 | 発注済み | output_type処理後 |
| 50 | 注文確定 | 先方FAX返信確認後（手動） |
| 60 | 入庫済み | 納入→倉庫入れ |
| 70 | 出庫済み | 廃止（出庫はt_ordersと切り離し） |

### 2. 注文確定画面 Orders/Confirm（完了）
- 確定前(40)/確定済(50)ドロップダウン切り替え
- 検索機能（発注番号、品目コード、品目名、納期From-To、送付先）
- 個別確定/一括確定/未確定ボタン
- ソート機能
- 数量・入目・合計数量・単価・合計金額列追加
- 楽観的ロック（OrderStatusHelper）適用

### 3. 入庫管理 Receivings 改修（完了）
- 入庫前(50)/入庫済(60)ドロップダウン切り替え
- 日付範囲（From-To）+ 倉庫フィルタ
- 個別入庫/一括入庫/未入庫ボタン
- 入庫伝票PDF（日付+倉庫で改ページ、印枠付き）
- 楽観的ロック適用
- ソート・ページング・フィルタ条件保持

### 4. DB競合対策（完了）
- OrderStatusHelper共通ヘルパー作成
- トランザクション + 存在チェック + ステータスチェック + RowVersionチェック
- 適用箇所: 承認、差戻し、発注確定、注文確定、未確定、入庫、未入庫

### 5. t_orders.amount列追加（完了）
- amount = total_qty × unit_price（生の金額、円単位）
- 画面表示はAmountInThousands（千円単位）
- Excel出力は生の金額

### 6. 表記変更
- 発注一覧「数量」→「合計数量」
- エントリリストに「数量」「入目」「合計」3列表示
- 確定前一覧に「数量」「入目」「合計数量」「単価」「合計金額」追加
- 発注書PDFに入目・合計列追加

### 7. UI改善
- 全ページの日付From-To連動（From変更時にTo自動調整）
- Orders/Create: ページ表示時に品目入力欄に自動フォーカス
- PrintQueue → JobQueue リネーム

### 8. Orders/Search ステータスリスト全ステータス対応

---

## 次回の作業予定

### 1. 出庫画面改修
- Dispatches画面をReceivingsと同様のスタイルに改修
- 在庫連携（StockService.DecrementStockAsync）
- 入目指定での出庫

### 2. 表記変更
- 「数量」→「個数」（全ページ）
- 「個数」×「入目」=「合計数量」

### 3. 単位マスタ m_units
- KKGは固形重量でbase_value=1
- 数値の入目値はそのまま使用

### 4. 在庫照会画面
- 品目×倉庫×入目の在庫一覧

### 5. 受払台帳画面
- 日次・月次・年次集計表示

---

## DB変更履歴（2026/04/28）

| テーブル | 変更内容 |
|---|---|
| t_orders | amount列追加、既存データ128件計算済み |
| t_stocks | DROP＋再設計（原価計算対応、入目別管理、357件初期データ移行） |
| t_stock_ledgers | DROP＋再設計（受払台帳、日次記録） |

---

## ルール確認（継続）
- MaterialModule配下のみ変更対象
- 作業前・終了前にMaterialModule/Docを確認
- DB設計提案は先に行い、承認を得てから実装
- ビルドはユーザーの指示があった時のみ実行
- t_ordersは結果テーブル（FK制約なし）
- 出庫はt_ordersと切り離し（在庫ベース）
- 楽観的ロック（OrderStatusHelper）を全ステータス変更に適用

---

## 参照ファイル一覧

### 新規・変更ファイル
- `Services/OrderStatusHelper.cs` — 楽観的ロック共通ヘルパー
- `Areas/Material/Pages/Orders/Confirm.cshtml` + `.cs` — 注文確定画面
- `Areas/Material/Pages/Receivings/Index.cshtml` + `.cs` — 入庫管理（大幅改修）
- `Areas/Material/Pages/JobQueue/Index.cshtml` + `.cs` — リネーム
- `Areas/Material/Pages/Orders/Search.cshtml` + `.cs` — ステータス全対応
- `Services/OrderPdfService.cs` — 入目・合計列追加、amount対応
- `Models/Dtos/OrderListDto.cs` — UnitContentQty, TotalQty, Amount追加
- `Data/Entities/TOrder.cs` — Amount, RowVersion追加


---

## 在庫管理設計（本日確定）

### t_stocks（リアルタイム在庫）
- キー: item_id + warehouse_code + unit_content_qty
- 入庫累計: received_count, received_qty, received_unit_price, received_amount
- 出庫累計: dispatched_count, dispatched_qty, dispatched_unit_price, dispatched_amount
- 在庫: stock_count, stock_qty, stock_unit_price（移動平均）, stock_amount
- 初期データ: dbNsShizai.t_tanaから357件移行済み

### t_stock_ledgers（受払台帳）
- キー: item_id + warehouse_code + unit_content_qty + record_date
- 繰越: carried_count, carried_qty, carried_amount
- 入庫/出庫/在庫: 同上
- 集計: 日次レコード → 月次/年次/通期はSUMで算出

### 在庫評価: 移動平均法
- 入庫時: 在庫金額 = 旧在庫金額 + 入庫金額, 在庫単価 = 在庫金額 / 在庫数量
- 出庫時: 出庫単価 = 在庫単価, 在庫金額 -= 出庫金額

### StockService 書き直し済み
- IncrementStockAsync: 入庫（移動平均単価更新＋台帳記録）
- DecrementStockAsync: 出庫（在庫不足チェック＋台帳記録）
- 入庫時の在庫連携: Receivings画面に実装済み

### 追加ファイル
- `Services/StockService.cs` — 全面書き直し
- `Services/IStockService.cs` — 全面書き直し
- `Data/Entities/TStock.cs` — 全面書き直し
- `Data/Entities/TStockLedger.cs` — 全面書き直し
- `Services/OrderStatusHelper.cs` — 楽観的ロック共通ヘルパー

### 開発ロードマップ
- 2026年内: 開発完了
- 2027年: テスト・改修
- 2028年1月: リリース
- MaterialModuleは受払の標準モジュール、他製品にも展開予定
