# セッション備忘録（2026/07/01 - session-memo分割整理／steering追記／共通プリント基盤を別spec化 common-print-platform 要件作成・dispatch-monitoring-consolidation を依存に再整理）

## 冒頭の整理作業
- **session-memo分割**: 6/29 ファイルに混在していた 6/30 分（「MainWeb混入変更の把握→撤去」以降）を `session-memo-20260630.md` に切り出し。6/29 は smtp-sender完了〜order-approval-fax-mail 完了まで。
- **steering 修正**: `project-rules.md` 冒頭フロントマターの壊れ行 `sa---` を除去（`inclusion: always` の正常形へ）。
- **steering 追記**: 「**大きな作業の進め方（最小単位・記録・確実実行）**」セクションを追加。spec分割／フェーズ分割／タスク最小化／記録徹底／依存・順序明示／リスク逓減を明文化。

## 監視基盤の責務分割（確定）
PrintAgent（ワーカー）＋ PrintAgent監視WEB は他モジュールから独立した「共通プリント基盤」と整理。SMTP側（SmtpAgent＋t_smtp_queue＋Common_SmtpMonitor）と対の構成。

### 新spec `common-print-platform`（契約の発生元・所有者）— 要件作成完了
- 所有: **`t_print_queue`（db_common_dev）スキーマ契約**（t_smtp_queueと対・印刷列のみ・FAX列なし・row_version）／**PrintAgent の読取先変更**（t_order_reports→t_print_queue・別ソリューション）／**Common_PrintMonitor（`/Common/PrintMonitor`）新設**／**m_print_agent_control（死活）**／**カットオーバー（DDL→移行→投入先切替→読取先切替）**。
- requirements R1〜R13。2箇所配置・診断クリア。
  - 正本 `.kiro/specs/common-print-platform/` ＋ コピー `MaterialModule/Doc/specs/common-print-platform/`。

### `dispatch-monitoring-consolidation`（MaterialModule関心・依存側）— 要件を依存に再整理
- 所有: **二重FAX根絶**（PrintJobService は fax_status を作らない）／**PrintJobService の投入先を t_print_queue へ（投入側実装）**／**旧 Material_SmtpMonitor 廃止**／**旧 Material_PrintMonitor 廃止・導線を /Common/PrintMonitor へ更新**。
- 委譲（依存）: t_print_queueスキーマ・PrintAgent読取先・Common_PrintMonitor新設・カットオーバー定義は **common-print-platform 所有**。重複受入基準は保持しない。
- requirements Req1〜Req7。2箇所配置・診断クリア。

## 次アクション（最小単位で進める）
1. **common-print-platform の Design**（契約発生元を先に固める）: t_print_queue スキーマ（列・型・制約・DDL粒度）／m_print_agent_control／Common_PrintMonitor 設計／カットオーバー手順。
2. その後 **dispatch-monitoring-consolidation の Design**（PrintJobService 投入経路＝CommonModule投入サービス経由 or 直接／FAX一本化＝fax_status=0／旧Monitor廃止・導線更新）。
3. 各 Design 合意 → Tasks（最小単位）→ 実装。各段階で記録。

## 申し送り（横断）
- MainWeb・AuthModule 不変更。Spec 2箇所配置。基幹システム構築基準 `.md` 準拠。最小単位で進め記録（steering明文化済み）。
- 既出の訂正要望（6/30記録）: Smtpエラーメール送信者通知 / m_smtp_config キー命名 test→mail・fax / 発注書兼納入仕様書 ゴシック+0.5pt / 同帳票に仕入先コード表示。
- 次案件候補: `smtp-agent-test-mode`（Agent側テスト送信DBマスタ化）。
- 完了済み: order-approval-fax-mail（実FAX着信OK・36/36）。
- 再開は「再開します、session-memoを確認」。

---

## common-print-platform: 要件分析(A)完了 → 設計(Design)完了

### 分析(A)で判明した重要点
- 現 `t_order_reports`(PrintAgent TOrderReport) は **row_version 無し** → PrintJobWorker の `DbUpdateConcurrencyException` catch が**実効していない隠れ排他バグ**。t_print_queue に row_version 追加で実効化。
- 完了列が `completed_at` と `print_at` の2本で冗長 → `printed_at` 1本化。
- PrintAgent 接続は appsettings `CloudDb=db_material_dev` → db_common_dev へ変更のみ（Workerロジック不変）。
- m_print_agent_control は現 db_material_dev → db_common_dev へ移設。

### 承認済み決定 D1〜D5（ユーザー）
- D1 t_print_queue 列確定（fax列なし・printed_at一本化・row_version）。
- D2 CommonModule に `IPrintQueueService`/`PrintQueueService` 新設（ISmtpQueueServiceと対）。
- D3 m_print_agent_control を db_common_dev へ＋CommonModule entity。
- D4 PrintAgent: エンティティ→t_print_queue・接続db_common_dev・Worker不変・row_version追加。
- D5 カットオーバー: DDL→移行→投入先切替→読取先切替。

### Design 成果物（2箇所・診断クリア）
- `.kiro/specs/common-print-platform/design.md` ＋ コピー。
- 章: 概要/アーキ(SMTP対比表+Mermaid)/Components(CommonModule・PrintAgent)/Data Models(t_print_queue・m_print_agent_control 列定義表)/Correctness Properties 1〜6/Error Handling/Testing/カットオーバー(順序図+ロールバック)/排他制御/責務分界。

