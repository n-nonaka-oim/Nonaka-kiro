# ER図（MaterialModule）

DB: `db_material_dev` / Server: `OJIADM23120073\DEVELOPMENT`

> Mermaid プレビューでエラーになる場合は `ER図.mmd` を直接開いてください。
> VS Code 拡張「Markdown Preview Mermaid Support」または「Mermaid Editor」で描画できます。

---

## マスタ間リレーション

```mermaid
erDiagram
    m_items ||--o| m_package_types : "package_type_id"
    m_items ||--o| m_suppliers : "supplier_id"
    m_items ||--o| m_usage_categories : "usage_1"
    m_purchase_conditions ||--o| m_items : "item_id"
    m_purchase_conditions ||--o| m_purchase_types : "purchase_type"
    m_bom_headers ||--|{ m_bom_details : "bom_header_id"
    m_bom_details ||--o| m_items : "item_id"
```

## 印刷出力パスマスタ（単独マスタ）

印刷出力(PDF)の保存先ベースパスを保持するマスタ `m_print_output_path`（`db_material_dev`）。他テーブルと直接のリレーション（FK）を持たない**単独マスタ**。MaterialModule(書込)が有効行(`is_active=1`)を参照して `pdf_path` を解決する。PrintAgent は参照しない。

```mermaid
erDiagram
    m_print_output_path {
        int id PK
        nvarchar base_path
        nvarchar description
        bit is_active
        rowversion row_version
        datetime2 created_at
        datetime2 updated_at
    }
```

> `m_print_output_path` は保存先ベースパスを保持する単独マスタで、他テーブルとリレーションを持たない（独立）。

## トランザクション リレーション

```mermaid
erDiagram
    t_orders ||--o| m_items : "item_id"
    t_receivings ||--|| t_orders : "order_id"
    t_dispatches ||--o| m_items : "item_id"
    t_order_forecasts ||--o| m_items : "item_id"
    t_order_forecasts ||--o| t_orders : "provisional_order_id"
    t_consumption_forecasts ||--o| m_items : "item_id"
    t_consumption_forecasts ||--o| m_forecast_sources : "source_id"
    t_tank_checks ||--o| m_tanks : "tank_id"
    t_orders ||--o{ t_order_dispatch_log : "reference_code (論理参照: OrderNoグループ)"
```

> `t_order_dispatch_log` は発注承認契機のFAX送信投入履歴（二重送信防止）。`reference_code` は `t_orders.order_no` の発注番号グループ（先頭3セグメント）への論理参照（FK制約なし）。`queue_job_id` は共通DB `db_common_dev` の `t_smtp_queue.id` への論理参照（別DBのためFK制約なし・参照のみ）。配置DBは `db_material_dev`（資材固有）。

---

## 共通DB（db_common_dev）— SMTP送信汎用基盤（smtp-sender）

DB: `db_common_dev` / Server: `OJIADM23120073\DEVELOPMENT`

全社共通のSMTP送信汎用基盤(smtp-sender)が使用する3テーブル。資材固有DBではなく共通DB(`db_common_dev`)に配置する。送信ジョブ(`t_smtp_queue`)は `config_key` で接続プロファイルマスタ(`m_smtp_config`)を参照する。死活監視(`m_smtp_agent_control`)は他テーブルと直接のリレーションを持たない独立テーブル。

```mermaid
erDiagram
    m_smtp_config ||--o{ t_smtp_queue : "config_key"
    m_smtp_agent_control {
        int id PK
    }
```

### リレーション一覧（論理FK制約なし・コード参照）

| 親テーブル | 子テーブル | 参照列 | 関係 | 備考 |
|-----------|-----------|--------|------|------|
| m_smtp_config | t_smtp_queue | config_key | 1:N | 送信ジョブが使用する接続プロファイルを選択（FK制約なし、Worker側で解決） |

> `m_smtp_agent_control` は SmtpAgent(Worker) の死活監視（heartbeat）専用の1行運用テーブルで、他テーブルとリレーションを持たない（独立）。

---

## 共通DB（db_common_dev）— 共通プリント基盤（print-platform）

DB: `db_common_dev` / Server: `OJIADM23120073\DEVELOPMENT`

全社共通のプリント送信汎用基盤(print-platform)が使用する2テーブル。上記 SMTP送信汎用基盤(`t_smtp_queue`/`m_smtp_agent_control`) と**対の共通基盤**として資材固有DBではなく共通DB(`db_common_dev`)に配置する。各業務モジュール(Producer)が共通印刷キュー(`t_print_queue`)へジョブを投入し、Worker(PrintAgent)がポーリングして印刷する。`reference_code` は発注番号等の参照キー（論理参照・FK制約なし）。死活監視(`m_print_agent_control`)は他テーブルと直接のリレーションを持たない独立テーブル。

