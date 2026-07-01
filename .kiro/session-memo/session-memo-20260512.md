# セッション備忘録（2026/05/12）

## 本日の完了作業

### 1. Dispatches（出庫/工場入請求）
- 搬入前リストのチェックボックス・戻すボタンを非表示化（将来管理ページで対応）
- サーバー側OnPostRecoverAsyncにSuperUserチェック追加（防御）
- PDF出力チェックボックス追加（デフォルトChecked、未チェック時はPDF生成なし）
- submitEntries関数の重複を統合

### 2. 表記変更「数量」→「個数」
- Orders/Create: 入力ラベル、リストヘッダー、バリデーションメッセージ
- Orders/Confirm: リストヘッダー
- Receivings/Index: リストヘッダー
- DeliveryMonitor/Index: 「発注数量」→「発注個数」
- JobQueue/Index: リストヘッダー
- 発注書PDF（OrderPdfService）: 「数量」→「個数」、「合計」→「数量」

### 3. PDF表示方式変更
- JobQueue/Search: ダウンロード→ダイレクトオープン（ファイル名省略でinline表示）

### 4. m_order_statuses マスタ化
- テーブル作成（id=10,15,20,30,40,50,60）
- エンティティ MOrderStatus.cs 作成
- DbContextにDbSet追加
- IMasterService/MasterServiceにGetOrderStatusesAsync/GetStatusNameAsync追加
- DeliveryMonitorのステータス名をマスタ参照に変更
- ステータス40（発注済み）をis_active=0に無効化

### 5. ステータスフロー変更（40廃止）
- 新フロー: エントリ(10) → 承認待ち(20) → 承認済み(30) → 注文確定(50) → 入庫済み(60)
- Orders/Confirm: 確定前ステータス 40→30、確定 30→50、未確定戻し 50→30

### 6. DeliveryMonitor改修
- フィルタ: 年/月ドロップダウン → 期間From-To + ステータスフィルタ
- デフォルト: 未納全件
- ステータス表示名: マスタから取得（回答待ち/注文確定）
- 対象: ステータス30と50のみ

### 7. Orders/Create コンパクト化
- 1行目: 品目(3) | 入目(1) | 個数(1) | 納期(2) | 倉庫(2) | 出力(2)
- 2行目: 送付先(3) | 備考(5) | エントリボタン(2)
- form-control-sm / form-select-sm 適用
- エントリリスト: font-size 0.85rem
- 「エントリ追加」→「エントリ」
- 出力区分「エントリのみ」→「出力なし」
- 登録ボタン: disabled制御（チェック0件でdisabled、Approvalsと同仕様）
- 未選択時「全件登録しますか？」→OK→全件チェック→登録
- 品目名ソート追加
- デフォルト個数未設定時: エントリ時の入力個数を自動保存
- formnovalidate追加（登録・削除ボタン）
- required属性削除（OrderQty）→ JS側バリデーションで代替
- ModelState.Clear()追加（Remove/Submitハンドラー）
- エントリ後クリア: 個数・倉庫・納期・備考・送付先表示

### 8. 発注番号採番仕様変更
- フォーマット: `プラントコード-yyMMdd-グループ番号3桁-連番3桁`（例: G201-260512-001-001）
- 採番タイミング: Orders/Create登録ボタン時（承認時ではない）
- グループ化: 送付先コード + 品目コードが同一 → 同一グループ番号
- GenerateGroupedOrderNosAsync メソッド新規作成

### 9. Approvals改修
- ドロップダウン: 「承認待ち/承認済み/差戻し」→「未承認/承認済/差戻し」
- リストヘッダー: 「発注一覧」→「未承認リスト/承認済リスト/差戻しリスト」
- ドロップダウン: onchangeで即反映（検索ボタン削除）
- 発注番号列: 復活（全ステータスで表示）
- 差戻し処理: order_no/order_line_no/order_dateをNULLリセット
- 承認済リスト: PDF列削除
- 行内ボタン: 幅縮小（px-1）、「差戻し」→「戻す」
- リスト外ボタン: 「一括承認」→「承認」、「差戻し」ボタン新規追加
- 承認/差戻しボタン: 未承認リスト時のみ表示
- disabled制御: チェック0件で両ボタンdisabled
- テーブルフォントサイズ: 0.85rem

### 10. StockService動作確認
- 在庫レコード未存在時の新規作成: ✅ 動作OK
- マイナス発注（倉庫戻し）で在庫増加: ✅ 動作OK

---

## 現在のステータスフロー（確定）