### 要確認(軽微)
- エラー列名: requirements=`print_error_message` / design=`error_message`（t_smtp_queue・現PrintAgentとパリティ）。→ **error_message に統一**推奨（requirements追随更新）。

### 次アクション
1. common-print-platform の **Tasks 生成**（最小単位）。
2. 実装（CommonModule→PrintAgent→カットオーバー）。DDL/ビルド/テスト/実印刷はユーザー側。
3. その後 dispatch-monitoring-consolidation の Design→Tasks→実装（投入先切替・FAX一本化・旧Monitor廃止）。

---

## common-print-platform Design 完了（方針A・Bスキーマ+デュアルモード反映）

### 決定（D1〜D6）
- D1: t_print_queue（db_common_dev・16列）= id/module(NOT NULL)/report_type/reference_code/output_type/print_status/print_payload/pdf_path/printer_name/copies/picked_at/printed_at/error_message/created_at/updated_at/row_version。fax_status無し。index: (print_status,created_at)/reference_code/module。
- D2: CommonModule に IPrintQueueService/PrintQueueService 新設（ISmtpQueueServiceと対・Scoped・直接書込は本サービス経由限定）。
- D3: m_print_agent_control を db_common_dev へ集約（CommonDbContext に TPrintQueue/MPrintAgentControl 追加）。
- D4: PrintAgent（別sln）接続を db_common_dev、entity を t_print_queue へ差替（fax_status削除/row_version追加/pdf_path追加/printed_at一本化）。PdfGenerator/SilentPrint/Documents 不変。
- D5: カットオーバー DDL→移行→投入先切替→読取先切替（可逆・取り残しゼロ照合）。
- D6: デュアルモード（pdf_path優先で直接印刷／無ければpayload生成）。将来payload方式を段階廃止。

### Correctness Properties
- P1〜P8=PBT（100回反復・CommonModule.Tests）、P9=並行統合（row_version二重取得防止）。

### 設計内メモ（要追随）
- error列 物理名は `error_message`（requirements表記 print_error_message と差異→requirements追随更新推奨）。
- m_print_agent_control は 1行運用・単一Writer のため row_version 非付与（m_smtp_agent_control とパリティ・例外として明記）。

### 成果物
- `.kiro/specs/common-print-platform/design.md` ＋ コピー `MaterialModule/Doc/specs/common-print-platform/design.md`（byte一致・診断クリア）。

### 次アクション（最小単位）
1. （任意）requirements の error_message 追随更新。
2. **common-print-platform の Tasks 生成**（design内「実装の最小単位14」をタスク化）。
3. Tasks を1つずつ実装（CommonModule側 1〜8 → PrintAgent側 9〜12 → テスト13 → カットオーバー14）。各完了で記録・ユーザー確認。
- その後 dispatch-monitoring-consolidation（Design→Tasks→実装）。

---

## チェックポイント（common-print-platform Design 完了 / IDEエラーRestart対応）

### 直近完了（最小単位）
- **common-print-platform の design.md 作成完了**（正本 `.kiro/specs/common-print-platform/design.md` ＋ コピー `MaterialModule/Doc/specs/common-print-platform/design.md`・byte一致・診断クリア）。
- 内容: t_print_queue（16列・module必須・pdf_path・row_version・fax無し・index 3種）／m_print_agent_control（db_common_dev集約）／IPrintQueueService・PrintQueueService（ISmtpQueueServiceと対）／Common_PrintMonitor（/Common/PrintMonitor）／PrintAgentデュアルモード（pdf_path優先→無ければpayload生成）／カットオーバー（DDL→移行→投入先切替→読取先切替・ロールバック）／Correctness Property 1〜9／実装最小単位14項目（tasks指針）。

### design内の要確認事項（次セッションで確認）
1. error列 物理名: requirementsは `print_error_message` 表記だが design は `error_message`（t_smtp_queue/現PrintAgentとのパリティ）。requirements追随更新を推奨。
2. m_print_agent_control は row_version 非付与（1行運用・単一Writer・MSmtpAgentControlとパリティ＝ルールの明示的例外）。

### 次アクション
1. common-print-platform の design レビュー（上記1・2の確認）→ 必要ならrequirements微修正。
2. **Tasks フェーズ**（design「実装最小単位14項目」を最小タスクに分解）。
3. 実装は最小単位で1つずつ（CommonModule entity→DbSet→IPrintQueueService→PrintQueueService/DI→Common_PrintMonitor→DDL/Doc→PrintAgent差替え→テスト→カットオーバー）。各完了で記録＆ユーザー確認。

### 備考
- 「i.map is not a function」はKiro(IDE)側のUIエラー。コード/spec無関係。Restart可。
- 依存: dispatch-monitoring-consolidation（PrintJobService投入先変更・旧Monitor廃止）は common-print-platform 契約に依存。common側を先に固める。
- 再開合図「再開します、session-memoを確認」。本ファイル(20260701)が最新。

---

## チェックポイント（common-print-platform Tasks 生成完了）

### 本セッション完了（最小単位）
- **design 持ち越し2点をユーザー承認**:
  1. エラー列 物理名を `error_message` に統一 → requirements の `print_error_message` 表記を追随更新（R1.2・R1.5相当・R9.1 の3箇所）。正本＋コピー2箇所反映済み。
  2. `m_print_agent_control` は row_version 非付与（1行運用・単一Writer・m_smtp_agent_control とパリティ＝ルールの明示的例外）を確認。
