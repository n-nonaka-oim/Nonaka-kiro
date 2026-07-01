# セッション備忘録（2026/04/22）

## Orders/Create 要件・仕様変更内容

### 1. 購買条件マスタ（m_purchase_conditions）追加
- SAPから購買条件.xlsxでインターフェイスされるマスタ
- 全40カラム（購買条件.xlsxのレイアウトを踏襲）
- 品目コードの重複あり（複数購買条件）
- 品目コード単一SELECTは適用開始日が最新のものを抽出

### 2. 品目選択の設計変更
- 品目選択のサジェスト検索元: m_items → m_purchase_conditions
- m_purchase_conditionsのitem_code + item_textでキーワード検索
- item_id NULLは除外
- GroupBy(ItemCode) + OrderByDescending(EffectiveDate) で品目コードごとに最新1件
- m_itemsから入目・荷姿・MRPパラメータを取得（item_idで紐づけ）

### 3. 発注書送付先
- 仕入先ドロップダウンを削除
- 品目選択時にm_purchase_conditionsから発注書送付先を自動取得・読み取り専用表示
- 仕入先と送付先は別データ（m_purchase_conditions.supplier_code ≠ destination_code）
- 送付先詳細（TEL/FAX/担当者/部門）はm_suppliersから取得してt_ordersに保存

### 4. t_orders列構成変更
- supplier_id(int FK) → supplier_code(nvarchar) に変更
- delivery_destination_name → destination_name に名称変更
- 追加カラム: condition_no, purchase_type, unit_price, supplier_code, destination_code, destination_contact, destination_department, destination_tel, destination_fax, plant_code, plant_name, output_type, cost_center
- order_no: nvarchar(10) → nvarchar(20) に拡張

### 5. 発注番号の採番仕様
- 旧: MO + yyMMdd + 連番2桁（例: MO26042201）
- 新: プラントコード + '-' + yyMMdd + '-' + 連番3桁（例: G201-260422-001）
- プラントコードはm_purchase_conditionsから取得

### 6. 出力区分
- 0: エントリのみ
- 1: 印刷のみ
- 2: FAXのみ
- 3: 印刷/FAX両方（デフォルト）
- 発注明細入力フォームにドロップダウン追加
- エントリリストに出力区分列を追加

### 7. エントリリスト列構成
- 並び: No, GR区分, 在庫区分, 品目コード, 品目名, 数量, 起票日, 納期, 発注書送付先, 出力区分, 削除
- 「備考」列は削除
- GR区分: m_suppliers.gr_type（仕入先コードから取得）
- 在庫区分: m_purchase_conditions.purchase_type（1:在庫/2:預託）
- ソート機能: 起票日、納期、数量

### 8. 確認ダイアログ
- 削除ボタン: 「削除しますか？」のconfirmダイアログ
- 発注確定ボタン: 「選択したエントリを発注確定しますか？」のconfirmダイアログ
- 未選択時はボタンdisabled

### 9. 購買区分マスタ（m_purchase_types）追加
- 1: 在庫
- 2: 預託

### 10. m_suppliers拡張
- gr_type カラム追加（supplier_code=9909683000のみ'GR'）
- full_name, department, zip_code, address, address_2, tel, fax, company_code をdbNsShizaiから移行

---

## DB変更履歴（2026/04/22）

| テーブル | 変更内容 |
|---|---|
| m_purchase_conditions | DROP＋再作成（全40カラム、購買条件.xlsx準拠） |
| m_purchase_types | 新規作成（1:在庫, 2:預託） |
| m_suppliers | gr_type追加、full_name/department/tel/fax等をdbNsShizaiから移行 |
| t_orders | DROP＋再作成（38カラム、order_no nvarchar(20)に拡張） |
| t_order_entries | DROP＋再作成（supplier_id→supplier_code、gr_type/purchase_type/output_type追加） |
| m_warehouses | conv_code/remarks/capacity削除（エンティティをDBに合わせ） |

---

## エンティティ変更履歴（2026/04/22）

| ファイル | 変更内容 |
|---|---|
| TOrder.cs | 全面書き直し（38カラム対応） |
| TOrderEntry.cs | supplier_id→supplier_code、gr_type/purchase_type/output_type追加 |
| MPurchaseCondition.cs | 全面書き直し（DB実カラムに合わせ、item_code/item_text追加） |
| MSupplier.cs | 全面書き直し（DB実カラムに合わせ） |
| MWarehouse.cs | conv_code/remarks/capacity削除 |
| OrderListDto.cs | DeliveryDestinationName→DestinationName |
| DeliveryMonitorDto.cs | DeliveryDestinationName→DestinationName |
| OrderCreateDto.cs | SupplierId削除、OutputType/CostCenter追加 |
| PurchaseConditionDto.cs | DB実カラムに合わせて書き直し |

---

## サービス変更履歴（2026/04/22）

| ファイル | 変更内容 |
|---|---|
| MasterService.cs | 全面書き直し（SearchItemsAsync: m_purchase_conditionsベース、GroupBy ItemCode） |
| OrderService.cs | 全面書き直し（購買条件から全情報取得、発注番号採番変更） |
| OrderEntryService.cs | 全面書き直し（購買条件からGR区分/購買区分/送付先取得） |
| ApprovalService.cs | DeliveryDestinationName→DestinationName |
| IOrderService.cs | GenerateOrderNoAsync(string? plantCode) に変更 |

---

## ルール確認
- MaterialModule配下のみ変更対象
- 作業前に要件・設計・これまでの修正内容を確認してから着手
- DB設計提案は先に行い、承認を得てから実装
- コードは複雑化しないように進める
- PowerShellでの部分置換は古いコードが残る問題あり → 全体書き直しが確実
