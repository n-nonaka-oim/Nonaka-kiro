# セッション備忘録（2026/05/21）

## 本日の完了作業

### 1. Dispatches section フィルタ動作確認 → OK
- 同一 section 内の別ユーザーのエントリが見える
- 異なる section のエントリは見えない
- 削除・登録操作も section 単位で動作確認済み
- `dispatches-section-filter` spec 完了

### 2. 受払台帳画面（stock-ledger-page）spec 作成
- Requirements（10要件）作成完了
- Design（設計書）作成完了
- Tasks（実装計画、9タスク）作成完了
- **タスク実行は未着手**

### 3. 残タスクの整理
- m_units（荷姿マスタ）→ 後回し
- 在庫照会画面 → 後回し
- MItem.OrderUnitQty → 未使用だが残す（将来のロット制約用）
- MItem.PackageTypeId → 未使用だが残す（m_units 実装時に活用）

---

## 未完了（次回タスク）: 受払台帳画面の実装

### spec 場所
`.xkiro/specs/stock-ledger-page/`

### タスク一覧（未着手）
1. MItem エンティティ拡張 + DB マイグレーション（concentration, specific_gravity, package_type_name）
2. ViewModel クラス作成（StockLedgerViewModel + StockLedgerHeaderInfo）
3. PageModel 実装（OnGetAsync、マトリクスデータ組み立て）
4. AJAX ハンドラ（SavePlanReceipt, SavePlanDispatch）
5. ビルドチェックポイント
6. ビュー実装（ヘッダーセクション）
7. ビュー実装（マトリクステーブル）
8. JavaScript 実装（インライン編集 + 計画在庫再計算）
9. 最終チェックポイント

---

## 残機能（優先度順）

1. ~~単位マスタ m_units~~ → 後回し
2. ~~在庫照会画面~~ → 後回し
3. **受払台帳画面（新規）** ← 次回着手
4. 搬入部門への帳票自動出力（Worker Service）
5. 印刷・FAX送信（環境決定後）
6. マスタメンテナンス・テーブル内容確認ページ（新規）
7. OrderStatusText のハードコードをマスタから動的取得に変更

### 動作確認（後回し — 変更予定あり）
- DeliveryMonitor: フィルタ動作
- Forecasts / Mrp: ページ表示確認

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260521.md`（本ファイル）
- `MaterialModule/Doc/specs/README.md`（spec 一覧インデックス）

### Spec（次回作業対象）
- `.xkiro/specs/stock-ledger-page/requirements.md` — 要件定義（10要件）
- `.xkiro/specs/stock-ledger-page/design.md` — 設計書
- `.xkiro/specs/stock-ledger-page/tasks.md` — 実装計画（9タスク、未着手）

### 完了済み Spec
- `.xkiro/specs/delivery-page-enhancements/` — 全タスク完了
- `.xkiro/specs/dispatches-section-filter/` — 全タスク完了