- **common-print-platform の tasks.md 作成完了**（正本 `.kiro/specs/common-print-platform/tasks.md` ＋ コピー `MaterialModule/Doc/specs/common-print-platform/tasks.md`・診断クリア）。
  - 構成: 1.DDL＋Doc / 2.CommonModule エンティティ・DbContext / 3.IPrintQueueService＋DI / 4.Common_PrintMonitor(一覧・フィルタ・サマリ・死活・再出力・ビュー) / 5.CP / 6.PrintAgent エンティティ・DbContext・接続先 / 7.Worker デュアルモード・状態遷移・row_version・統合 / 8.CP / 9.カットオーバー移行SQL＋Spec同期 / 10.最終CP。
  - Property 1〜8=PBT(CommonModule.Tests・100回)、Property 9=並行統合。`*` 付きはテスト（省略可）。Wave 依存グラフ添付（wave 0〜9）。
  - ビルド・テスト・DDL・実印刷・PrintAgent 再デプロイはユーザー側。MainWeb/AuthModule 不変更。

### 次アクション（最小単位・1つずつ）
1. tasks レビュー（ユーザー確認）→ OK なら実装フェーズ着手。
2. 実装順（Wave）: 1.1(DDL) → 1.2/2.1/2.2 → 2.3 → 3.1/4.1/4.4 → テスト群・3.4・4.6 → 4.7/4.8 → 6.1〜6.3 → 7.1/7.4 → 7.2/7.3/7.5 → 9.1/9.2。各完了で記録＆ユーザー確認。
3. その後 dispatch-monitoring-consolidation（Design→Tasks→実装：投入先切替・FAX一本化・旧Monitor廃止・導線更新）。

### 備考
- common-print-platform は requirements ✅ / design ✅ / tasks ✅（3フェーズ揃い・実装未着手）。
- 再開合図「再開します、session-memoを確認」。本ファイル(20260701)が最新。

---

## チェックポイント（ドキュメント整理 段階1 完了：session-memo 集約）

### 方針決定（ユーザー確定）
- **基本＝プロジェクトモジュール単位**でドキュメント管理（各リポジトリ内 Doc で完結）。
- **session-memo（進捗ログ）＝ワークスペース共通**。steering/specs と同じ `.kiro/` 配下に集約 → **`.kiro/session-memo/`**。

### 本段階の完了作業（最小単位）
- `MaterialModule/Doc/session-memo-*.md`（46本）を **`.kiro/session-memo/` へ一括移動**（Doc側 0本・移動先 46本を確認）。
- `.kiro/session-memo/README.md` 新設（用途・運用記載）。
- パス参照を更新:
  - `.kiro/steering/project-rules.md`（セッション開始/終了の保管先を `.kiro/session-memo/...` へ）。
  - `MaterialModule/Doc/specs/README.md`（開始時参照）。
  - `clnCoCore/.kiro/steering/material-module.md`（引継ぎ・参照ドキュメント・フォルダ構成図）。
- 旧パス `MaterialModule/Doc/session-memo` の残存参照なし（ログ本体除く）を grep 確認。

### 次アクション（ドキュメント整理の続き・各段階でユーザー確認）
- 段階2: 横断設計文書（`concurrency-control-design.md`/`common-db-design.md`）と `テーブル定義書.md`/`ER図.*` の配置決定＋移動＋steeringパス更新（テーブル定義書/ER図は横断1本 or DB分割を要確定）。
- 段階3: `CommonModule/Doc/` 新設 → 横断spec（common-print-platform/smtp-sender）コピー・smtp手順を移設。spec 2箇所配置ルールを「コピー先＝所有モジュール」へ改定。
- 段階4: PrintAgent/SmtpAgent 文書を各リポジトリ Doc へ越境移動（各2コミット）。
- 段階5: MaterialModule/Doc に資材固有のみ残す整理＋各 README 索引更新。

### 備考
- common-print-platform は requirements/design/tasks 揃い（実装未着手）。ドキュメント整理が一段落したら実装フェーズ（Wave0: DDL 1.1）へ。
- 再開合図「再開します、session-memoを確認」。最新は `.kiro/session-memo/session-memo-20260701.md`。

---

## チェックポイント（ドキュメント整理 段階2 完了：横断DB参照・横断設計の集約）

### 完了作業（最小単位）
- テーブル定義書/ER図の扱いは **①横断1本** で確定。
- 移動（`MaterialModule/Doc/` → 集約先）:
  - `テーブル定義書.md`・`ER図.md`・`ER図.mmd`・`ER図.drawio`・`common-db-design.md` → **`Doc/02_db/`**
  - `concurrency-control-design.md` → **`Doc/`**（横断設計）
- `テーブル定義書.md` 見出しを「横断・全DB」に更新（db_material_dev＋db_common_dev、移設注記）。
- steering `project-rules.md` 更新:
  - DBスキーマ変更時の必須作業パスを `Doc/02_db/テーブル定義書.md`・`Doc/02_db/ER図.md` へ。
  - 新節「**ドキュメント配置ルール（モジュール単位管理）**」を追記（session-memo=.kiro/session-memo、横断DB=Doc/02_db、横断設計=Doc、モジュール固有=各Doc、spec正本=.kiro/specs・コピー=所有モジュールDoc）。
  - 「Spec管理ルール」をコピー先＝所有モジュール（資材→MaterialModule/Doc、共通→CommonModule/Doc）へ改定。
