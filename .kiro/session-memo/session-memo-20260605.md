# セッション備忘録（2026/06/05 - ページャー展開・レイアウト調整）

## 本日の完了作業

### 1. ページャー上部・下部2か所設置の全ページ展開（完了）
- 共通 `_Pager` partial を全リストページの上部（カードヘッダ直下）・下部に設置
- 適用ページ: Approvals, Receivings, Delivery, JobQueue, Orders/Confirm, Orders/Create, Orders/Search, Mrp
- 件数プロパティはページ毎に指定:
  - Approvals = `TotalOrderCount`
  - Orders/Create = `TotalEntryCount`
  - Mrp = `CurrentPage = Model.PageNo` + `PageParam = "PageNo"`
  - 他 = `TotalCount`
- `Position="top"/"bottom"` で罫線の向きを切替
- 動作確認OK（ユーザー確認済み）

### 2. 横スクロール方針の確定（material-fixed.css）
- 横スクロールはコンテンツ領域(.main-content)内に限定。左サイドバー・上部ナビバーは固定
  - `.main-content { overflow-x: hidden }`
  - `.scroll-wrapper { overflow-x: auto }`（800px未満で全体スクロール）
- コンテンツ大枠 `.material-page { min-width: 800px; max-width: 100% }`
  - 下限800px。中身(テーブル)で押し広げられないよう max-width 制約
- 横長一覧テーブルは `table-responsive` の枠内だけで横スクロール
  - `.material-page .table-responsive { overflow-x: auto; max-width: 100% }`
- 前回の「折り畳み防止（.row nowrap, col幅auto, width:max-content）」は撤回

### 3. ヘッダソートリンクの2行化（列幅縮小・Overflow対策）
- ヘッダのソートリンクが `white-space:nowrap` で固定幅 → Overflowの主因だった
- ラベル(1行目) + 矢印アイコン(2行目・中央) の構成に変更
  - `thead th a { white-space: normal; word-break: break-word; display: inline-block }`
  - `thead th a i { display: block; text-align: center }`（矢印を2行目に落とす）
  - `thead th { vertical-align: top }`
- これで列の最小幅が縮み、ラベル折り返しも有効。矢印の見た目も各列で揃う
- 確認OK（ユーザー確認済み「これで行きましょう」）

### 4. Receivings 0件時の余分な罫線修正
- 空メッセージの colspan を 14 → 16（実列数）に修正
- 入庫者・備考列にはみ出していた罫線が解消

### 5. 左Naviメニュー固定の最終確認（完了）
- `.sidebar { position: sticky; top: 56px; height: calc(100vh - 56px) }` + `.sidebar-body { overflow-y: auto }`（site.css側）
- `.main-content { overflow-x: hidden }`、横スクロールは `.scroll-wrapper` / `.table-responsive` 枠内に限定
- 縦スクロール・横スクロール・ブラウザ幅縮小いずれでもサイドバー固定を実機確認 → 期待通り（ユーザー確認済み）

### 6. リストヘッダのソート矢印アイコン削除（方針変更）
- ソート矢印は不要との方針変更。全ページのソートリンクから `<i class="@SortIcon(...)"></i>` / `<i class="@sortIcon(...)"></i>` を一括削除
- ラベルのみのソートリンクに（リンク機能・サーバーソートは維持）
- 対象: Approvals, Receivings, Delivery, JobQueue, MasterMaintenance, Orders/Confirm, Orders/Create, Orders/Search, Dispatches
- ビルド確認OK（ユーザー確認済み）

### 7. レコード編集の楽観的ロック（同時編集制御）実装（完了）
- 方針: プロジェクトルール準拠の RowVersion（楽観的ロック）
- 編集機能のある4ページに実装: Orders/Confirm, Receivings, Delivery, Orders/Create
- 方式: 編集開始時の RowVersion を hidden(Base64) で保持 → 保存時に「現在DBのRowVersion」と**文字列比較**し、不一致なら競合エラー
  - ※ EF Core の OriginalValue 上書き方式ではセル単位の誤検知があったため、明示的な文字列比較に変更（レコード単位で確実に検知）
- 競合メッセージ: 「他のユーザーが先に更新しました。画面を再読み込みしてください。」（ルール準拠）
- TDispatch に `row_version`（`[Timestamp]`）追加 + DB `ALTER TABLE t_dispatches ADD row_version rowversion;` 実行済み
- TOrder は既存の RowVersion を使用
- OrderListDto に `RowVersion` 追加、ToOrderListDto マッピング更新
- 4ページとも別ユーザー・同レコード・異なるセル変更で競合検知することを実機確認OK（ユーザー確認済み）
- テーブル定義書に t_dispatches の `lot_no`・`row_version` を追記

