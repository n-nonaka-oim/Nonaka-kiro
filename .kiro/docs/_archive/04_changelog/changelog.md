# 発注入力画面（/Material/Orders/Create）変更履歴

## 2026-04-15 変更1: 品目入力方式の変更
- 変更前: ドロップダウン選択
- 変更後: テキスト入力＋サジェスト（インクリメンタルサーチ）
- 仕様: Doc/Text入力：追加指示.md に準拠
  - 300msデバウンス、上限20件、部分一致検索
  - Named Handler: OnGetSearchSuggestAsync
  - IMasterService.SearchItemsAsync(keyword, maxResults) を追加

## 2026-04-15 変更2: 一時テーブル方式への変更
- 変更前: 入力→即t_ordersに登録
- 変更後: 入力→「追加」→一時テーブル(t_order_entries)にユーザー単位で保管→エントリリスト表示→「発注確定」で一括登録
- フロー:
  1. 品目コード入力（サジェスト）→数量・納期等入力→「追加」ボタン
  2. t_order_entriesにユーザーID単位で保存
  3. 登録フォームの下にエントリリスト（追加済み明細一覧）を表示
  4. エントリリストから個別削除可能
  5. 「発注確定」ボタンでt_order_entriesからt_ordersに一括登録
- 新規テーブル: t_order_entries
- 新規エンティティ: TOrderEntry
- 新規サービス: IOrderEntryService / OrderEntryService

## 2026-04-15 変更3: 品目検索の拡張（品名検索対応）
- 変更前: 品目コード（数値のみ）でサジェスト検索
- 変更後: 品目コードまたは品目名で検索可能
  - 入力欄を数値制限なしのテキスト入力に変更
  - item_code OR item_name OR short_name の部分一致検索
  - SearchItemsAsync の WHERE条件を拡張



## 2026-04-15 変更4: m_suppliers テーブル拡張（仕入先得意先一覧.xlsx準拠）
- 変更前: supplier_code, supplier_name のみ
- 変更後: 仕入先得意先一覧.xlsxの全カラムに対応
- 追加カラム: supplier_type, company_code, formal_name, branch_name, account_name, zip_code, address, address_2, tel, fax, registration_no, auto_fax_type, registered_on, is_deleted_company, is_deleted_common
- SQLファイル: Doc/sql/alter_m_suppliers.sql
- 命名規則(db).xlsx準拠: スネークケース、英語表記



## 2026-04-15 変更5: 共有マスタの工場専用DB分離
- 変更前: 全テーブルが db_material_dev に存在
- 変更後: 共有マスタを db_factory_dev に分離
- 工場専用DB: db_factory_dev（開発）/ db_factory_prod（本番）
- 移動対象テーブル:
  - m_warehouses（倉庫マスタ）
  - m_departments（部門マスタ）
  - m_suppliers（仕入先マスタ）
  - m_delivery_locations（搬入場所マスタ）
- db_material_dev からは上記テーブルを削除し、db_factory_dev をクロスDB参照
- 理由: 他プロジェクト（Proposal、SafetyReport等）でも共有するマスタのため



## 2026-04-15 変更6: 搬入場所削除、倉庫表記変更
- 搬入場所（DeliveryLocationId）を発注入力画面から削除
- 倉庫ドロップダウンの表記を「倉庫コード 倉庫名」に変更（例: 0052 第1倉庫）



## 2026-04-15 変更7: m_items.default_order_qty 追加
- m_itemsにdefault_order_qty（デフォルト納入数量）カラムを追加
- 計算式: AVG(t_moto.nyuko_suryo / m_items.order_unit_qty) を ROUND(,0) で丸め
- 品目ごとの月平均入庫数量を入目単位に換算した値



## 2026-04-15 変更8: デフォルト納入数量の自動セットと更新確認
- 品目選択時にdefault_order_qtyを数量欄に自動セット
- エントリ追加時、入力数量とdefault_order_qtyが異なる場合に確認ダイアログ表示
- 「更新する」選択時にm_items.default_order_qtyを新しい値に更新
- IMasterService.UpdateDefaultOrderQtyAsync(itemId, newQty) を追加
- Create.cshtml.cs に OnPostUpdateDefaultQtyAsync ハンドラーを追加



## 2026-04-16 変更9: エントリリスト改善
- 起票日（CreatedAt）列を追加
- 数量表示をF2（小数点以下2桁）に統一
- ヘッダー日本語化（KiroのeditCodeで直接書き込み）

## 2026-04-16 変更10: confirm Window修正
- submit eventのe.submitter問題 → button clickイベントに変更
- hiddenDefaultOrderQtyの設定位置をselectItem関数内に修正

## 2026-04-16 変更11: TOrderEntry IDENTITY修正
- [DatabaseGenerated(DatabaseGeneratedOption.Identity)] 追加
- [Key] 属性追加

## 2026-04-16 技術メモ
- PowerShellスクリプト経由で日本語を含むcshtmlを書き込むと文字化けする
- 対策: KiroのeditCode/fsWriteツールで直接書き込む
- fetchのURLはパスベース(/AuthTest)を含める必要がある → @Url.Page()で動的生成



## 2026-04-17 File Rename: Japanese to English filenames
- Doc/仕入先得意先一覧.xlsx -> Doc/supplier_customer_list.xlsx
- Doc/Text入力：追加指示.md -> Doc/suggest_input_spec.md
- Doc/変更履歴_発注入力.md -> Doc/changelog_order_create.md (already existed)
- Deleted: garbled MD files (PowerShell encoding artifacts)
- Deleted: .kiro/specs/material-module/_test_write.txt (temp file)
- Reason: Japanese filenames cause encoding issues with PowerShell scripts