- 現在作業 spec（common-print-platform）の tasks.md・design.md（2箇所）のテーブル定義書/ER図パスを `Doc/02_db/...` へ更新。診断クリア。
- `Doc/README.md` を横断ハブ索引に刷新。

### 未処理・留意
- `Doc/02_db/` に旧スケルトン `db_schema.md`/`db_migration.md`/`db_optimization.md` が残存（テーブル定義書.md と役割重複）。整理は段階5で判断。
- 履歴（session-memo 過去分・完了済み spec: smtp-sender/order-approval-fax-mail 等）の旧パス表記は点在するがそのまま（点在履歴のため未追随）。

### 次アクション
- 段階3: `CommonModule/Doc/` 新設 → 横断spec（common-print-platform/smtp-sender）コピーを CommonModule/Doc/specs へ移設、`smtp-sender実送信テスト手順.md` を CommonModule/Doc へ。spec 2箇所ルール（改定済み）に沿ってコピーを再配置。
- 段階4: PrintAgent/SmtpAgent 文書を各リポジトリ Doc へ越境移動。
- 段階5: MaterialModule/Doc に資材固有のみ残す整理＋旧スケルトン整理＋各 README 索引更新。

---

## チェックポイント（Nonaka/Doc の位置づけ確定＋旧スケルトン退避）

### 判明した実態
- `Nonaka/Doc` は 2026/01〜04 作成の**旧 MaterialModule ドキュメントスケルトン**（その後 `MaterialModule/Doc` が実運用ハブ化し放置・陳腐化）。段階2で横断DBドキュメントを移した結果、新旧が混在していた。

### 決定・完了作業
- **`Nonaka/Doc` = ワークスペース横断ドキュメントハブに確定**（複数DB・複数モジュール横断専用。モジュール固有は各モジュール Doc）。
- 旧スケルトンを **`Doc/_archive/` へ退避（可逆）**:
  - `01_spec/`・`03_flow/`・`04_changelog/`・`05_reference/`・`sql/`（旧資材DB移行スクリプト）
  - `02_db/db_schema.md`・`db_migration.md`・`db_optimization.md` → `_archive/02_db_old/`
  - `SESSION_LOG.md`
- 残置（横断ハブ本体）: `02_db/`（テーブル定義書.md・ER図.*・common-db-design.md）／`concurrency-control-design.md`／`README.md`。
- `Doc/README.md` を最終構成（_archive 追記）に更新。

### 最終レイアウト（現時点）
- `.kiro/session-memo/` … 進捗ログ（46本＋README）
- `.kiro/specs/` … spec 正本（不変）
- `Doc/` … 横断ハブ（02_db・concurrency-control-design・_archive）
- `MaterialModule/Doc/` … 資材固有（session-memo/テーブル定義書/ER図/横断設計を除去済み・以降 段階5で資材固有のみに整理）

### 次アクション
- 段階3: `CommonModule/Doc/` 新設 → common-print-platform/smtp-sender の spec コピー・smtp手順を移設。
- 段階4: PrintAgent/SmtpAgent 文書を各リポジトリ Doc へ越境移動。
- 段階5: MaterialModule/Doc に資材固有のみ残す整理＋各 README 索引更新。

---

## チェックポイント（横断ハブを .kiro/docs へ集約＋db リネーム）

### 決定・完了作業
- `02_db` の連番命名（旧スケルトン名残）を廃し **`db`** にリネーム。
- **`Nonaka/Doc/` → `.kiro/docs/` へ移動**（ワークスペース共通の管理物を `.kiro/` に統一: steering/specs/session-memo/docs）。
- 最終レイアウト:
  - `.kiro/docs/README.md`（新配置に更新）
  - `.kiro/docs/concurrency-control-design.md`
  - `.kiro/docs/db/`（テーブル定義書.md・ER図.*・common-db-design.md）
  - `.kiro/docs/_archive/`（旧スケルトン・可逆）
- 参照更新（`Doc/02_db/...` → `.kiro/docs/db/...`）:
  - steering `project-rules.md`（配置ルール節・DBスキーマ変更必須作業）
  - common-print-platform tasks.md/design.md（2箇所）
  - `.kiro/docs/db/テーブル定義書.md` 見出し注記
- grep で `Doc/02_db` 残存なし・spec 診断クリアを確認。

### 現在の確定レイアウト（全体）
- `.kiro/steering/` … ルール
- `.kiro/specs/` … spec 正本（不変）
- `.kiro/session-memo/` … 進捗ログ
- `.kiro/docs/` … 横断ドキュメント（db・concurrency・_archive）
- `<module>/Doc/` … モジュール固有（MaterialModule/CommonModule(新設予定)/PrintAgent/SmtpAgent）

### 次アクション
- 段階3: `CommonModule/Doc/` 新設 → common-print-platform/smtp-sender の spec コピー・smtp手順を移設。
- 段階4: PrintAgent/SmtpAgent 文書を各リポジトリ Doc へ越境移動。
- 段階5: MaterialModule/Doc に資材固有のみ残す整理＋各 README 索引更新。