## 変更ファイル（本セッション）
- `wwwroot/css/material-fixed.css` — 横スクロール方針、ヘッダ2行化、テーブル枠内スクロール
- `Areas/Material/Pages/Approvals/Index.cshtml` — ページャー2か所
- `Areas/Material/Pages/Receivings/Index.cshtml` — ページャー2か所、空colspan 14→16
- `Areas/Material/Pages/Delivery/Index.cshtml` — ページャー2か所
- `Areas/Material/Pages/JobQueue/Index.cshtml` — ページャー2か所
- `Areas/Material/Pages/Orders/Create.cshtml` — ページャー2か所
- `Areas/Material/Pages/Orders/Search.cshtml` — ページャー2か所
- `Areas/Material/Pages/Mrp/Index.cshtml` — ページャー2か所（PageParam=PageNo）
- `Areas/Material/Pages/Orders/Confirm.cshtml` — 前回設置済み

### ソート矢印削除（本セッション後半）
- `Areas/Material/Pages/{Approvals,Receivings,Delivery,JobQueue,MasterMaintenance,Orders/Confirm,Orders/Create,Orders/Search,Dispatches}/*.cshtml` — SortIcon呼び出し削除

### 楽観的ロック（本セッション後半）
- `Models/Dtos/OrderListDto.cs` — RowVersion プロパティ追加
- `Extensions/OrderQueryExtensions.cs` — ToOrderListDto に RowVersion マッピング追加
- `Data/Entities/TDispatch.cs` — RowVersion（[Timestamp]）追加
- `Services/IOrderService.cs` / `OrderService.cs` — UpdateEntryAsync に rowVersion 追加 + 競合検知
- `Areas/Material/Pages/Orders/Confirm.cshtml(.cs)` — RowVersion比較 + hidden
- `Areas/Material/Pages/Receivings/Index.cshtml(.cs)` — RowVersion比較 + hidden
- `Areas/Material/Pages/Delivery/Index.cshtml(.cs)` — RowVersion比較 + hidden
- `Areas/Material/Pages/Orders/Create.cshtml(.cs)` — RowVersion比較 + hidden
- `Doc/テーブル定義書.md` — t_dispatches に lot_no・row_version 追記

## DB変更（本セッション）
- `ALTER TABLE t_dispatches ADD row_version rowversion;` 実行済み

## 未完了（次回タスク）
- 動作確認で出るその他の訂正箇所（随時）
- 前回からの継続: PrintAgent フェーズ4・5

## レイアウト確定事項
- 「リスト下部スクロールバー vs 左Navi固定」→ 左Navi固定優先で確定（問題なく動作、ユーザー確認済み）

---

# 追記（2026/06/05 後半 - 各ページUI調整・動作確認）

## 完了作業（ビルドOK・ユーザー確認済み）

### 1. 競合メッセージ変更（全ページ）
- 「他のユーザーが先に更新しました。画面を再読み込みしてください。」
  → 「対象レコードは他ユーザーが操作した可能性があります。確認してください」
- 理由: 競合時は更新されず最新DB内容を表示する正しい挙動。文言を実挙動に合わせた
- 競合時の表示仕様は「最新DB内容を表示」で確定（ユーザー承認済み）

### 2. 更新ボタン設置 + 検索条件キープ化
- 設置: Approvals, Orders/Confirm, Orders/Create, Receivings, Delivery
- 当初 `location.pathname+location.search` 方式 → 保存(POST)後に条件が消える問題
- 対策: `asp-route-*` でモデルの検索条件をURLに埋め込む方式に変更（保存後も条件維持）

### 3. Orders/Create
- 「登録」ボタンを横幅50%に縮小（w-100 → w-50）

### 4. Orders/Confirm
- 発注者ドロップダウンのデフォルトを担当者（ログインユーザー）に変更

### 5. Receivings
- 「納期 From」→「納入日 From」に変更
- 「一括入庫」→「入庫」に変更
- 「本日納入分」ボタン追加（納入日From/Toに本日セットして検索実行）
- 「送付先」「納期」列を削除（ヘッダ・データ行・colspan 16→14）
- レコード単位の「入庫」ボタンを非表示（コメントアウト、今後復活可）
- レコード無のとき「入庫伝票」ボタンを無効化
- 「表示」「本日納入分」をドロップダウン下の2行目に左寄せ配置（flex強制改行）

### 6. Dispatches
- 搬入場所をドロップダウン → サジェスト方式に変更（locationData をJS埋め込み）
- 削除は各行ボタン廃止 → チェックボックス選択＋ヘッダー「削除」1個に統一
- 削除ボタン・チェックボックスは「未登録」のみ表示（搬入前は表示なし）

