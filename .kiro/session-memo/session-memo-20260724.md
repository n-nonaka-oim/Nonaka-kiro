# セッション備忘録（2026/07/24）

前日（20260723）＝clnCoCore 最新取り込み（push厳禁で保留）・DemoModule push・予実 過去データ移行の設計確定＋カバレッジ実測。本日は過去データ移行を実装・実行。

## 計画マスタ 過去データ移行：実装・実行 完了

### 実施内容
移行元 NT182028\dbNsShizai.`m_hinmoku_tanka`（年度×上期/下期×品目×単価・2016〜2026）→ db_material_dev.`t_material_plans`。

1. **対応表テーブル新設** `m_item_code_map`（db_material_dev）:
   - `MaterialModule/docs/sql/create_m_item_code_map.sql`（冪等 CREATE・一意 uq_m_item_code_map_01(sap_id)）。
   - 列: id/sap_id(=item_code)/kanzaki_code(旧神崎)/item_id(m_items.id・物理FKなし・未解決NULL)/created_at/updated_at/row_version。
   - Kiro が sqlcmd で db_material_dev に適用（DDL）。
2. **対応表投入**（Kiro・sqlcmd クロスサーバ）:
   - dbNsShizai から sap_id 単位に kanzaki_code を抽出（GROUP BY sap_id・MAX(kanzaki)）→ m_item_code_map へ INSERT（TRUNCATE で冪等）→ 同一DB内 UPDATE で m_items.item_code=sap_id 突合し item_id 解決。
   - 結果：total 1,265 ／ item_id 解決 637 ／ 未解決 628。
3. **t_material_plans へ移行**（Kiro・sqlcmd）:
   - m_hinmoku_tanka 全行(24,660) 抽出 → item_id 解決品目のみ → 6ヶ月展開:
     - nendo_kubun=0(上期) → plan_version=annual・year_month=当年4〜9月
     - nendo_kubun=1(下期) → plan_version=revised_h2・year_month=当年10〜翌年3月
     - planned_unit_price=tanka／planned_qty=0／planned_amount=0／fiscal_year=nendo。
   - 冪等化：投入前に `DELETE ... WHERE plan_version IN ('annual','revised_h2') AND fiscal_year BETWEEN 2016 AND 2026`。
   - 結果：**投入 68,856行**（未解決 13,184ソース行スキップ）／品目637／年度2016〜2026／annual 34,272・revised_h2 34,584。検算一致（11,476解決ソース行×6）。
4. **docs 更新**：テーブル定義書.md／ER図.md に `m_item_code_map` 追記（t_material_plans は7/22追記済）。

### 状態・確認
- **ビルド確認OK**（ユーザー）。移行データは db_material_dev に投入済（68,856行）。
- 画面（PlanMaster）での過去単価表示（年度選択→annual=上期単価4-9/revised_h2=下期単価10-3・推移把握）は次回さらに確認可。
- 数量は移行対象外（0・今後入力 or 後続Phase実績連携）。

### コミット対象（本日）
- MaterialModule：`docs/sql/create_m_item_code_map.sql`（新規）。※移行データ自体はDB内容でgit管理外。
- Nonaka-kiro：`.kiro/docs/db/テーブル定義書.md`・`ER図.md`（m_item_code_map 追記）＋本 session-memo。

### 未実装案件（保留・再掲）
- 予実 後続 Phase：Phase2 実績集計（t_stock_ledgers・預託=出庫/在庫=入庫）→ Phase3 実績3ヶ月平均で計画初期投入＋当月実績単価 → Phase4 予実分析（単価差×見込数量＝影響額＋数量差×単価。現行 dbNsShizai.t_hinmoku_eikyo が実装参考元）。
- 計画数量の入力/移行（今回単価のみ移行）。
- MRP任意テスト／発注点自動計算／接続文字列平文パスワードのセキュア化（本番移行）。
- clnCoCore ahead 40（push厳禁で保留・publish_f 誤コミット混入の整理は将来）。

### 再開合図
「再開します、session-memoを確認」。最新は 20260724。予実 過去データ移行 **完了**（t_material_plans 68,856行・2016-2026・annual/revised_h2）。次＝画面での推移確認 or 後続Phase（実績集計）or 計画数量入力。