---

## チェックポイント（ドキュメント整理 段階3 完了：共通基盤specをCommonModule/Docへ）

### 完了作業
- `CommonModule/Doc/`（＋`specs/`）新設。
- 移設（MaterialModule/Doc → CommonModule/Doc・越境=別リポジトリ）:
  - `specs/common-print-platform/` → `CommonModule/Doc/specs/common-print-platform/`
  - `specs/smtp-sender/` → `CommonModule/Doc/specs/smtp-sender/`
  - `smtp-sender実送信テスト手順.md` → `CommonModule/Doc/`
- MaterialModule/Doc/specs から共通基盤2件が消え、資材固有specのみ残存を確認（dispatch-monitoring-consolidation は資材関心のため残置）。
- 参照更新（common-print-platform：正本＋コピーの3ファイル×2）: 自コピー先を `MaterialModule/Doc/specs/...` → `CommonModule/Doc/specs/...`（requirements 配置条項・tasks Notes/9.2・design 2箇所）。診断クリア。
- 新設 README: `CommonModule/Doc/README.md`・`CommonModule/Doc/specs/README.md`。`MaterialModule/Doc/specs/README.md` に所有分離の注記追加。
- smtp-sender（完了済み）の自コピー先パス記述は**履歴として残置**（完了タスクの記録のため未追随）。

### 次アクション
- 段階4: PrintAgent/SmtpAgent 文書を各リポジトリ Doc へ越境移動。
  - MaterialModule/Doc の PrintAgent 関連（`PrintAgent_Source/`・`ダイレクト印刷設計.md`・`Web側実装案_ダイレクト印刷.md`・`Worker実装案_QuestPDF_Sumatra.md`・`Worker疎通テスト手順.md`）→ `PrintAgent/Doc/`。
- 段階5: MaterialModule/Doc に資材固有のみ残す最終整理＋各 README 索引更新。

---

## チェックポイント（ドキュメント整理 段階4 完了：PrintAgent文書を越境移設）

### 完了作業
- MaterialModule/Doc の PrintAgent 関連を `PrintAgent/Doc/`（別リポジトリ）へ移設:
  - `ダイレクト印刷設計.md`・`Web側実装案_ダイレクト印刷.md`・`Worker実装案_QuestPDF_Sumatra.md`・`Worker疎通テスト手順.md` → `PrintAgent/Doc/direct-print/`
  - `PrintAgent_Source/`（ソーススナップショット・参照用）→ `PrintAgent/Doc/PrintAgent_Source/`
- 生きた参照1件（`PrintAgent/Doc/spec.md` の疎通テスト手順）を `direct-print/Worker疎通テスト手順.md` へ更新。
- SmtpAgent 固有文書は MaterialModule/Doc に残存なし（smtp手順は段階3でCommonModuleへ、SmtpAgent/Doc は既存）。
- MaterialModule/Doc に PrintAgent 関連の残存なしを確認。

### MaterialModule/Doc の残存（段階5で整理判断）
- 資材固有（残す）: `specs/`（資材のみ）・`sql/`・`order-status-flow.md`・`order-table-merge-design.md`・`purchase-condition-design.md`・`page-routing-investigation.md`・`db-migration-mapping.md`・`create-page-test-checklist.md`・`development-log.md`・`発注点計算方法.md`・各 xlsx/csv/pdf/png・`manual/`
- 要判断: `未実装案件一覧.md`（全案件一元管理＝横断バックログ→ `.kiro/docs` 候補）／`kiro-signin-logs/`・`maintenance-kiro-signin-20260623.md`（Kiro保守ログ→ `.kiro` or archive）／`_tmp_xlsx_result.txt`・`Thumbs.db`（一時ファイル→削除候補）／検証用 xlsx（`excel_*`・`購買条件.xlsx` 等の要否）

### 次アクション
- 段階5: 上記「要判断」分の扱い決定＋MaterialModule/Doc の索引 README 整備（資材固有のみに最終整理）。

---

## チェックポイント（ドキュメント整理 段階5 完了：sql分割・specs検証・横断バックログ移設）

### sql/ の分割（ユーザー指摘で実施）
- 共通DB系 **8本を `CommonModule/Doc/sql/` へ移動**: create_t_smtp_queue / alter_t_smtp_queue_cc_bcc / create_m_smtp_config / insert_m_smtp_config / create_m_smtp_agent_control / create_smtp_agent / test_smtp_send / create_print_agent_control。
- 資材DB系は MaterialModule/Doc/sql に残置（order/tank/purchase/usage/calendar/safety_stock 等）。
- `register_print_monitor_content.sql`・`register_smtp_monitor_content.sql` は **認証DB(dbAuthTest)への /Material ページ権限登録**＝資材ページ固有のため残置。
- common-print-platform spec（正本＋コピー）の DDL 出力先を `MaterialModule/Doc/sql/` → `CommonModule/Doc/sql/` に更新（前提ルール・1.1・9.1）。
- CommonModule/Doc/README に sql/ を追記。

### specs/ 検証
- 全17件を確認し**すべて資材固有**（dispatch-monitoring-consolidation・print-monitor-page 含む）→ MaterialModule/Doc/specs 残置で正（移動不要）。

### 横断バックログ
- `未実装案件一覧.md`（全案件一元管理）→ `.kiro/docs/` へ移動。README に追記。生きた参照なし。