### 7. Delivery
- リスト列: 品目名・品目コードの位置を入替（品目コード→品目名）
- 「本日搬入分」ボタン追加（搬入日に本日セットして検索実行）
- レコード単位の「完了」ボタン非表示
- 「一括完了」→「搬入完了」に変更
- 「削除」ボタン追加（チェック選択方式、OnPostBulkDelete、status=1のみ対象）
- ページ更新ボタン追加
- 「表示」「本日搬入分」をドロップダウン下の2行目に左寄せ配置
- **搬入者名バグ修正**: BulkComplete で CompletedBy/CompletedByName 未設定だった → userRepository で姓を取得して設定

### 8. ツールバーボタンの折り返し防止
- Receivings（入庫・入庫伝票・更新）、Delivery（搬入完了・削除・更新）、Approvals/Orders系の更新ボタンに `text-nowrap` 追加

## 未完了（次回タスク）

### MasterMaintenance 他ページ統一（**完了 2026/06/05**）
- ✅ 5タブ全て（items/suppliers/purchase/packages/warehouses）にページング実装
  - PageModel: PageNo/PageSize/TotalCount/CurrentPage/TotalPages 追加、CountAsync+Skip/Take
  - 各タブに更新ボタン・件数コントロール(10/20/30/50)・上下ページャー(_Pager, PageParam=PageNo)
- ✅ 件数セレクタ/ソート/更新のURLを `@Url.Page`(絶対パス)方式に修正
  - 原因: Layout の `<base href="~/">` のため `?...` 相対URLがTOPに飛んでいた
- ✅ 品目マスタ モーダルのモダン化＋フォント縮小（item-modal-modern クラス、3セクション分割）
- ✅ 品目マスタ一覧ヘッダ・データ行を左寄せに統一
- ✅ 「デフォルト発注数」→「標準発注数量(モーダルは標準発注数)」に変更
- ✅ 数量(number)入力欄のスピナー矢印を全ページ・全モーダルで非表示（material-fixed.css）

### 継続案件
- PrintAgent フェーズ4・5
- 動作確認で出るその他の訂正箇所

## 新規追加案件（2026/06/05受領 — ※A=MasterMaintenance統一, B=PrintAgent 完了後に着手）

### G. 原材料 計画単価・数量管理 + 実績対比分析
1. **計画単価・計画数量を MasterMaintenance に追加**
   - 原材料（品目マスタ）に計画単価・計画数量の項目を追加
2. **実績対比分析ページ（新規ページ予定）**
   - 計画単価・数量 vs 実績の対比（影響額・数量差）を即座に提示
   - 集計期間: 毎月 / 半期に1回 / 年1回 / 過去3年実績 / 過去5年実績 / 過去10年実績
3. **仕入先別・用途別 購入実績（上記ページに集約予定）**
   - 仕入先別・用途別の原材料購入実績（数量・金額）
   - 期間設定機能付き
   - ※ 2 と同じページに機能を纏める

- **着手条件**: A（MasterMaintenance統一）と B（PrintAgent）完了後

## 主要変更ファイル（本日後半）
- `Areas/Material/Pages/Approvals/Index.cshtml` — 更新ボタン(asp-route方式)、text-nowrap
- `Areas/Material/Pages/Orders/Confirm.cshtml(.cs)` — 更新ボタン、発注者デフォルト担当者、競合メッセージ
- `Areas/Material/Pages/Orders/Create.cshtml(.cs)` — 更新ボタン、登録ボタン50%、競合メッセージ
- `Areas/Material/Pages/Receivings/Index.cshtml(.cs)` — 納入日ラベル、入庫ボタン名、本日納入分、列削除、入庫ボタン非表示、入庫伝票無効化、更新、ボタン配置、競合メッセージ
- `Areas/Material/Pages/Dispatches/Index.cshtml(.cs)` — 搬入場所サジェスト、削除統一仕様、競合メッセージ
- `Areas/Material/Pages/Delivery/Index.cshtml(.cs)` — 列入替、本日搬入分、完了ボタン非表示、搬入完了改名、削除ボタン、更新、ボタン配置、搬入者名バグ修正、競合メッセージ
- `Services/OrderService.cs` — 競合メッセージ
- その他（OrderPlanning, TankCheck, MasterMaintenance の cshtml.cs）— 競合メッセージ一括変更

## 備考
- Kiro更新のため一時中断。再開時は本メモから継続。
- 全変更ファイル 診断エラーなし。ユーザー側ビルド・動作確認済み。

## 参照ファイル一覧（再開時に読むべきファイル）
- `MaterialModule/Doc/session-memo-20260605.md`（本ファイル）
- `MaterialModule/Doc/session-memo-20260604.md`（前セッション: UI改善・ソート統一）
- `.kiro/steering/project-rules.md`（プロジェクトルール — 自動読込）
- `wwwroot/css/material-fixed.css`（共通スタイル正本）
- `Areas/Material/Pages/_Pager.cshtml` / `PagerModel.cs`（共通ページャー）
