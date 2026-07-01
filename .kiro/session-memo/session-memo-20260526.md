# セッション備忘録（2026/05/26）※補完

> このファイルは 05/22 と 05/27 の差分から推測して補完したものです。
> 05/25（日）〜05/26（月）の作業をまとめて記載しています。

## 完了作業（05/25〜05/26）

### 1. 各ページ UI統一
- 全ページに `<partial name="_MaterialStyles" />` 追加
- コンテナに `class="container-fluid mt-3 px-4 material-page" style="font-size: 0.8rem;"` 設定
- タイトルを `<h5 class="mb-2">` に統一
- テーブルに `style="font-size: 0.75rem;"` 設定
- `_MaterialStyles.cshtml` でドロップダウン・ボタンに `font-size: inherit !important` 設定

### 2. 用語統一
- 「発注日」→「起票日」に変更（Orders/Confirm, Orders/Search, Mrp）
- 「発注単位」→「発注個数」に変更（MasterMaintenance）

### 3. MasterMaintenance AJAX保存修正
- URL: `?handler=SaveItem` → `@Url.Page(...)` 絶対パスに変更
- RowVersion: `byte[]` → `string?`（Base64文字列で受信）
- `[IgnoreAntiforgeryToken]` をクラスレベルに追加
- `@Html.AntiForgeryToken()` 追加
- 保存成功時にページ上部にメッセージ表示
- 「発注個数」の step を整数に変更

### 4. 操作者名の追加
- **DB変更**:
  - t_orders: `confirmed_by`, `confirmed_by_name`, `confirmed_at` 追加
  - t_receivings: `user_name` 追加
  - t_dispatches: `completed_by`, `completed_by_name` 追加
- **エンティティ更新**: TOrder, TReceiving, TDispatch にプロパティ追加
- **OrderListDto**: `ConfirmedByName` フィールド追加
- **Orders/Confirm**: 確定時に確定者名（LastName）を保存、「確定者」列追加
- **Receivings**: 入庫時にユーザー名（LastName）を保存、「入庫者」列追加
- **Delivery**: 搬入完了時にユーザー名（LastName）を保存、「搬入者」列追加

### 5. Orders/Confirm 微調整
- 「一括確定」ボタンに `text-nowrap` 追加
- 発注者ヘッダーをソートリンクに変更
- 「確定者」列を納期確定リストのみ表示（回答待ちリストでは非表示）

### 6. Approvals ページ
- Excel出力ボタンをコメントアウト（非表示）

---

## 未完了（05/27へ持ち越し）

- MRPページ パフォーマンス改善（AlertService N+1解消、データソース統一）
- MRP発注数量計算方式修正
- Receivings/Delivery の操作者表示動作確認
- IIS発行（本番環境反映）

---

## 備考

- 05/23（金）は休日
- 05/24（土）は休日
- 05/25（日）〜05/26（月）の作業を本ファイルにまとめて記載
