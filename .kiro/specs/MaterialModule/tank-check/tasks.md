# 実装計画: タンク残量チェック

## 概要

タンク残量チェックページ（/Material/TankCheck）を実装する。品目マスタ（m_items）からタンクマスタ（m_tanks）を自動生成し、日次のタンク残量チェック記録を一括保存する単一ページ構成。保存時に前日出庫レコードを t_dispatches に自動登録する。

## タスク

- [x] 1. SQLスクリプト作成とエンティティ定義（1.1〜1.4）
- [x] 2. チェックポイント — ビルド確認
- [x] 3. PageModel実装（3.1〜3.5）
- [x] 4. ビュー実装（4.1〜4.3）
- [x] 5. チェックポイント — 全体動作確認

## 追加実装（05/30〜06/02）

- [x] 6. UI改修
  - [x] タンクマスタ生成ボタン削除
  - [x] 行単位保存 → ヘッダ一括保存に変更（OnPostSaveAllAsync）
  - [x] 担当者列削除（サーバー側自動セット）
  - [x] 前日残量列追加
  - [x] 読込みボタン追加（確認ダイアログ付き）
  - [x] 保存ボタンに確認ダイアログ追加
  - [x] 比重を変更不可（m_items.specific_gravity をテキスト表示）
  - [x] 時間入力フィールド追加（デフォルト 07:00、全レコードに反映）
  - [x] t_tank_checks に check_time 列追加
  - [x] 前日入庫数量列追加（order_qty × unit_content_qty / 1000、Key: ItemId + WarehouseCode）
  - [x] 使用数量列追加（前日残 - 当日残 + 入庫数量）
  - [x] 保存成功後にページリロード
  - [x] m_tanks.sort_order 列追加 + ソート対応
  - [x] 残数量入力を小数点2桁に統一
  - [x] 入力行フォーカス時ハイライト
  - [x] 特記事項表示（北No.22 +15 / 南No.10,11 +2 / 南No.7 +2.5）
  - [x] Enterキーで保存
  - [x] 担当者名をヘッダに表示（IUserRepository → LastName）

- [x] 7. 出庫自動登録機能
  - [x] 保存時に t_dispatches へ前日出庫レコードを自動登録
  - [x] 出庫数量 = 前日残量 + 前日入庫数量 - 当日残量
  - [x] 前日入庫数量 = t_orders（status=60, received_date=前日, warehouse_code=tank_no）の order_qty × unit_content_qty / 1000
  - [x] 出庫日付: 前日、warehouse_code: tank_no
  - [x] 既存レコードあれば更新（Upsert）
  - [x] Status=2、Remarks="タンクチェック自動登録"

- [x] 8. 動作確認完了
