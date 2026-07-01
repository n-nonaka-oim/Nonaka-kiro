# 設計書: 印刷ジョブ監視ページ（PrintMonitor）

## 概要

PrintAgent（オンプレ常駐の .NET8 Worker Service）が処理する印刷ジョブ（`t_order_reports`）を、Web画面で俯瞰・監視するための**閲覧専用**ページ。Worker Service は UI を持たないため、処理状況・エラー・滞留を可視化して障害対応の判断材料を提供する。

対象ファイル:
- `Areas/Material/Pages/PrintMonitor/Index.cshtml`
- `Areas/Material/Pages/PrintMonitor/Index.cshtml.cs`

## 背景・JobQueue との違い

既存の JobQueue ページは「発注者が自分の発注書PDFを取得する業務画面」であり、監視用途には不適:
- `report_type == 'order_approval'` 固定（他帳票種別が見えない）
- `t_orders` と内部結合（t_orders に対応行が無いジョブは表示されない）
- `o.UserId == userId`（自分のジョブのみ）
- 発注番号でグループ集約（個々のジョブ状態が見えない）

PrintMonitor は `t_order_reports` を**全件・全帳票種別・全ステータス**でそのまま表示する。

## 画面構成

### サマリカード（全件ベース・フィルタ非依存）
- 待機(1) / 処理中(2) / 完了(3) / エラー(9) / 要確認(滞留) の件数
- 滞留 = 処理中(2)のまま閾値（既定10分）超過、または 待機(1)かつ payload=NULL

### フィルタ
- ステータス（待機/処理中/完了/エラー）
- 帳票種別（order_approval / receiving_slip / factory_invoice）
- 参照コード（reference_code 部分一致）
- 作成日 From / To

### 一覧
- 列: ID / 帳票種別 / 参照コード / 総合ステータス / 印刷ステータス / FAXステータス / プリンタ / 部数 / 取得日時 / 完了日時 / 作成日時 / エラー内容
- **総合ステータス列**（参照コードの右）: 印刷・FAX の各状態を1列に集約したバッジ。優先順位 滞留 > エラー > 処理中 > 待機 > 完了 > 対象外 で1つに決定し色分け表示
- 印刷/FAX ステータスはバッジ表示（待機=黄, 処理中=青, 完了=緑, エラー=赤, 対象外=灰）
- エラー内容はツールチップで全文、一覧は40字で省略
- 滞留ジョブは行を黄色ハイライト＋警告アイコン（payload=NULL は理由をツールチップ表示）
- 並び: ID降順、ページング（_Pager 上下）

### 日時表示（日本時間）
- 全日時を**日本時間（JST）**で表示する。
- `CreatedAt` は Web側で JST 保存（PrintJobService が JST で INSERT）のためそのまま表示。
- `PickedAt` / `CompletedAt` は Worker が UTC 保存のため、JST へ明示変換して表示（`ToLocalTime()` は使わずタイムゾーン変換ヘルパーで JST 固定）。

### 自動更新
- 10秒間隔の location.reload。チェックボックスでON/OFF、状態は sessionStorage 保持。
- **カウントダウン表示**: 「あと○秒」を1秒ごとに更新し、0でリロード。次の更新までの残り時間を可視化。

## 実装ポイント

- PageModel: `MaterialDbContext` を注入、`OrderReports` を `AsNoTracking()` でクエリ
- サマリは `GroupBy(PrintStatus)` で集計、滞留は別カウント
- 日時は JST で表示（CreatedAt は JST 保存済みのためそのまま、PickedAt/CompletedAt は UTC→JST 変換ヘルパーで変換）
- 総合ステータスは 滞留 > エラー > 処理中 > 待機 > 完了 > 対象外 の優先で印刷/FAX状態を1値に集約
- 自動更新はカウントダウン（残り秒を1秒ごと表示、0でリロード）
- 認可: `[Authorize(Policy = "DbPermissionCheck")]`。閲覧ロールは dbAuthTest 側のコンテンツ権限（m_content / r_content_auth）で制御
- スタック閾値: `StuckThresholdMinutes = 10`（定数）

## コンテンツ認可登録

認証DB dbAuthTest に登録（ユーザー側実施）:
- `m_content`: area='Material', page='PrintMonitor/Index', label='プリントモニター', group='資材調達', is_visible=1
- `r_content_auth`: 閲覧を許可するロール×セクションを付与
- 補助SQL: `MaterialModule/Doc/sql/register_print_monitor_content.sql`

## ビルド時の注意（重要）

MaterialModule（RCL）に**新規 Razor ページを追加した場合、インクリメンタルビルドが Razor コンパイルを取りこぼし、dll にページが含まれず asp-page のリンクが生成されない**ことがある。新規ページ追加時は obj/bin を削除して**クリーンビルド**すること（2026/06/15 に本ページで発生・対処）。

## 将来拡張（未実装）

- payload=NULL / スタックジョブのクリーンアップ操作
- 死活監視（Worker の heartbeat 表示）

## 操作機能（2026/06/16 追加）

### 再出力
- 完了(3)・エラー(9) のジョブに「再出力」ボタンを表示。
- 押下で print_status を待機(1)に戻し、picked_at/completed_at/print_at/error_message をクリア → Worker が再処理。
- PDF は Temp に保管されるが、Worker は payload から再生成して印刷するため再現性がある。
- ハンドラ: `OnPostReprintAsync(int id)`。payload が無い/状態が3・9以外は不可。

### PrintAgent 死活監視（heartbeat）
- タイトル右に生存バッジ（ポーリング中=緑 / 応答なし=灰）＋最終応答時刻・ホスト名を表示。
- `m_print_agent_control`（1行運用 last_heartbeat_at/machine_name）。Worker がポーリング毎に更新。
- PrintMonitor は最終応答が既定30秒（`HeartbeatAliveSeconds`）以内なら「ポーリング中」、超過で「応答なし」。
- 稼働ON/OFFの手動制御は廃止（SkipPrint完了との競合・オペレーション混乱のため）。表示のみ。
