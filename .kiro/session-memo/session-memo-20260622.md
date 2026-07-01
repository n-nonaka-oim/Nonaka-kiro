# セッション備忘録（2026/06/22 - 進捗なし・前回状態を維持）

## 本日
- 作業なし（コード変更・ビルド・DDL実行いずれも未実施）。
- 状態は前回 2026/06/20 から変化なし。実体の詳細は **`session-memo-20260620.md` を正本として参照**すること。

## 現在の到達点（20260620 時点のまま）
- smtp-sender 実装: **タスク1（DDL/ドキュメント整備）完了** ✓ / **タスク2（CommonModule 新規プロジェクト・共通エンティティ3種・CommonDbContext）完了** ✓
- ビルド・DDL実行とも **未実施**。

## 次回タスク（最優先・20260620から継続）
1. **まず CommonModule をクリーンビルドして通ることを確認**（新規プロジェクト追加直後のため）。
2. **タスク3: 投入ヘルパー ISmtpQueueService**
   - 3.1 ISmtpQueueService / SmtpQueueService（EnqueueAsync。status=1, created_at==updated_at=now でINSERT。module/configKey/fromAddress/recipient/subject 空文字バリデーション→ArgumentException。config_key実在チェックはWorker側）
   - 3.2* 投入不変条件PBT（Property 1、EF Core InMemory、100イテレーション）
   - 3.3 CommonModuleExtensions.AddCommonModule(configuration) + MainWeb の ModuleRegistration.AddModules に AddCommonModule 追加・CommonDb 接続文字列注入
3. **タスク1のDDLを db_common_dev に実行**（タスク4の前提。create 3本 → insert_m_smtp_config）
4. **タスク4: SmtpAgent改修**（別sln。接続先 db_common_dev・TSmtpQueue/MSmtpConfig差し替え）
5. タスク5（送信サービス）→ 6（Worker）→ 8（監視画面 SmtpMonitor）→ 10（統合テスト・Spec同期）

## EnqueueAsync シグネチャ（再掲）
`EnqueueAsync(module, configKey, fromAddress, fromName, recipient, subject, body?, pdfPath?)`

## 注意（継続・要点のみ。詳細は20260620メモ）
- ビルド・DDL実行・動作確認はユーザー側。新規プロジェクト追加時はクリーンビルド必須。Worker起動中はexeロックでビルド不可。
- 新基盤の3テーブルは **db_common_dev**（db_material_dev と取り違え注意）。
- slnCoCore.sln に CommonModule 追加済み。
- 並行運用: 既存 t_order_reports.fax_status 経路・旧smtpテーブル・既存ページは削除せず残す。

## 申し送り
- 本日は進捗なし。次回は **CommonModule クリーンビルド確認 → タスク3** から。詳細は `session-memo-20260620.md` を参照。
- 新セッションは「再開します、session-memoを確認」で最新メモから。