### 現状維持（ユーザー選択）
- `kiro-signin-logs/`・`maintenance-kiro-signin-20260623.md`（Kiro保守ログ）→ 現状維持。
- `_tmp_xlsx_result.txt`・`Thumbs.db`（一時/OSゴミ）→ 現状維持。
- 検証用 `excel_suppliers.xlsx`・`excel_purchase_conditions.xlsx` → 現状維持。

### ドキュメント整理 全体完了サマリ
- `.kiro/session-memo/` … 進捗ログ（46本＋README）
- `.kiro/specs/` … spec 正本（不変）
- `.kiro/docs/` … 横断（db・concurrency-control-design・未実装案件一覧・_archive・README）
- `CommonModule/Doc/` … 共通基盤（specs: common-print-platform/smtp-sender・sql: 共通DB 8本・smtp手順・README）
- `PrintAgent/Doc/` … PrintAgent（既存spec＋direct-print/・PrintAgent_Source/）
- `SmtpAgent/Doc/` … 既存
- `MaterialModule/Doc/` … 資材固有のみ（specs資材・sql資材・各設計md・data・manual）

### 次アクション
- ドキュメント整理は一段落。common-print-platform 実装フェーズ（Wave0: タスク1.1 DDL＝CommonModule/Doc/sql に t_print_queue・m_print_agent_control）へ着手可能。
- 各リポジトリ（MaterialModule/CommonModule/PrintAgent）は越境移動分のコミットが必要（ユーザー側）。

---

## チェックポイント（MaterialModule/Doc 残フォルダ判定＋非文書の削除）

### 残フォルダ判定（生死）
- `specs/`（資材spec 17件）・`sql/`（資材DB 14本）・`manual/`（操作マニュアル）＝**生きている・資材固有 → そのまま**。
- `kiro-signin-logs/`＝Kiro サインイン障害調査のIDEログ一式（非プロジェクト文書・陳腐化）。

### 削除（ユーザー承認）
- `kiro-signin-logs/`（フォルダ一式）／`maintenance-kiro-signin-20260623.md`／`_tmp_xlsx_result.txt`／`Thumbs.db` を削除。

### MaterialModule/Doc 最終状態（資材固有のみ）
- フォルダ: `manual/`・`specs/`・`sql/`
- md: order-status-flow / order-table-merge-design / purchase-condition-design / page-routing-investigation / db-migration-mapping / create-page-test-checklist / development-log / 発注点計算方法
- データ: account.png / order_form.pdf,png / 購買条件.xlsx / 仕入先得意先一覧.xlsx / 資材棚卸.xlsx / 資料.xlsx / 棚卸.csv / excel_*（検証用・残置）

### ドキュメント整理 完了
- 全段階（1〜5＋クリーンアップ）完了。越境移動分は各リポジトリでコミット済み（ユーザー）。
- 次: common-print-platform 実装フェーズ（Wave0: 1.1 DDL＝CommonModule/Doc/sql）。

---

## チェックポイント（モジュール docs フォルダ名の統一：Doc → docs）

### 確認結果（保管方法）
- MaterialModule/CommonModule（複数機能）＝ `docs/specs/{feature}/` にコピー配置（正本は `.kiro/specs/`）＋固有文書。同方式。
- PrintAgent/SmtpAgent（単一目的Worker）＝ 自身の spec を `docs/` 直下（spec.md 等）。原則共通・単一specのため specs/ 未使用。
- → ユーザー認識どおり整合。

### 実施（推奨名 = 小文字 docs、.kiro/docs と統一）
- 4モジュールの `Doc` → `docs` にリネーム: MaterialModule / CommonModule / PrintAgent / SmtpAgent。
- 生きた参照を `Doc/` → `docs/` に更新（steering project-rules、.kiro/docs/README、現行 common-print-platform 正本＋コピー、各 README、clnCoCore material-module.md、PrintAgent/SmtpAgent の docs）。接頭辞なし `Doc/` 表記も修正。
- 移動済みSQLを指すエージェント参照を実体に合わせ `CommonModule/docs/sql/` へ修正（create_smtp_agent.sql / create_print_agent_control.sql）。register_smtp_monitor_content.sql は資材残置で正。
- 書込は BOM無し・改行維持を確認。現行 spec 診断クリア。
- 履歴（session-memo・完了済み spec: order-approval-fax-mail / master-maintenance / dispatch-monitoring-consolidation / smtp-sender コピー）の旧 `Doc/` 表記は記録として残置。

### 現状の最終ドキュメント構成
- 横断: `.kiro/`（session-memo / specs 正本 / docs[db・concurrency・未実装案件一覧・_archive]）
- モジュール固有: `<module>/docs/`（MaterialModule=資材／CommonModule=共通基盤 specs+sql+smtp手順／PrintAgent=spec+direct-print+PrintAgent_Source／SmtpAgent=spec）

### 次アクション
- ドキュメント整理は完了。各リポジトリで Doc→docs リネーム分のコミットが必要（ユーザー）。
- common-print-platform 実装フェーズ（Wave0: 1.1 DDL＝CommonModule/docs/sql）へ着手可能。

---

## チェックポイント（specs モジュールフォルダ化：CommonModule 着手・print-platform 改名）

