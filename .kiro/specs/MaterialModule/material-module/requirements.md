# Materialモジュール 要件定義書

## 概要
CoCoreソリューションにおける原材料管理モジュール。原材料の発注（手動・自動）、倉庫受入、現場払い出し、納期監視、発注承認フロー、およびMRP標準ロジック（BOM展開・正味所要量計算・ロットまとめ・リードタイムオフセット）に基づく消化予測・発注予測・仮発注機能を提供する。
DemoModuleの構成・作法および基幹システム構築基準に準拠して構築する。

## 参照ドキュメント
- 基幹システム構築基準: `\\OJIADM23120073\Labs\sdoc\基幹システム構築基準.md`
- DB命名規則: `\\OJIADM23120073\Labs\sdoc\命名規則(db).xlsx`
- DemoModule: `\\OJIADM23120073\Labs\web\asp\CoCore\DemoModule`
- 現行WEBシステム（IMIS）: `\\OJIADM23120073\Labs\nt182028\backup\NsASPWF`
- 現行デスクトップアプリ（NsAsap）: `\\OJIADM23120073\Labs\nt182028\NsAsap`
- 現行DB: dbNsShizai（OJIADM23120073）

## 開発環境
- OS: Windows / 共有フォルダ: Windowsサーバー（UNCパス）
- プロジェクトフォルダ: `\\OJIADM23120073\Labs\web\asp\CoCore\Nonaka\Material`

## 前提条件
- DBサーバー: OJIADM23120073（SQL Server、SA認証）
- DB名: db_material_dev（開発）/ db_material_prod（本番）※命名規則 db_[目的]_[環境] に準拠
- DB接続文字列はMainWebの `appsettings.json` で管理
- 認証・認可はAuthModuleのDbPermissionCheckポリシーを使用

---

## DB命名規則（命名規則(db).xlsxより）

| 対象 | プレフィックス | ルール |
|---|---|---|
| トランザクション | t_ | t_ + 複数形名詞 |
| マスタ | m_ | m_ + 複数形名詞 |
| 中間テーブル | r_ | r_ + テーブル1 + テーブル2 |
| カラム | (なし) | スネークケース、英語表記 |
| 必須カラム | | id, created_at, updated_at |
| 外部キー: テーブル名(単数)_id / 数量: _qty / 金額: _amount,_price / 日付: _date(DATE),_at(TIMESTAMP) / フラグ: is_,has_ / コード: _code,_no |

---

## 新DBテーブル定義（db_material）

### マスタテーブル

#### m_items（原材料マスタ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| item_code | nvarchar(50) | YES | 品目コード |
| item_name | nvarchar(256) | YES | 品目名称 |
| short_name | nvarchar(256) | | 略称 |
| order_unit_qty | decimal | YES | 発注数量単位 |
| content_qty | decimal | | 入目（荷姿あたり内容量） |
| content_unit | nvarchar(50) | | 入目単位 |
| package_type_id | int | FK | 荷姿マスタ参照 |
| default_delivery_days | int | YES | デフォルト納期日数（デフォルト: 14） |
| lead_time_days | int | YES | 調達リードタイム日数（MRP計算用、default_delivery_daysと同値可） |
| stock_minimum_qty | decimal | | 最低在庫数量（この値以下でアラート・発注手配） |
| safety_stock_qty | decimal | | 安全在庫数量（MRP正味所要量計算で加算） |
| lot_size_type | nvarchar(10) | YES | ロットサイズ方式（fixed_qty/lot_for_lot） |
| fixed_lot_qty | decimal | | 固定ロット数量（lot_size_type='fixed_qty'の場合） |
| receiving_unit_qty | decimal | | 入庫単位数量 |
| warehouse_id | int | FK | デフォルト倉庫 |
| supplier_id | int | FK | デフォルト仕入先 |
| department_id | int | FK | 部門 |
| brand_id | int | FK | ブランド |
| input_lot | int | | 入力ロット |
| is_active | bit | YES | 有効フラグ |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

※ lot_size_type:
- `fixed_qty`: 固定数量発注（fixed_lot_qtyで発注）
- `lot_for_lot`: 正味所要量をそのまま発注（必要量ぴったり）


#### m_suppliers（仕入先マスタ）
id(PK), supplier_code, supplier_name, is_active, created_at, updated_at

