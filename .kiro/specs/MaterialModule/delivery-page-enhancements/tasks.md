# 実装計画: 出庫管理ページ改善

## 概要

既存のDelivery/Indexページに対して、文言変更・倉庫フィルタ追加・「戻す」機能を段階的に実装する。PageModel（Index.cshtml.cs）のロジック変更を先に行い、次にビュー（Index.cshtml）のUI変更を適用する。

## タスク

- [x] 1. PageModelにWarehouseFilterプロパティとLoadWarehousesAsyncメソッドを追加
  - [x] 1.1 WarehouseFilterプロパティとWarehousesリストを追加し、LoadWarehousesAsyncを実装する
    - `Index.cshtml.cs`に`[BindProperty(SupportsGet = true)] public string? WarehouseFilter`プロパティを追加
    - `public List<string> Warehouses { get; set; } = [];`プロパティを追加
    - `LoadWarehousesAsync()`メソッドを実装（Status 1/2のレコードからdistinct WarehouseNameを取得）
    - `OnGetAsync`内で`LoadWarehousesAsync()`を呼び出す
    - _要件: 3.1, 3.4_

  - [x] 1.2 LoadItemsAsyncにWarehouseFilterによる絞り込み条件を追加する
    - `LoadItemsAsync()`内で`WarehouseFilter`が空でない場合に`d.WarehouseName == WarehouseFilter`のWhere条件を追加
    - _要件: 3.2, 3.3_

- [x] 2. OnPostRevertAsyncハンドラを実装する
  - [x] 2.1 OnPostRevertAsyncメソッドを追加する
    - `Index.cshtml.cs`に`OnPostRevertAsync(int dispatchId)`を実装
    - 対象レコードが存在しない、またはStatus≠2の場合はErrorMessage="対象が見つからないか、戻せない状態です。"を設定
    - 正常時はStatus=2→1、CompletedAt=null、UpdatedAt=現在時刻に更新
    - 成功時はSuccessMessage="搬入前に戻しました。"を設定
    - DB例外時はErrorMessage=ex.Messageを設定
    - 処理後に`LoadDepartmentsAsync()`、`LoadWarehousesAsync()`、`LoadItemsAsync()`を呼び出してPage()を返す
    - _要件: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [x] 3. 既存ハンドラのメッセージ文言を変更する
  - [x] 3.1 OnPostCompleteAsyncとOnPostBulkCompleteAsyncのSuccessMessageを変更する
    - `OnPostCompleteAsync`: SuccessMessageを"搬入完了しました。"に変更
    - `OnPostBulkCompleteAsync`: SuccessMessageを"{count} 件を搬入完了しました。"に変更
    - 両ハンドラ内で`LoadWarehousesAsync()`呼び出しを追加
    - _要件: 5.5, 5.6_

- [x] 4. チェックポイント - PageModel変更の確認
  - すべてのビルドが通ることを確認し、質問があればユーザーに確認する。

- [x] 5. ビューの文言変更を適用する
  - [x] 5.1 ページタイトル・カードヘッダー・列ヘッダーを変更する
    - `Index.cshtml`の`ViewData["Title"]`を"運搬管理"→"出庫管理"に変更
    - card-headerの"運搬リスト"→"出庫リスト"に変更
    - 列ヘッダーの"操作"→"搬入"に変更
    - _要件: 1.1, 2.1, 4.1_

  - [x] 5.2 ステータスバッジとconfirmメッセージを変更する
    - Status=2のバッジテキストを"完了"→"搬入済"に変更
    - Status=1のバッジテキストを"未完了"→"搬入前"に変更
    - 個別完了ボタンのconfirmを"運搬完了しますか？"→"搬入完了しますか？"に変更
    - 一括完了ボタンのconfirmを"選択した項目を運搬完了しますか？"→"選択した項目を搬入完了しますか？"に変更
    - _要件: 5.1, 5.2, 5.3, 5.4_

- [x] 6. ビューに倉庫フィルタUIを追加する
  - [x] 6.1 検索フォームに倉庫ドロップダウンを追加する
    - 「請求部門」ドロップダウンの後に「倉庫」ドロップダウンを配置
    - デフォルト選択肢は"全倉庫"（value=""）
    - `Model.Warehouses`からオプションを動的生成
    - _要件: 3.1, 3.2_

  - [x] 6.2 全フォームとリンクにWarehouseFilterのhidden fieldとルートパラメータを追加する
    - 一括完了フォーム（bulkForm）にWarehouseFilter hidden fieldを追加
    - 個別完了フォームにWarehouseFilter hidden fieldを追加
    - ソートリンク（date, item, warehouse, location）にasp-route-WarehouseFilterを追加
    - ページネーションリンクにasp-route-WarehouseFilterを追加
    - ページサイズ変更のonchange URLにWarehouseFilterパラメータを追加
    - _要件: 3.5_

- [x] 7. ビューに「戻す」ボタンUIを追加する
  - [x] 7.1 Status=2のレコードの操作列に「戻す」ボタンを追加する
    - `isCompleted`がtrueの場合に「戻す」ボタンのフォームを表示
    - フォームにはdispatchId、DateFrom、DateTo、DepartmentFilter、WarehouseFilterのhidden fieldを含める
    - ボタンクリック時にconfirm('搬入前に戻しますか？')を表示
    - ボタンスタイルは`btn btn-sm btn-outline-secondary`
    - _要件: 6.1, 6.2, 6.6_

- [x] 8. 最終チェックポイント - 全体確認
  - すべてのビルドが通ることを確認し、質問があればユーザーに確認する。

## 備考

- テスト関連タスクは`*`マーク付きで省略可能
- 各タスクは特定の要件を参照しトレーサビリティを確保
- チェックポイントで段階的に検証を実施
- PBT（Property-Based Testing）は本機能では対象外（設計書に記載の通り）
- 文言変更はビュー側のみ、ロジック変更はPageModel側のみに分離

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1"] },
    { "id": 2, "tasks": ["5.1", "5.2"] },
    { "id": 3, "tasks": ["6.1", "6.2", "7.1"] }
  ]
}
```