### 決定（検証済み）
- `.kiro/specs` を **A案（モジュール名フォルダ入れ子）** で単一正本化する方針に確定。プローブ `_probe-module/probe-feature` で **Kiro が入れ子スペックを認識**（エクスプローラ表示・3フェーズタブ・Start task）を実測確認済み。プローブは削除済み。
- IDE UIエラー（`Cannot read properties of undefined`＝スペックエクスプローラ一時エラー）回避のため**最小範囲（少数ずつ）**で移動する。

### 本チェックポイントの完了作業
- `.kiro/specs/CommonModule/` を作成し、`common-print-platform`・`smtp-sender` を移動（表示OK確認済み）。
- 命名統一: `common-print-platform` → **`print-platform`**（CommonModule 配下で「common」冗長のため除去。`smtp-sender` と釣り合い）。正本＋コピーのフォルダをリネーム。
- 参照更新（順序付き置換）:
  - `.kiro/specs/common-print-platform` → `.kiro/specs/CommonModule/print-platform`（正本パス入れ子化）
  - `CommonModule/docs/specs/common-print-platform` → `CommonModule/docs/specs/print-platform`（コピー）
  - 残りの `common-print-platform` → `print-platform`（feature名・`// Feature: print-platform, Property N` タグ・依存参照）
  - 対象: print-platform 正本＋コピー3ファイル／project-rules／CommonModule・MaterialModule docs README／dispatch-monitoring-consolidation（正本＋コピー）。
- 診断クリア・`.kiro/specs/print-platform`(誤フラット) 0件を確認。

### 残タスク（最小単位・順次）
1. **MaterialModule 19スペックを `.kiro/specs/MaterialModule/` へ数件ずつ移動**（＋各 spec の自己パス参照 `.kiro/specs/{feature}` → `.kiro/specs/MaterialModule/{feature}` 更新）。※smtp-sender の自己パス参照（`.kiro/specs/smtp-sender`）も未更新＝要追随（完了spec・低優先）。
2. steering 昇格（承認済み・保留）: clnCoCore の6本を Nonaka/.kiro/steering へ（基盤固有は fileMatch）。
3. `.kiro/skiles` → `.kiro/skills` リネーム。
4. project-rules の「Spec配置ルール」を「単一正本（.kiro/specs/{Module}/{feature}）＋コピー廃止」へ改定。
5. コピー（`<module>/docs/specs`）廃止は **`.kiro` の git 取り込み後**に実施（未版管理のため）。

### 備考
- Kiro UIエラーが出たら Restart（コード/spec 無関係のUI一時エラー）。作業は最小単位継続。

---

## チェックポイント（specs モジュールフォルダ化 完了：MaterialModule 全移動）

### 完了
- MaterialModule 19スペックを **4バッチ（5/5/5/4）で `.kiro/specs/MaterialModule/` へ移動**（UIエラー回避のため少数ずつ）。
- `.kiro/specs` 直下は **`CommonModule`(2) / `MaterialModule`(19) のみ**のクリーン構造に単一正本化完了。
  - CommonModule: print-platform / smtp-sender
  - MaterialModule: approvals-page, orders-page, dispatches-page, receivings-page, delivery-page-enhancements, delivery-monitor-page, dispatches-section-filter, forecasts-page, job-queue-page, mrp-page, dispatch-monitoring-consolidation, master-maintenance, order-approval-fax-mail, order-planning-dashboard, order-recommendation, material-module, print-monitor-page, stock-ledger-page, tank-check
- 完了済みページ spec の内部パス表記（historical）は最小方針で未改変。

### 既知（移動起因ではない）
- `orders-page`・`material-module` 等で spec 形式診断（`# Implementation Plan:`／`## Task Dependency Graph` 欠落）。旧テンプレ由来の既存差分。必要時に別途整備。
- `dispatch-monitoring-consolidation` は tasks.md 未作成（requirements/design のみ）。
- smtp-sender の自己パス参照（`.kiro/specs/smtp-sender`）は入れ子未追随（完了spec・低優先）。

### 残タスク（順次・最小単位）
1. steering 昇格（承認済み）: clnCoCore の6本 → Nonaka/.kiro/steering（基盤固有は fileMatch）。
2. `.kiro/skiles` → `.kiro/skills` リネーム。
3. project-rules「Spec管理ルール」を「単一正本 `.kiro/specs/{Module}/{feature}` ＋ コピー廃止」へ改定（コピー廃止実施と同時）。
4. コピー（`<module>/docs/specs`）廃止＝ `.kiro` の git 取り込み後に実施。

---

## チェックポイント（steering 昇格完了・変更不可明記・システム構成書 新設）

### steering 昇格（承認済みフル・完了）
- clnCoCore の6本を `Nonaka/.kiro/steering` へ移動し有効化。
  - `material-module.md`＝fileMatch `**/MaterialModule/**`（既存スコープ維持）
  - `coding-standards.md`＝常時（一般規約・優先順位注記＝モジュール固有が優先）
  - `structure.md`/`tech.md`/`product.md`/`module-development-guide.md`＝fileMatch `**/clnCoCore/**` を付与（CoCore作業時のみ有効・資材に干渉しない）
- `clnCoCore/.kiro/steering` は空になったが **C（残置）**。clnCoCore 所有でプルすれば戻るため削除しない（MainWeb/SharedCore/AuthModule＝変更不可リポジトリ）。

