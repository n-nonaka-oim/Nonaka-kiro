# 実装計画

- [x] 1. エンティティ＋DbContext（印刷設定2マスタ）
  - [x] 1.1 `Data/Entities/MUserPrintSetting.cs`（`m_user_print_setting`：user_code/report_type/printer_name/監査/row_version）
    - _要件: 5.1, 5.6_
  - [x] 1.2 `Data/Entities/MPrintSystemSetting.cs`（`m_print_system_setting`：report_type/external_output_enabled/printer_name/監査/row_version）
    - _要件: 6.1_
  - [x] 1.3 `MaterialDbContext` に DbSet 2件＋一意インデックス（user_code×report_type／report_type）を追加
    - _要件: 5.6, 6.1_

- [x] 2. スキーマ変更SQL（適用はユーザー）
  - `docs/sql/create_m_user_print_setting.sql`・`docs/sql/create_m_print_system_setting.sql`（CREATE＋一意インデックス・冪等）
  - _要件: 10.4_

- [x] 3. 純粋ロジック（方式判定・外部出力ゲート）
  - `Logic/PrintRoutingRules.cs`：`ResolveOutputKinds(int? outputType)`（0=なし/1=PDFエージェント/2=SMTPエージェント/3=両方）／`ShouldExternalOutput(MPrintSystemSetting?)`（enabled かつ printer_name 非空）
  - _要件: 7.1, 8.2, 6.2, 6.3_

- [x]* 4. 純粋ロジックのプロパティテスト
  - `MaterialModule.Tests` に `PrintRoutingRulesPropertyTests`（P1 方式判定 全域／P2 外部出力ゲート）
  - _要件: 7.1, 6.2_

- [x] 5. IPrintOutputResolver / PrintOutputResolver ＋ DI
  - `Services/IPrintOutputResolver.cs`・`Services/PrintOutputResolver.cs`：`ResolveUserPrinterAsync(userCode, reportType)`／`ResolveSystemSettingAsync(reportType)`／`ResolveSelfEmailAsync(loginName)`（既存 `ISenderInfoResolver.ResolveSenderEmailAsync` 再利用可）
  - `MaterialModuleExtensions` に Scoped 登録
  - _要件: 3.2, 6.2, 9.4_

- [x] 6. ユーザー印刷設定 自己サービス画面
  - `Areas/Material/Pages/PrintSettings/Index.cshtml(.cs)`：ログインユーザーの `m_user_print_setting` を帳票種別ごとに表示・編集。プリンタ選択肢＝`IPrinterQueryService.GetAvailablePrintersAsync`。`row_version` 楽観ロック。`[Authorize(Policy="DbPermissionCheck")]`。`_MaterialStyles`/フォント規約準拠
  - _要件: 5.2, 5.3, 5.4, 5.5_

- [ ] 7. PDFエージェント投入の printer_name 解決反映
  - [x] 7.1 Orders/Create 承認時：**案B（承認前ブロック）**。`ApprovalService.EnsurePrinterAssignedAsync` で出力区分1/3の発注につき発注者×`order_approval` の割当を検証し未設定なら `InvalidOperationException`（Approvals が ErrorMessage 表示）。`PrintJobService` は解決した printer_name で `EnqueueAsync`（未設定は防御的にスキップ・ログ）
    - _要件: 3.1, 3.2, 3.3, 3.5, 7.1, 7.4, 7.5_
  - [x] 7.2 Dispatches(ii)：`m_print_system_setting`(dispatch_request) を解決し、外部出力ON かつ printer_name 非空のとき PDFエージェント投入（固定パス保存＋`IPrintQueueService.EnqueueAsync(printer_name)`・投入失敗は請求を妨げない）
    - _要件: 6.2, 6.3, 6.4, 8.2_

- [x] 8. PDFプリント導線（HTTP配信）＝既存機能で充足
  - [x] 8.1 発注書は**承認経路のPDFエージェント/SMTPエージェント**が本線（最終マトリクス）。手動DLは既存 `Approvals.OnGetDownloadPdfAsync`（`File`配信）で充足＝新規導線不要
    - _要件: 2.1, 2.2, 2.3_
  - [x] 8.2 Dispatches(i)：既存 `OnPostSubmitAsync` の `PdfOutput`→`File(pdf)` が PDFプリント（HTTP配信）＝充足
    - _要件: 2.1, 2.3, 8.1_
  - [x] 8.3 Receivings：既存 `OnGetExportPdfAsync`（`File`配信）が PDFプリント＝充足
    - _要件: 2.1, 2.3_

- [x] 9. Dispatches 2カ所出力の統合
  - 「請求」押下で (i) PDFプリント（PdfOutput）＋(ii) PDFエージェント（外部出力ON時）を**同一生成PDF**で実施（`pdf` を1回生成し共用・二重生成回避）
  - _要件: 8.1, 8.2, 8.3_

- [x] 10. テスト出力（エージェント時のみ）＝**案Y：PrintSettings 自己サービス画面に集約**
  - [x] 10.1 テスト印刷（PDFエージェント）：帳票種別ごとの「テスト印刷」ボタン。保存済み割当プリンタへテストPDFを固定パス保存＋`IPrintQueueService.EnqueueAsync`。本番フロー非経由。未割当はエラー通知
    - _要件: 9.1, 9.2, 9.3, 9.5_
  - [x] 10.2 テストメール送信（SMTPエージェント）：「テストメール送信（自分宛）」ボタン。`ResolveSelfEmailAsync` の自分宛へ `ISmtpQueueService.EnqueueAsync(configKey:"mail")`。本番宛先へ送らない。宛先/送信元未設定はエラー
    - _要件: 9.1, 9.2, 9.4, 9.5_

- [ ] 11. ビルド確認（チェックポイント・ユーザー）
  - slnCoCore ビルド＋（適用済みなら）画面動作確認。DBは task2 SQL 適用が前提
  - _要件: 10.1, 10.3_

- [x] 12. ドキュメント整合
  - `.kiro/docs/db/テーブル定義書.md`・`ER図.md`・`ER図.mmd` に `m_user_print_setting`・`m_print_system_setting` を反映
  - _要件: 11.1_

## タスク依存グラフ

```mermaid
flowchart TD
  T1[1 エンティティ/DbContext] --> T5[5 Resolver+DI]
  T1 --> T7[7 PDFエージェント投入]
  T3[3 純粋ロジック] --> T4[*4 PBT]
  T3 --> T7
  T3 --> T9[9 Dispatches2カ所]
  T5 --> T6[6 自己サービス画面]
  T5 --> T7
  T5 --> T10[10 テスト出力CB]
  T7 --> T9
  T8[8 PDFプリント導線] --> T9
  T2[2 スキーマSQL] --> T11[11 ビルド/動作CP・ユーザー]
  T6 --> T11
  T7 --> T11
  T9 --> T11
  T10 --> T11
  T11 --> T12[12 docs]
```

- 実装順の目安：1 → 2 → 3 →（*4）→ 5 → 6 → 7 → 8 → 9 → 10 → 11（ユーザー）→ 12
- スキーマ追加（2マスタ）はコードと分離し SQL 適用はユーザー。破壊系なし（新規テーブル追加）。