#### m_warehouses（倉庫マスタ）
id(PK), warehouse_code, warehouse_name, is_active, created_at, updated_at

#### m_package_types（荷姿マスタ）
id(PK), package_type_name, created_at, updated_at

#### m_departments（部門マスタ）
id(PK), department_code, department_name, sort_id, is_active, created_at, updated_at

#### m_delivery_locations（搬入場所マスタ）
id(PK), department_id(FK), location_name, sort_id, remarks, created_at, updated_at

#### m_order_statuses（発注ステータスマスタ）
id(PK), status_name, next_status_id(FK), restore_status_id(FK), created_at, updated_at

#### m_forecast_sources（消化予測ソースマスタ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| source_code | nvarchar(20) | YES | ソースコード |
| source_name | nvarchar(50) | YES | ソース名称 |
| is_active | bit | YES | 有効フラグ |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

初期データ: manual（手動入力）、production_plan（生産計画連携）、bom_explosion（BOM展開）

#### m_bom_headers（BOMヘッダ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| product_code | nvarchar(50) | YES | 製品コード |
| product_name | nvarchar(256) | YES | 製品名称 |
| version | nvarchar(10) | YES | BOMバージョン |
| effective_date | date | YES | 有効開始日 |
| expiry_date | date | | 有効終了日 |
| is_active | bit | YES | 有効フラグ |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

#### m_bom_details（BOM明細）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| bom_header_id | int | FK | BOMヘッダ参照 |
| item_id | int | FK | 原材料（m_items参照） |
| usage_qty | decimal | YES | 使用量（製品1単位あたり） |
| unit | nvarchar(10) | YES | 単位 |
| scrap_rate | decimal | | 歩留まりロス率（%）（デフォルト: 0） |
| sort_id | int | | 表示順 |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

※ BOMは将来の生産計画連携で使用。現フェーズではテーブル構造のみ定義し、データは空。
※ 総所要量 = 生産計画数量 × usage_qty × (1 + scrap_rate/100)

### トランザクションテーブル

#### t_orders（発注データ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| order_no | nvarchar(10) | YES | 発注番号 |
| order_line_no | nvarchar(4) | YES | 発注明細番号 |
| order_date | date | YES | 発注日 |
| order_type | nvarchar(10) | YES | 発注種別（manual/auto/provisional） |
| item_id | int | FK | 品目 |
| item_code | nvarchar(50) | YES | 品目コード |
| item_name | nvarchar(256) | | 品目名（スナップショット） |
| order_qty | decimal | YES | 発注数量 |
| unit_content_qty | decimal | | 単位入目 |
| total_qty | decimal | | 発注数量合計 |
| supplier_id | int | FK | 仕入先 |
| supplier_name | nvarchar(80) | | 仕入先名（スナップショット） |
| delivery_date | date | YES | 納期 |
| warehouse_id | int | FK | 倉庫 |
| delivery_location_id | int | FK | 搬入場所 |
| order_status_id | int | FK | ステータス |
| remarks | nvarchar(256) | | 備考 |
| user_id | nvarchar(40) | YES | 発注者ID |
| user_name | nvarchar(40) | | 発注者名 |
| approved_at | datetime | | 承認日時 |
| approved_by | nvarchar(40) | | 承認者 |
| forecast_id | int | FK | 発注予測参照（所要ロジック由来の場合） |
| confirmed_by | nvarchar(40) | | 確定者ID |
| confirmed_by_name | nvarchar(40) | | 確定者名 |
| confirmed_at | datetime | | 確定日時 |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

#### t_receivings（受入データ）
id(PK), order_id(FK), received_date, received_qty, warehouse_id(FK), remarks, user_id, user_name, created_at, updated_at

#### t_dispatches（払い出しデータ）
id(PK), dispatch_date, item_id(FK), dispatch_qty, warehouse_id(FK), destination, department_id(FK), remarks, user_id, completed_by, completed_by_name, created_at, updated_at

#### t_stocks（在庫データ）
id(PK), item_id(FK), warehouse_id(FK), stock_qty, updated_at

#### t_stock_ledgers（在庫台帳 — 日別推移）
id(PK), record_date, item_id(FK), carried_over_qty, reserved_qty, received_qty, dispatched_qty, dispatch_count, stock_qty, created_at, updated_at