| order_status | 表示名（m_order_statuses） | タイミング |
|---|---|---|
| 10 | エントリ | 新規入力 |
| 15 | 差戻し | 差戻し（order_noリセット） |
| 20 | 承認待ち | 登録ボタン（order_no採番） |
| 30 | 承認済み | 承認ボタン |
| ~~40~~ | ~~発注済み~~ | ~~廃止（is_active=0）~~ |
| 50 | 注文確定 | FAX返信確認（Confirm画面） |
| 60 | 入庫済み | 倉庫入れ（Receivings画面） |

---

## 各ページ仕様（現在）

### Orders/Create
- 品目サジェスト検索（m_purchase_conditions + m_items）
- 1行目: 品目 | 入目 | 個数 | 納期 | 倉庫 | 出力区分
- 2行目: 送付先（自動） | 備考 | エントリボタン
- エントリリスト: チェックボックス + 登録ボタン（disabled制御）+ 削除ボタン
- 登録時: ステータス10→20（発注番号は承認時に採番）
- デフォルト個数: 未設定時は入力値を自動保存
- **デフォルトソート: 起票日降順**
- ページサイズ切り替え: 10/20/30/50件

### Approvals
- ドロップダウン: 未承認(20) / 承認済(30) / 差戻し(15) — onchangeで即反映
- リストヘッダー: 「未承認リスト」「承認済リスト」「差戻しリスト」
- 未承認リスト: チェックボックス + 承認/差戻しボタン（リスト外・行内両方）、発注番号列なし
- 承認済リスト: No列表示、発注番号列あり（ソート可）、操作ボタンなし
- 差戻しリスト: No列表示、発注番号列なし、操作ボタンなし
- 承認処理: ステータス20→30 + 発注番号採番（グループ: 送付先+品目+発注者+出力区分、枝番最大10件）
- 差戻し処理: ステータス20→15、order_no/order_line_no/order_dateリセット
- **デフォルトソート（未承認/差戻し）: 起票日昇順 → 品目名昇順**
- **デフォルトソート（承認済）: 発注番号日付部分降順 → グループ番号昇順 → 枝番昇順**
- ソート可能列: 合計数量、起票日、納期、発注番号（承認済のみ）、品目名
- Excel出力、フォントサイズ0.85rem

### Orders/Confirm
- 確定前(30) / 確定済(50) 切り替え
- 確定: 30→50、未確定戻し: 50→30
- 検索・ソート・ページング

### Receivings
- 入庫前(50) / 入庫済(60) 切り替え
- 入庫: 50→60 + 在庫増加（StockService.IncrementStockAsync）
- 入庫伝票PDF

### Dispatches
- エントリ追加 → 登録（在庫減算 + PDF出力オプション）
- 搬入前リスト: 閲覧のみ（チェックボックス・戻すボタン非表示）
- PDF出力チェックボックス（デフォルトChecked）

### DeliveryMonitor
- 期間From-To + ステータスフィルタ（マスタから動的生成）
- 対象: ステータス30, 50
- 残日数表示、超過は赤字

### JobQueue / Orders/Search
- PDFダイレクトオープン（別タブ表示）

---

## 明日の作業予定

### 動作確認
1. Orders/Create: 登録→発注番号採番（グループ番号付き）
2. Approvals: 承認/差戻し/一括操作
3. Orders/Confirm: 確定/未確定
4. Receivings: 入庫
5. DeliveryMonitor: フィルタ動作
6. Forecasts / Mrp: ページ表示確認

### 残機能
1. 単位マスタ m_units
2. 在庫照会画面（新規）
3. 受払台帳画面（新規）
4. 搬入部門への帳票自動出力（Worker Service）
5. 印刷・FAX送信（環境決定後）
6. 搬入前リスト管理ページ

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
- PowerShellでのファイル書き込みは禁止（ファイル破損リスク）→ str_replace/fs_writeのみ使用

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260512.md`（本ファイル）

### 主要変更ファイル
- `Services/OrderService.cs` — 採番ロジック（GenerateGroupedOrderNosAsync）
- `Services/ApprovalService.cs` — 承認/差戻し（order_noリセット）
- `Areas/Material/Pages/Orders/Create.cshtml` + `.cs` — コンパクト化・登録ロジック
- `Areas/Material/Pages/Approvals/Index.cshtml` + `.cs` — UI改修・一括差戻し
- `Areas/Material/Pages/DeliveryMonitor/Index.cshtml` + `.cs` — フィルタ改修
- `Areas/Material/Pages/Orders/Confirm.cshtml.cs` — ステータス30→50
- `Data/Entities/MOrderStatus.cs` — 新規エンティティ
- `Doc/sql/create_m_order_statuses.sql` — マスタ作成SQL