```mermaid
erDiagram
    t_print_queue {
        int id PK
        nvarchar module
        nvarchar reference_code
    }
    m_print_agent_control {
        int id PK
    }
    m_printer {
        int id PK
        nvarchar machine_name
        nvarchar printer_name
        bit is_default
        bit is_active
        datetime2 last_seen_at
        datetime2 created_at
        datetime2 updated_at
        rowversion row_version
    }
```

### リレーション一覧（論理参照・FK制約なし・コード参照）

| テーブル | 参照先 | 参照列 | 備考 |
|---------|--------|--------|------|
| t_print_queue | （各業務モジュールの発注等） | reference_code | 発注番号等への論理参照（FK制約なし・コード参照）。投入側が生成した pdf_path の PDF を印刷（印刷専用・単一パス） |

> `t_print_queue` は全モジュール横断の共通印刷キュー。`t_smtp_queue`（FAX/メール送信）と対の共通基盤で、FK制約は持たず `reference_code`（発注番号等）で発生元を参照する。FAX関連列は持たない。
> `m_print_agent_control` は PrintAgent(Worker) の死活監視（heartbeat）専用の1行運用テーブルで、他テーブルとリレーションを持たない（独立）。`m_smtp_agent_control` と対。
> `m_printer` はインストール済みプリンタの台帳。PrintAgent が起動時に稼働機のプリンタを列挙し `(machine_name, printer_name)` をキーに upsert する。他テーブルと直接のリレーション（FK）を持たない**単独マスタ**（一意制約 `(machine_name, printer_name)`）。

---

## 共通DB（db_common_dev）— 送信設定マスタ（send-config-master）

DB: `db_common_dev` / Server: `OJIADM23120073\DEVELOPMENT`

送信元アドレスとテスト送信先（テストFAX番号・テストメール）を1行（有効行 `is_active=1`）で一元管理する **単独マスタ** `m_send_config`。他テーブルと直接のリレーション（FK）を持たない。CommonModule の `ISendConfigService` が有効行を読み取り、投入側（`dispatch-monitoring-consolidation`）が From／テスト送信時の recipient 上書きに使用する。spec: `send-config-master`。

```mermaid
erDiagram
    m_send_config {
        int id PK
        nvarchar owner_user_id
        nvarchar from_address
        nvarchar test_fax_number
        nvarchar test_email
        nvarchar attachment_path
        bit is_active
        datetime2 created_at
        datetime2 updated_at
        rowversion row_version
    }
```

> `m_send_config` は送信元・テスト宛先を保持する単独マスタで、他テーブルとリレーションを持たない（独立）。有効行は `is_active=1` を1件採用（1行運用・将来複数化余地）。`row_version` は管理画面編集の楽観的ロック用。

---

## リレーション一覧

### マスタ間

| 親テーブル | 子テーブル | FK列 | 関係 |
|-----------|-----------|------|------|
| m_package_types | m_items | package_type_id | 1:N |
| m_suppliers | m_items | supplier_id | 1:N |
| m_usage_categories | m_items | usage_1 | 1:N |
| m_items | m_purchase_conditions | item_id | 1:N |
| m_purchase_types | m_purchase_conditions | purchase_type | 1:N |
| m_bom_headers | m_bom_details | bom_header_id | 1:N |
| m_items | m_bom_details | item_id | 1:N |

### トランザクション → マスタ

| 親テーブル | 子テーブル | FK列 | 関係 | 備考 |
|-----------|-----------|------|------|------|
| m_items | t_orders | item_id | 1:N | 論理FK（FK制約なし、スナップショット保持） |
| t_orders | t_receivings | order_id | 1:N | |
| m_items | t_dispatches | item_id | 1:N | |
| m_items | t_order_forecasts | item_id | 1:N | |
| t_orders | t_order_forecasts | provisional_order_id | 1:N | 仮発注紐付け |
| m_items | t_consumption_forecasts | item_id | 1:N | |
| m_forecast_sources | t_consumption_forecasts | source_id | 1:N | |
| m_tanks | t_tank_checks | tank_id | 1:N | |

### 論理リレーション（FK制約なし・コード参照）

| テーブル | 参照先 | 参照列 | 備考 |
|---------|--------|--------|------|
| t_orders | m_suppliers | supplier_code | スナップショット保持 |
| t_orders | m_warehouses | warehouse_code | スナップショット保持 |
| t_stocks | m_items | item_id | |
| t_stocks | m_warehouses | warehouse_code | |
| t_stock_ledgers | m_items | item_id | |
| t_stock_ledgers | m_warehouses | warehouse_code | |
| m_tanks | m_items | item_code | コード参照 |
| m_purchase_conditions | m_suppliers | supplier_code | コード参照 |
| t_order_dispatch_log | t_orders | reference_code | 発注番号グループ（OrderNo先頭3セグメント）への論理参照 |
| t_order_dispatch_log | t_smtp_queue | queue_job_id | 共通DB db_common_dev の送信キュージョブID。別DBのためFK制約なし・参照のみ |