#### t_consumption_forecasts（消化予測データ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| item_id | int | FK | 品目 |
| forecast_date | date | YES | 予測対象日 |
| forecast_qty | decimal | YES | 予測消化数量 |
| source_id | int | FK | 予測ソース（m_forecast_sources参照） |
| source_reference_id | nvarchar(50) | | 外部参照ID（生産計画番号、BOMヘッダID等） |
| user_id | nvarchar(40) | YES | 入力者/生成者ID |
| remarks | nvarchar(256) | | 備考 |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

#### t_order_forecasts（発注予測データ）
| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー |
| item_id | int | FK | 品目 |
| forecast_date | date | YES | 在庫不足予測日 |
| forecast_order_date | date | YES | 発注予測日（不足日 - lead_time_days） |
| gross_requirement_qty | decimal | YES | 総所要量 |
| net_requirement_qty | decimal | YES | 正味所要量 |
| forecast_order_qty | decimal | YES | 計画発注数量（ロットまとめ後） |
| forecast_delivery_date | date | YES | 予測納期 |
| forecast_stock_qty | decimal | | 予測時点の在庫数量 |
| lot_size_type | nvarchar(10) | | 適用ロット方式 |
| is_converted | bit | YES | 仮発注に変換済みフラグ |
| provisional_order_id | int | FK | 変換先の仮発注ID |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

### 現行DB→新DB対応

| 現行テーブル | 新テーブル |
|---|---|
| m_hinmoku | m_items |
| m_hannyu_basyo | m_delivery_locations |
| m_hannyu_status | m_order_statuses |
| m_nisugata | m_package_types |
| m_shiiresaki_kubun | m_suppliers |
| t_asap_hachu / t_kojyoire_seikyu | t_orders |
| t_nyusyuko | t_receivings / t_dispatches |
| t_daicho | t_stock_ledgers |
| (新規) | m_forecast_sources, m_bom_headers, m_bom_details |
| (新規) | t_consumption_forecasts, t_order_forecasts |

---

## MRP標準ロジック設計

### MRPフロー概要

```
┌─────────────────────────────────────────────────────────┐
│ Step 1: 総所要量計算（Gross Requirements）               │
│   現フェーズ: 手動入力（ManualForecastProvider）          │
│   将来: 生産計画数量 × BOM使用量 × (1+歩留まりロス率)     │
│         （ProductionPlanProvider / BomExplosionProvider） │
├─────────────────────────────────────────────────────────┤
│ Step 2: 正味所要量計算（Net Requirements）               │
│   正味所要量 = 総所要量                                   │
│              - 手持在庫(stock_qty)                        │
│              - 入庫予定(発注済み未受入のorder_qty)          │
│              + 安全在庫(safety_stock_qty)                 │
│   ※ 正味所要量 < 0 の場合は 0（発注不要）                 │
├─────────────────────────────────────────────────────────┤
│ Step 3: ロットまとめ（Lot Sizing）                       │
│   lot_for_lot: 正味所要量をそのまま発注                    │
│   fixed_qty:   fixed_lot_qty単位に切り上げ                │
├─────────────────────────────────────────────────────────┤
│ Step 4: リードタイムオフセット（Lead Time Offsetting）    │
│   発注予定日 = 必要日 - lead_time_days                    │
├─────────────────────────────────────────────────────────┤
│ Step 5: 計画オーダー生成（Planned Order Release）        │
│   → t_order_forecastsに保存                              │
│   → 仮発注(provisional)としてt_ordersに変換可能           │
│   → 承認フロー(REQ-4)に入る                              │
└─────────────────────────────────────────────────────────┘
```

### サービス抽象化（汎用プロバイダ方式）

```
IConsumptionForecastProvider（消化予測プロバイダ）
├── ManualForecastProvider           ← 現フェーズ: 使用者が手動入力
├── ProductionPlanProvider           ← 将来: 生産計画データから算出
└── BomExplosionProvider             ← 将来: 生産計画 × BOM展開で総所要量算出

IRequirementCalculationService（MRP計算エンジン）
  入力: IConsumptionForecastProviderから総所要量を取得
  処理: 正味所要量 → ロットまとめ → リードタイムオフセット
  出力: 計画オーダー（t_order_forecasts）

IOrderService（発注サービス）
  計画オーダー → 仮発注(provisional) → 承認フロー
```