### 変更不可の明記（project-rules）
- 「モジュール改変の原則」を **MainWeb・SharedCore・AuthModule は変更不可**（clnCoCore ソース・設定は変更しない・要時は事前ユーザー確認）に更新。

### システム全体構成書 新設
- `.kiro/docs/system-architecture.md` 作成（横断ハブ）。基盤 clnCoCore（MainWeb=Composition Root/AuthModule/SharedCore/SharedInfrastructure・変更不可）＋追加モジュール（MaterialModule=db_material_dev／CommonModule=db_common_dev）＋Worker（SmtpAgent/PrintAgent＝別ソリューション）＋DB3種＋ModuleRegistration組込＋リポジトリ境界＋docs/spec配置＋steeringスコープを1枚に集約。Mermaid構成図・コンポーネント表付き。README索引に追記。診断クリア。

### 開発スタンス（確認事項）
- clnCoCore（MainWeb/SharedCore/AuthModule）をベースに、他プロジェクトモジュール（MaterialModule/CommonModule/PrintAgent/SmtpAgent）を追加する構成。ホスト登録は MainWeb の ModuleRegistration（プラットフォーム側 spec 所有）。

### 残タスク
1. `.kiro/skiles` → `.kiro/skills` リネーム。
2. project-rules「Spec管理ルール」を単一正本（`.kiro/specs/{Module}/{feature}`）へ改定（コピー廃止と同時）。
3. コピー（`<module>/docs/specs`）廃止＝ `.kiro` の git 取り込み後。

### コミットポイント
- steering昇格・変更不可明記・構成書新設・specs単一正本化まで安定。ここでコミット推奨。

---

## チェックポイント（steering: clnCoCore を復元＝MOVEをCOPYに是正）

### 問題認識
- steering 昇格時に clnCoCore の6本を **MOVE（clnCoCore から削除）** していた。clnCoCore は変更不可の基盤リポジトリのため誤り。

### 是正
- `git -C clnCoCore restore .kiro/steering` で6本を復元。**clnCoCore/.kiro/steering=6本・worktree差分ゼロ（原状復帰）**。
- Nonaka/.kiro/steering=7本（project-rules＋昇格コピー6本・fileMatchスコープ付与済み）はアクティブとして保持。
- 結果＝当初のMOVEをCOPYに是正。clnCoCore基盤は無変更、Nonakaがアクティブ overlay。

### 二重配置の位置づけ（意図的）
- clnCoCore/.kiro/steering＝基盤リポジトリ所有・プルで維持・Nonakaワークスペースでは休眠（Kiroはルート直下のみ読む）。
- Nonaka/.kiro/steering＝本ワークスペースのアクティブ steering。

### コミット影響
- clnCoCore は差分ゼロ＝コミット不要。コミット対象は Nonaka/.kiro（steering6本コピー追加・specs再編・docs/system-architecture 追加・session-memo）＋ CommonModule/MaterialModule の docs 差分。

### 残タスク（変更なし）
1. `.kiro/skiles`→`.kiro/skills` リネーム
2. project-rules「Spec管理ルール」を単一正本（`.kiro/specs/{Module}/{feature}`）へ改定（コピー廃止と同時）
3. コピー（`<module>/docs/specs`）廃止＝ `.kiro` git 取り込み後

---

## 決定（steering 重複の扱い）

- Nonaka/.kiro/steering の7本（project-rules ＋ clnCoCore由来6本のコピー）は **現状維持（残置）** で確定。
- 位置づけ: clnCoCore/.kiro/steering＝基盤リポジトリ原本（休眠・プルで維持）。Nonaka/.kiro/steering＝本ワークスペースのアクティブ steering（Kiro はルート直下のみ読むため、有効化には Nonaka 側配置が必要）。重複は有効化のための意図的配置として受容。
- steering ファイルへの追加変更なし。

---

## チェックポイント（コミット実施＋.kiro 版管理化）

### コミット（Kiro代行・ユーザー委任）
- CommonModule `dfe3230`: print-platform 改名・docs 整理。
- MaterialModule `07c65ca`: print-platform 改名に伴う spec 参照更新。
- **Nonaka 新規 git `ee2897b`**: `.kiro` を版管理化（初回・152ファイル）。
- clnCoCore/PrintAgent/SmtpAgent: 差分なし・コミット不要。

### .kiro 版管理化の設計
- Nonaka ルートに `git init`。`.gitignore` は `/*` ＋ `!/.gitignore` ＋ `!/.kiro/`（.kiro と .gitignore のみ追跡）。
- ネストした各モジュールリポジトリ・bin/obj は非追跡（巻き込み回避）。ステージ=.kiro 配下のみを確認。
- 以後、steering・spec・docs・session-memo が履歴付きで保全される。

### 残タスク
1. `.kiro/skiles` → `.kiro/skills` リネーム（Kiro 誤認識解消）。※Nonaka repo で追跡済みのため、リネーム後は Nonaka repo で再コミット。
2. project-rules「Spec管理ルール」を単一正本（`.kiro/specs/{Module}/{feature}`）へ改定。
3. コピー（`<module>/docs/specs`）廃止＝各モジュール repo でコミット（.kiro 版管理化により正本は保全済み。ただしユーザー方針次第では docs/specs コピーを残す選択も可＝要確認）。

### 補足
- Nonaka repo はワークスペース・メタ専用（.kiro のみ）。リモート push 方針は未定（ユーザー判断）。