---

## テーブル分類

### マスタ（20テーブル）

| テーブル名 | 日本語名 | 主用途 |
|-----------|----------|--------|
| m_items | 品目マスタ | 全画面の中核 |
| m_suppliers | 仕入先マスタ | 発注・購買条件 |
| m_purchase_conditions | 購買条件マスタ | SAP連携。1品目に複数行を許容（重複可）。**参照時はitem_code単位でeffective_date最新を採用** |
| m_warehouses | 倉庫マスタ | 在庫管理 |
| m_tanks | タンクマスタ | タンク残量チェック |
| m_delivery_locations | 搬入先マスタ | 出庫先指定 |
| m_calendar | カレンダーマスタ | 営業日計算 |
| m_bom_headers | BOMヘッダ | 所要計算（将来） |
| m_bom_details | BOM明細 | 所要計算（将来） |
| m_package_types | 荷姿マスタ | 品目属性 |
| m_purchase_types | 購買区分マスタ | 発注分類 |
| m_order_statuses | 発注ステータスマスタ | ステータス管理 |
| m_forecast_sources | 予測ソースマスタ | 消費予測の出処 |
| m_usage_categories | 用途区分マスタ | 品目分類 |
| m_usage2_categories | 用途2区分マスタ | 品目分類 |
| m_usage3_categories | 用途3区分マスタ | 品目分類 |
| m_company_info | 自社情報マスタ | 帳票ヘッダ |
| m_report_notes | 帳票備考マスタ | 帳票フッター |
| m_user_preferences | ユーザー設定 | 画面設定保存 |
| m_print_output_path | 印刷出力パスマスタ | 印刷出力(PDF)保存先ベースパス保持（独立・リレーションなし） |

> 注: 旧 db_material_dev の `m_print_agent_control`／`m_smtp_config`／`m_smtp_agent_control`（共通基盤移行に伴う孤立コピー）は 2026/07/03 に DROP 済み。現行の同名テーブルは db_common_dev（共通基盤）側のみ（下記「共通DB」節）。

### トランザクション（10テーブル）

| テーブル名 | 日本語名 | 主用途 |
|-----------|----------|--------|
| t_orders | 発注 | 発注ワークフロー |
| t_receivings | 入庫 | 入庫実績 |
| t_dispatches | 出庫 | 出庫依頼・実績 |
| t_stocks | 在庫 | 現在庫サマリ |
| t_stock_ledgers | 受払台帳 | 日次在庫推移 |
| t_order_forecasts | 発注予測 | MRP計算結果 |
| t_consumption_forecasts | 消費予測 | 使用量予測 |
| t_tank_checks | タンクチェック | 日次残量記録 |
| t_order_reports | 帳票管理 | 印刷/FAX状況 |
| t_order_dispatch_log | 送信投入履歴 | 発注承認FAX送信の投入実績（二重送信防止） |

---

## 共通DB（db_common_dev）テーブル分類 — SMTP送信汎用基盤

| テーブル名 | 日本語名 | 区分 | 主用途 |
|-----------|----------|------|--------|
| t_smtp_queue | 共通送信キュー | トランザクション | 全モジュール横断のSMTP送信ジョブ。1レコード=1送信ジョブ |
| m_smtp_config | 接続プロファイルマスタ（複数行） | マスタ | SMTP接続先設定。config_key で t_smtp_queue から参照 |
| m_smtp_agent_control | SmtpAgent死活監視 | マスタ | 送信Worker生存状態(heartbeat)表示（独立・リレーションなし） |

## 共通DB（db_common_dev）テーブル分類 — 共通プリント基盤

| テーブル名 | 日本語名 | 区分 | 主用途 |
|-----------|----------|------|--------|
| t_print_queue | 共通印刷キュー | トランザクション | 全モジュール横断の印刷ジョブ。1レコード=1印刷ジョブ。FAX列なし。`t_smtp_queue` と対 |
| m_print_agent_control | PrintAgent死活監視 | マスタ | 印刷Worker生存状態(heartbeat)表示（独立・リレーションなし）。`m_smtp_agent_control` と対 |
| m_printer | プリンタマスタ | マスタ | インストール済みプリンタ台帳。PrintAgent が起動時に列挙し upsert（独立・リレーションなし。一意 (machine_name, printer_name)） |

## 共通DB（db_common_dev）テーブル分類 — 送信設定マスタ

| テーブル名 | 日本語名 | 区分 | 主用途 |
|-----------|----------|------|--------|
| m_send_config | 送信設定マスタ | マスタ | 送信元アドレス・テスト送信先(FAX/メール)を1行で一元管理（独立・リレーションなし）。ISendConfigService が参照、投入側が From/recipient 上書きに使用 |