- すべてpublic interface / internal class
- DI登録で切り替え可能
- MRP計算エンジンは消化予測の入力元に依存しない

---

## 要件一覧

### REQ-1: プロジェクト構成（DemoModule準拠）

```
Material/
├── Areas/Material/Pages/
├── DependencyInjection/MaterialModuleExtensions.cs
├── Models/
├── Services/
│   ├── IConsumptionForecastProvider.cs    (public)
│   ├── ManualForecastProvider.cs          (internal)
│   ├── IRequirementCalculationService.cs  (public)
│   ├── RequirementCalculationService.cs   (internal)
│   ├── IOrderService.cs                   (public)
│   ├── OrderService.cs                    (internal)
│   └── ...
├── Material.csproj / Material.sln
```

**受入条件**:
- [ ] Microsoft.NET.Sdk.Razor SDK、net8.0
- [ ] interface=public、実装=internal
- [ ] DI: AddMaterialModule(IServiceCollection, IConfiguration) を実装し、ModuleRegistration.cs 経由で登録
- [ ] 全ページ: [Authorize(Policy = "DbPermissionCheck")]
- [ ] ルーティング: /Material/ 配下
- [ ] モジュール間直接参照禁止

---

### REQ-2: 原材料の手動発注

**現行対応**: kojyoire_seikyu.aspx、frmKobaiHachuToroku

**受入条件**:
- [ ] m_itemsから品目選択、order_qty/delivery_date/supplier_id/delivery_location_id入力
- [ ] 品目選択時にcontent_qty・package_type_name自動表示
- [ ] delivery_date未入力時はdefault_delivery_days（デフォルト14日）適用
- [ ] order_qtyはorder_unit_qty単位で入力
- [ ] order_status_id=「承認待ち」、order_type='manual'
- [ ] バリデーション（qty > 0、納期は未来日）、remarks最大256文字
- [ ] async/await


---

### REQ-3: 所要ロジック（MRP標準フロー）

**現行対応**: frmPreOrder、frmLowLimit

#### REQ-3a: 消化予測入力（総所要量 — Gross Requirements）

**要件**: 使用者が原材料単位で消化予測数量を入力できること。将来はBOM展開・生産計画連携にも対応する汎用構造とする。

**受入条件**:
- [ ] 原材料(item_id)選択、現在在庫(stock_qty)と受払履歴を表示
- [ ] 日別の消化予測数量(forecast_qty)を入力
- [ ] t_consumption_forecastsにsource_id=1(manual)で保存
- [ ] 過去の受払実績（t_stock_ledgers）を参照しながら入力可能
- [ ] 消化予測の修正・削除が可能
- [ ] IConsumptionForecastProvider経由で取得（将来のBOM展開/生産計画連携に備えた抽象化）

#### REQ-3b: MRP計算（正味所要量→ロットまとめ→リードタイムオフセット）

**要件**: MRP標準フローに従い、総所要量から正味所要量を算出し、ロットまとめ・リードタイムオフセットを経て計画オーダーを生成すること。

**MRP計算ロジック**:
```
日別シミュレーション（予測期間中の各日について）:

1. 総所要量[日] = sum(t_consumption_forecasts.forecast_qty) for 当日
   ※ 将来: 生産計画数量 × BOM.usage_qty × (1 + scrap_rate/100)

2. 入庫予定[日] = sum(t_orders.order_qty) where delivery_date=当日 and status=発注済み

3. 予測在庫[日] = 前日在庫 + 入庫予定[日] - 総所要量[日]

4. 正味所要量判定:
   if 予測在庫[日] < safety_stock_qty then
     正味所要量 = safety_stock_qty - 予測在庫[日]
   else
     正味所要量 = 0（発注不要）

5. ロットまとめ:
   if lot_size_type = 'lot_for_lot' then
     計画発注数量 = 正味所要量
   if lot_size_type = 'fixed_qty' then
     計画発注数量 = ceil(正味所要量 / fixed_lot_qty) × fixed_lot_qty

6. リードタイムオフセット:
   発注予定日 = 当日 - lead_time_days

7. 計画オーダー生成:
   → t_order_forecastsに保存
   → 計画オーダーの入庫を在庫推移に反映してシミュレーション継続
```

