# セッション備忘録（2026/05/13）

## 本日の完了作業

### 1. Kiro Steering File 作成
- `clnCoCore/.kiro/steering/material-module.md` を新規作成
- MaterialModule関連ファイルを触ると自動読み込みされる設定（fileMatch）
- プロジェクトルール、ステータスフロー、採番仕様、アーキテクチャパターン等を集約

### 2. 発注番号採番仕様変更
- **採番タイミング**: Orders/Create「登録」時 → **Approvals「承認」時**（ステータス20→30）
- **グループ条件**: 送付先コード + 品目コード + 発注者 + 出力区分
- **枝番上限**: 最大20件、21件以上でグループ番号カウントアップ
- **フォーマット**: `プラントコード-yyMMdd-グループ番号3桁-連番3桁`（例: G201-260513-001-001）
- Orders/Create「登録」時はorder_no空のまま（ステータス10→20のみ）
- ApprovalService に IOrderService 依存追加、承認時に一括グループ採番

### 3. Approvals画面改修
- 未承認リスト・差戻しリスト: 発注番号列を非表示
- 承認済リスト: 発注番号列あり（ソート可）、品目名ソート追加
- **デフォルトソート（未承認/差戻し）**: 起票日昇順 → 品目名昇順
- **デフォルトソート（承認済）**: 発注番号日付部分降順 → グループ番号昇順 → 枝番昇順

### 4. Orders/Create改修
- ページサイズ切り替えドロップダウン追加（10/20/30/50件）
- ページャーコントロールをApprovalsと同じ形式に統一（««/«/ページ番号/»/»»）
- **デフォルトソート**: 起票日降順
- 件数表示: 現ページ件数 → 全件数に変更

### 5. JobQueue改修（グループ単位化）
- リスト表示: 1発注=1行 → **発注番号グループ単位=1行**
- 表示列: 発注番号グループ、代表品目名（枝番001）、件数、送付先、承認日時、印刷、FAX、PDF
- 出力区分列: 削除（印刷/FAX列で判断可能）
- フィルタ: onchangeで即反映（検索ボタン削除）

### 6. 発注書兼納入依頼書PDF改修
- **グループ単位1ページ**: 最大20件明細を1ページに表示
- **削除項目**: 仕入先名称、購買条件No、受入工場、合計金額
- **追加列**: 納期（MM/dd）、納入場所
- **追加**: QRコード（発注番号グループコード）— 押印枠の左側に配置
- **備考**: 2行罫線
- **左余白**: +15mm（25→40mm）
- **押印枠**: 正方形（80×40、2セル構成）
- **フォントサイズ**: 明細9pt
- **QRCoder 1.6.0** パッケージ追加

### 7. 帳票レコード作成条件変更
- output_typeに関係なく、承認時は常に `print_status = 1`（待機）で作成

---

## 現在のステータスフロー（確定）

| order_status | 表示名 | タイミング |
|---|---|---|
| 10 | エントリ | 新規入力 |
| 15 | 差戻し | 差戻し（order_noリセット） |
| 20 | 承認待ち | 登録ボタン（order_noは空） |
| 30 | 承認済み | 承認ボタン（**ここで発注番号採番**） |
| 50 | 注文確定 | FAX返信確認（Confirm画面） |
| 60 | 入庫済み | 倉庫入れ（Receivings画面） |

---

## 次回の作業予定

### PDF出力方式の検討
- 現状: 別タブでPDF表示（inline）
- 検討: PDFボタン → ローカルPC保管 → PDFオープン
- 方法: JavaScript fetch → Blob保存 + window.open（Blob URL）

### 動作確認（残り）
- Orders/Confirm: 確定/未確定
- Receivings: 入庫
- DeliveryMonitor: フィルタ動作
- Forecasts / Mrp: ページ表示確認

### 残機能
1. 単位マスタ m_units
2. 在庫照会画面（新規）
3. 受払台帳画面（新規）
4. 搬入部門への帳票自動出力（Worker Service）
5. 印刷・FAX送信（環境決定後）
6. 搬入前リスト管理ページ

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
- 未承認リスト: チェックボックス + 承認/差戻しボタン、発注番号列なし
- 承認済リスト: No列表示、発注番号列あり（ソート可）、操作ボタンなし
- 差戻しリスト: No列表示、発注番号列なし、操作ボタンなし
- 承認処理: ステータス20→30 + 発注番号採番（グループ: 送付先+品目+発注者+出力区分、枝番最大20件）
- 差戻し処理: ステータス20→15、order_no/order_line_no/order_dateリセット
- **デフォルトソート（未承認/差戻し）: 起票日昇順 → 品目名昇順**
- **デフォルトソート（承認済）: 発注番号日付部分降順 → グループ番号昇順 → 枝番昇順**
- ソート可能列: 合計数量、起票日、納期、発注番号（承認済のみ）、品目名
- Excel出力、フォントサイズ0.85rem

### JobQueue
- リスト単位: 発注番号グループ（プラント-日付-グループ番号）
- 表示列: 発注番号グループ、代表品目名、件数、送付先、承認日時、印刷、FAX、PDF
- フィルタ: 待機(1)/完了(2)/エラー(9) — onchangeで即反映
- PDF: グループ単位で生成（GenerateGroupOrderPdfAsync）

### 発注書兼納入依頼書PDF
- グループ単位1ページ（最大20件明細）
- ヘッダー: タイトル、発注番号グループ、発行日、送付先御中、自社情報、担当者、QRコード+押印枠
- 明細テーブル: No、品目コード、品目名、個数、入目、数量、単位、単価、金額、納期、納入場所
- フッター: 備考2行罫線、注記
- 削除済み: 仕入先名称、購買条件No、受入工場、合計金額

### Orders/Confirm
- 確定前(30) / 確定済(50) 切り替え
- 確定: 30→50、未確定戻し: 50→30

### Receivings
- 入庫前(50) / 入庫済(60) 切り替え
- 入庫: 50→60 + 在庫増加（StockService.IncrementStockAsync）

### Dispatches
- エントリ追加 → 登録（在庫減算 + PDF出力オプション）
- 搬入前リスト: 閲覧のみ

### DeliveryMonitor
- 期間From-To + ステータスフィルタ
- 対象: ステータス30, 50
- 残日数表示、超過は赤字

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
- `MaterialModule/Doc/session-memo-20260513.md`（本ファイル）

### 主要変更ファイル
- `Services/OrderService.cs` — 採番ロジック（GenerateGroupedOrderNosAsync、枝番最大20件）
- `Services/ApprovalService.cs` — 承認時採番、IOrderService依存追加
- `Services/IOrderService.cs` — GenerateGroupedOrderNosAsync追加
- `Services/OrderPdfService.cs` — グループPDF生成（GenerateGroupOrderPdfAsync）、QRコード
- `Services/IOrderPdfService.cs` — GenerateGroupOrderPdfAsync追加
- `Areas/Material/Pages/Orders/Create.cshtml` + `.cs` — ページャー改修、デフォルトソート
- `Areas/Material/Pages/Approvals/Index.cshtml` + `.cs` — 発注番号列条件表示、ソート追加
- `Areas/Material/Pages/JobQueue/Index.cshtml` + `.cs` — グループ単位リスト化
- `MaterialModule.csproj` — QRCoder 1.6.0 追加
- `clnCoCore/.kiro/steering/material-module.md` — Steering File新規作成
