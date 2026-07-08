# Implementation Plan: monitor-job-delete（共通監視画面の一括削除機能）

## Overview

design.md に基づき、Common_SmtpMonitor（`/Common/SmtpMonitor`）と Common_PrintMonitor（`/Common/PrintMonitor`）に、Material/Dispatches を踏襲した**チェックボックス複数選択＋一括削除**機能を追加する。削除は物理削除・**処理中(2)以外**（待機1/完了3/エラー9）が対象・**確認ダイアログ**あり。成果物は CommonModule 内で完結（スキーマ変更なし・MainWeb/AuthModule 不変更）。

前提・運用ルール:
- データアクセスは既存 `CommonDbContext` を直接注入。新規サービス/テーブル/スキーマ変更なし。
- 削除可否はサーバ側の削除クエリ条件（`status != 2` / `print_status != 2`）で担保。
- 認可は既存 `DbPermissionCheck`。ビルド・テスト実行はユーザー側。
- テストは `CommonModule.Tests`（xUnit + FsCheck・100反復以上・`// Feature: monitor-job-delete` タグ）。

## Tasks

- [x] 1. Common_SmtpMonitor に一括削除を実装
  - [x] 1.1 PageModel に一括削除ハンドラを追加
    - `CommonModule/Areas/Common/Pages/SmtpMonitor/Index.cshtml.cs` に `[BindProperty] List<int> SelectedJobIds` と `OnPostDeleteAsync` を追加
    - 削除条件：`context.SmtpQueue.Where(r => SelectedJobIds.Contains(r.Id) && r.Status != 2)` を `RemoveRange`→`SaveChangesAsync`
    - 未選択は削除せず「削除するジョブを選択してください。」。削除件数を成功メッセージに（件数<選択時は除外注記）
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 3.1, 3.2, 3.3, 4.2_

  - [x] 1.2 ビューに行チェックボックス＋一括削除ボタン＋確認ダイアログを追加
    - `SmtpMonitor/Index.cshtml`：一覧を削除用 `<form method="post">` で囲み、各行に `<input type="checkbox" name="SelectedJobIds" value="@row.Id">`、一覧外に「選択削除」ボタン（`asp-page-handler="Delete"`）、全選択チェック＋`confirm()`（Material/Dispatches 踏襲）
    - 既存の再送ボタン/フォームと併存させる（フォーム境界に注意）
    - _Requirements: 1.1, 4.1, 4.2, 4.3_

- [x] 2. Common_PrintMonitor に一括削除を実装
  - [x] 2.1 PageModel に一括削除ハンドラを追加
    - `CommonModule/Areas/Common/Pages/PrintMonitor/Index.cshtml.cs` に `[BindProperty] List<int> SelectedJobIds` と `OnPostDeleteAsync` を追加
    - 削除条件：`context.PrintQueue.Where(r => SelectedJobIds.Contains(r.Id) && r.PrintStatus != 2)` を `RemoveRange`→`SaveChangesAsync`
    - 未選択は削除せず通知。削除件数を成功メッセージに
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 4.2_

  - [x] 2.2 ビューに行チェックボックス＋一括削除ボタン＋確認ダイアログを追加
    - `PrintMonitor/Index.cshtml`：SmtpMonitor と同方式（削除用フォーム・行チェックボックス・選択削除ボタン・全選択・confirm）。既存の再出力ボタンと併存
    - _Requirements: 2.1, 4.1, 4.2, 4.3_

- [ ] 3. チェックポイント - ビルド/テストを通す
  - ビルド／テスト実行はユーザー側。両画面で選択→確認→削除→件数メッセージ→一覧最新化の一連が整合していることを確認する。

- [ ]* 4. 削除対象選別のプロパティテスト
  - [ ]* 4.1 Property 1: 削除対象選別は「選択かつ 処理中(2) 以外」と一致する
    - **Property 1: 削除対象選別は「選択かつ 処理中(2) 以外」と一致する**
    - **Validates: Requirements 1.2, 1.3, 2.2, 2.3, 3.1, 3.2**
    - `CommonModule.Tests`（InMemory）：ジョブ集合（Id×status 1/2/3/9）＋選択Id集合を生成し、`OnPostDeleteAsync` 後に「選択かつ status≠2（Print は print_status≠2）」のみ削除・他は不変を検証。`// Feature: monitor-job-delete, Property 1` タグ・100反復以上

  - [ ]* 4.2 例示テスト（未選択・処理中のみ・混在）
    - 未選択→0件＋エラーメッセージ、処理中のみ選択→0件、混在→削除可能分のみ削除＋件数メッセージ、を検証
    - _Requirements: 3.3, 4.2_

## Notes

- `*` 付き（テスト）は任意。コア実装は 1・2（両画面の PageModel＋ビュー）。
- 参照実装＝`MaterialModule/Areas/Material/Pages/Dispatches/Index.cshtml.cs` の `OnPostRemoveAsync`（`SelectedEntryIds`＋クエリ条件＋`RemoveRange`）。
- スキーマ変更なし・物理削除。監視画面本体の所有は print-platform / smtp-sender、本 spec は削除機能の追加を所有。
- MainWeb・AuthModule・SharedCore は変更しない。ビルド・テスト実行はユーザー側。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "2.2"] },
    { "id": 2, "tasks": ["3"] },
    { "id": 3, "tasks": ["4.1", "4.2"] }
  ]
}
```