**受入条件**:
- [ ] 消化予測入力後、MRP計算を実行できる
- [ ] 正味所要量 = 総所要量 - 手持在庫 - 入庫予定 + 安全在庫(safety_stock_qty)
- [ ] ロットまとめはm_items.lot_size_typeに従う（fixed_qty or lot_for_lot）
- [ ] 発注予定日 = 在庫不足日 - lead_time_days
- [ ] 計画オーダーをt_order_forecastsに保存（gross/net/lot後の各数量を記録）
- [ ] 在庫推移を表形式で表示（stock_minimum_qty/safety_stock_qtyラインを明示）
- [ ] IRequirementCalculationServiceは消化予測の入力元に依存しない設計
- [ ] MRP計算ロジックは単体テスト（Unit Test）で検証すること

#### REQ-3c: 最低在庫アラート

**要件**: stock_minimum_qtyに基づき、現在在庫または予測在庫が最低在庫数量以下になった場合にアラートを表示。納期リードタイムとの兼ね合いを視覚的に把握できるようにする。

**受入条件**:
- [ ] 現在在庫 <= stock_minimum_qty の品目をアラート表示
- [ ] シミュレーション結果で将来在庫が最低在庫を割る品目もアラート対象
- [ ] アラート情報: 品目、現在在庫、最低在庫、安全在庫、不足予測日、発注予測日、リードタイム
- [ ] 発注予測日が過去日の場合は「納期に間に合わない可能性」を強調
- [ ] アラートレベル色分け:
  - 赤: 現在在庫が既にstock_minimum_qty以下（即時発注手配）
  - 橙: 発注予測日が本日以前（リードタイム的に間に合わない可能性）
  - 黄: 発注予測日が近日中（3日以内に発注必要）
  - 緑: 当面余裕あり
- [ ] アラートから手動発注(REQ-2)または仮発注生成(REQ-3d)に直接遷移可能

#### REQ-3d: 仮発注生成（計画オーダー→仮発注）

**要件**: MRP計算結果の計画オーダーから仮発注を生成し、承認待ちステータスで登録すること。

**受入条件**:
- [ ] 計画オーダー一覧から仮発注に変換する品目を選択
- [ ] t_ordersにorder_type='provisional'で登録、order_status_id=「承認待ち」
- [ ] delivery_date=forecast_delivery_date、order_qty=forecast_order_qty
- [ ] supplier_id/warehouse_idはm_itemsのデフォルト値
- [ ] t_order_forecasts.is_converted=true、provisional_order_idを更新
- [ ] 同一品目・同一予測日の重複仮発注を防止
- [ ] 仮発注生成後、使用者が内容を確認・修正してから承認フローに回せる

---

### REQ-4: 発注承認フロー

**現行対応**: kojyoire_seikyu_list.aspx、frmKobaiHachuHistory

**受入条件**:
- [ ] ステータス遷移: 承認待ち→承認済み→発注済み
- [ ] manual/auto/provisionalすべて同一承認フロー
- [ ] 承認/却下、チェックボックス一括承認
- [ ] 却下→「却下」ステータス、差し戻し
- [ ] 承認済みのみ発行可能、遷移は不可逆
- [ ] approved_at/approved_by記録、印刷機能

---

### REQ-5: 原材料倉庫への受入

**受入条件**:
- [ ] 「発注済み」のt_ordersに対してのみ受入可能
- [ ] t_receivingsに登録、t_stocks.stock_qty加算
- [ ] 分割受入対応、全数受入→「受入完了」
- [ ] warehouse_id別管理

---

### REQ-6: 原材料倉庫から現場への払い出し

**受入条件**:
- [ ] item_id/dispatch_qty指定、stock_qty >= dispatch_qty検証
- [ ] t_dispatches記録、stock_qty減算、負にならない（不変条件）
- [ ] 検索: 日付範囲、item_code範囲、item_name、supplier_id、warehouse_id
- [ ] 複数段階ソート

---

### REQ-7: 納期監視

**受入条件**:
- [ ] 「発注済み」（未受入完了）をdelivery_date順に表示
- [ ] 納期超過警告、残日数表示、遅延リスク警告
- [ ] 年月絞り込み

---

### REQ-8: UI統一規約（フォントサイズ・タイトル・用語統一）

**User Story:** As a 使用者, I want 全ページで統一されたUI表示を得ること, so that 操作に迷わず効率的に業務を遂行できる。

#### 受入条件

1. THE Material_Module SHALL 全ページのコンテナに `material-page` クラスを適用する
2. THE Material_Module SHALL リスト外のフォントサイズを 0.8rem（container-fluid に設定）で統一する
3. THE Material_Module SHALL リスト内（テーブル）のフォントサイズを 0.75rem で統一する（StockLedgerのみ 0.7rem を例外とする）
4. THE Material_Module SHALL ページタイトルを `<h5 class="mb-2">` で統一する
5. THE Material_Module SHALL ドロップダウン・ボタンのフォントサイズを `_MaterialStyles.cshtml` で `font-size: inherit !important` に設定する
6. THE Material_Module SHALL 全ページ先頭に `<partial name="_MaterialStyles" />` を配置する
7. THE Material_Module SHALL 発注日の表示名称を「起票日」に統一する（Orders/Confirm, Orders/Search, Mrp）
8. THE Material_Module SHALL 「発注単位」の表示名称を「発注個数」に統一する（MasterMaintenance）
9. THE Material_Module SHALL MainWeb側のCSS（site.css）を変更せず、MaterialModule内で完結させる

---

### REQ-9: 操作者トレーサビリティ（各操作の実行者名記録）

**User Story:** As a 管理者, I want 各操作（確定・入庫・搬入完了）の実行者名が記録されること, so that 誰がいつ操作したかを追跡できる。

#### 受入条件

1. WHEN 発注が確定されたとき, THE Orders_Confirm SHALL 確定者ID（confirmed_by）、確定者名（confirmed_by_name）、確定日時（confirmed_at）を t_orders に保存する
2. WHEN 発注確定が取り消されたとき, THE Orders_Confirm SHALL confirmed_by, confirmed_by_name, confirmed_at をクリアする
3. THE Orders_Confirm SHALL 「確定者」列を納期確定リストのみに表示する（回答待ちリストでは非表示）
4. WHEN 入庫が実行されたとき, THE Receivings SHALL 入庫者名（user_name）を t_receivings に保存する
5. THE Receivings SHALL 「入庫者」列を入庫一覧に表示する
6. WHEN 搬入完了が実行されたとき, THE Delivery SHALL 搬入者ID（completed_by）、搬入者名（completed_by_name）を t_dispatches に保存する
7. WHEN 搬入完了が取り消されたとき, THE Delivery SHALL completed_by, completed_by_name をクリアする
8. THE Delivery SHALL 「搬入者」列を搬入一覧に表示する
9. THE Material_Module SHALL 操作者名としてユーザーの LastName を使用する

**DB変更**:
- t_orders: `confirmed_by` (nvarchar(40)), `confirmed_by_name` (nvarchar(40)), `confirmed_at` (datetime) 追加
- t_receivings: `user_name` (nvarchar(40)) 追加
- t_dispatches: `completed_by` (nvarchar(40)), `completed_by_name` (nvarchar(40)) 追加

---

### REQ-10: パフォーマンス要件（N+1解消・必要列のみ取得）

**User Story:** As a 使用者, I want MRPページが高速に表示されること, so that 業務効率が低下しない。

#### 受入条件

1. THE AlertService SHALL N+1クエリを排除し、一括クエリ（最大3回）でアラートデータを取得する
2. THE AlertService SHALL 在庫データソースを t_stock_ledgers に統一する（t_stocks は使用しない）
3. THE AlertService SHALL アラート判定基準を safety_stock_qty に統一し、Green（余裕あり）を除外して返却する
4. THE LoadOrderListAsync SHALL `Include` ではなく `Select` を使用し、必要列のみを取得する
5. THE Material_Module SHALL 一覧取得クエリにおいて、表示に不要なナビゲーションプロパティを読み込まない

---

### REQ-11: 排他制御（楽観的ロック・RowVersion）

**User Story:** As a 使用者, I want 同時編集時にデータが上書きされないこと, so that データの整合性が保たれる。

#### 受入条件

1. THE MasterMaintenance SHALL マスタ保存時に RowVersion による楽観的ロックを適用する
2. THE MasterMaintenance SHALL RowVersion を Base64文字列（string?）としてクライアントに返却し、次回保存時に送信する
3. IF 楽観的ロックの競合が検出されたとき, THEN THE Material_Module SHALL 「他のユーザーが先に更新しました。画面を再読み込みしてください。」とメッセージを表示する
4. THE MasterMaintenance SHALL AJAX保存時に `@Url.Page(...)` による絶対パスURLを使用する
5. THE MasterMaintenance SHALL `[IgnoreAntiforgeryToken]` をクラスレベルに設定し、`@Html.AntiForgeryToken()` をページに配置する
6. WHEN 保存が成功したとき, THE MasterMaintenance SHALL ページ上部に成功メッセージを表示する

---

### REQ-12: MRP発注数量計算方式

**User Story:** As a 使用者, I want MRPの発注数量が正しく計算されること, so that 適切な数量で発注できる。

#### 受入条件

1. THE MRP_Calculator SHALL 発注数量を「安全在庫(safety_stock_qty) - 現在在庫(stock_qty) = 不足分」で計算する
2. THE Material_Module SHALL m_items.default_order_qty を発注数量の初期値として使用しない（NULLとする）
3. THE MRP_Calculator SHALL 計算結果を t_order_forecasts に保存する

---

## コーディング規約

| 項目 | 規約 |
|------|------|
| アーキテクチャ | モジュラモノリス厳守 |
| 非同期処理 | I/Oはすべて async/await |
| 型定義 | var は右辺から型が明らかな場合のみ |
| DB命名 | 命名規則(db).xlsx準拠 |
| テーブル | t_(トランザクション)、m_(マスタ)、r_(中間) |
| カラム | 英語スネークケース |
| 必須カラム | id, created_at, updated_at |
| サービス設計 | interface=public、実装=internal |
| テスト | 複雑なロジック（MRP計算等）は必ずUnit Test |

---

## 正当性プロパティ

### CP-1: 在庫整合性
`∀ item: t_stocks.stock_qty >= 0`

### CP-2: 発注ステータス遷移
`承認待ち → 承認済み → 発注済み → 受入完了` / `承認待ち → 却下`（逆方向不可）

### CP-3: 受入数量整合性
`∀ order: sum(t_receivings.received_qty) <= t_orders.order_qty`

### CP-4: 払い出し数量整合性
`stock_after = stock_before - dispatch_qty`

### CP-5: 仮発注の冪等性
`∀ forecast: is_converted=true → 再変換不可`

### CP-6: 承認必須
`∀ order: order_status_id != "承認済み" → cannot_issue(order)`

### CP-7: デフォルト納期適用
`∀ order: delivery_date未入力 → delivery_date = order_date + default_delivery_days`

### CP-8: MRP正味所要量整合性
`net_requirement = max(0, gross_requirement - on_hand_stock - scheduled_receipts + safety_stock)`

### CP-9: ロットまとめ整合性
`lot_for_lot: planned_qty = net_requirement`
`fixed_qty: planned_qty = ceil(net_requirement / fixed_lot_qty) × fixed_lot_qty`
`∀ case: planned_qty >= net_requirement`

### CP-10: リードタイムオフセット整合性
`∀ forecast: forecast_order_date = shortage_date - lead_time_days`

### CP-11: 最低在庫アラート整合性
`∀ item: stock_qty <= stock_minimum_qty → alert_level ∈ {red, orange, yellow}`

### CP-12: BOM展開整合性（将来）
`∀ bom_detail: gross_requirement = production_qty × usage_qty × (1 + scrap_rate/100)`

### CP-13: 操作者トレーサビリティ整合性
`∀ order where confirmed: confirmed_by IS NOT NULL ∧ confirmed_by_name IS NOT NULL ∧ confirmed_at IS NOT NULL`
`∀ receiving: user_name IS NOT NULL`
`∀ dispatch where completed: completed_by IS NOT NULL ∧ completed_by_name IS NOT NULL`

### CP-14: 楽観的ロック整合性
`∀ master_update: row_version_sent = row_version_current → update_success`
`∀ master_update: row_version_sent ≠ row_version_current → update_rejected`

### CP-15: UI統一性
`∀ page ∈ MaterialModule: has_class("material-page") ∧ has_partial("_MaterialStyles")`
`∀ page ∈ MaterialModule: title_element = <h5 class="mb-2">`

### CP-16: パフォーマンス — クエリ効率
`∀ AlertService.GetAlerts(): query_count <= 3`
`∀ list_query: SELECT only required columns (no Include of navigation properties)`

### CP-17: MRP発注数量整合性
`∀ mrp_order: order_qty = max(0, safety_stock_qty - current_stock_qty)`
