# Implementation Plan: PrintSettings 帳票別出力プリンタのアクセス権連動制限

## Overview

PrintSettings 画面（`Areas/Material/Pages/PrintSettings/Index`）の「帳票別 出力プリンタ」を、各帳票の対応ページ（area=Material）へのアクセス権に連動して制限する。UI は案B（不可帳票は行表示のまま select と「テスト印刷」を disabled）＋サーバ側防御（保存スキップ・テスト印刷拒否）。

スコープ拡張として、同一画面の「ページ別既定設定カード」（出力区分 select・印刷既定チェックボックス）も、対応ページのアクセス権（order_approval → Orders/Create、dispatch_request → Dispatches/Index）に連動して UI 無効化（design §8）＋保存時のサーバ側項目単位防御（design §9）を行う（Requirement 6 / Requirement 7）。

変更対象は MaterialModule の 2 ファイルのみ:
- `Areas/Material/Pages/PrintSettings/Index.cshtml.cs`
- `Areas/Material/Pages/PrintSettings/Index.cshtml`

clnCoCore（MainWeb / AuthModule / SharedCore）・DB スキーマは変更不可（読み取り参照のみ）。実装言語は C#（既存 MaterialModule に準拠）。ビルドはユーザー側で実施（Kiro からビルドしない）。テストは任意（MaterialModule.Tests は管理外運用）。design の Correctness Property 1（`ParseSectionIds` の property-based test）はタスクに含めるが「任意（`*`）」とする。

各タスクは最小単位（1タスク＝1つの明確な成果物）で、順に積み上げる。design の Components and Interfaces 1〜7 を実装ガイドとする。

## Tasks

- [x] 1. 認可判定基盤の実装（`Index.cshtml.cs`）
  - [x] 1.1 IndexModel への依存注入と using 追加
    - primary constructor 末尾に `IContentAuthService contentAuthService` を追加（既存注入: MaterialDbContext, IPrinterQueryService, IPrintOutputResolver, IPrintQueueService, ISmtpQueueService, ISendConfigService, IPrintOutputPathService, IUserOrderSettingService の後ろ）
    - using に `SharedCore.Interfaces;` と `System.Security.Claims;` を追加
    - clnCoCore は変更せず、DI 済みの `IContentAuthService` を読み取り参照で受け取るのみ
    - _Requirements: 1.2, 5.1, 5.2_（design §1）

  - [x] 1.2 Report_Page_Map（ReportTypeDef に対応ページ）を定義
    - `ReportTypeDef` を `record(string ReportType, string Label, string Page)` に変更（`Page` フィールド追加）
    - `ReportTypes` を order_approval→`Orders/Create`／dispatch_request→`Dispatches/Index`／receiving→`Receivings/Index` で定義
    - area 固定用に `private const string AuthArea = "Material";` を追加
    - _Requirements: 1.1, 1.5_（design §2）

  - [x] 1.3 Claim 解析の純粋関数 `ParseSectionIds` を実装
    - `internal static List<string> ParseSectionIds(string? allSectionIds)`：カンマ分割＋空要素除去（`StringSplitOptions.RemoveEmptyEntries`）、null/空は空リスト
    - 副作用なしの純粋関数として単独で検証可能にする
    - _Requirements: 1.3_（design §3）

  - [x] 1.4 判定マップ構築 `BuildReportEditMapAsync` と `IsPageAuthorizedAsync` を実装
    - `BuildReportEditMapAsync`：SuperUser は全帳票 true、非 SuperUser は Claim `"max_rank"`（`int.TryParse` 失敗時 0）と `ParseSectionIds(User.FindFirstValue("all_section_ids"))` を 1 回解析し、`report_type → CanEdit` の `Dictionary<string,bool>` を構築（所属未設定は不可・安全側）
    - Claim キーはリテラル `"max_rank"` / `"all_section_ids"` を使用し、`AuthModule.Constants.ClaimKeys` と同値である旨をコメントで明記（AuthModule 参照不可のため）
    - `IsPageAuthorizedAsync`：`IContentAuthService.IsAuthorizedForAnySectionAsync(maxRank, sectionIds, AuthArea, page)` を呼び、末尾が `/Index` でなければ `page/Index` でも OR 評価（要件 1.5 を自動充足）
    - 判定方式は clnCoCore `DbPermissionHandler` に準拠
    - _Requirements: 1.1, 1.2, 1.4, 1.5_（design §3）

  - [-]* 1.5 `ParseSectionIds` の property-based test（任意・スキップ）
    - **Property 1: 所属ID解析は空要素を除去し非空トークンを保持する**
    - **Validates: Requirements 1.3**
    - FsCheck.Xunit で、カンマを含まない非空トークン列をカンマ結合→`ParseSectionIds` した結果が元の非空トークン列と順序含め一致し、空要素（連続/先頭/末尾カンマ・空文字）が除去されることを検証（最低 100 反復）
    - 配置先は `MaterialModule.Tests`（管理外運用のため任意）
    - _Requirements: 1.3_

- [x] 2. 編集可否の UI 反映（案B）
  - [x] 2.1 `AssignmentInput.CanEdit` 追加と Inputs 構築への反映（`Index.cshtml.cs`）
    - `AssignmentInput` に `public bool CanEdit { get; set; }`（画面内 DTO・永続化なし）を追加
    - `OnGetAsync` / `ReloadAsync` / `OnPostAsync` 再表示の 3 箇所すべてで、`await BuildReportEditMapAsync()`（各ハンドラ 1 回）から `CanEdit` を解決して `Inputs` を構築
    - _Requirements: 2.1_（design §4）

  - [x] 2.2 cshtml で Inaccessible 行の select と「テスト印刷」を無効化（`Index.cshtml`）
    - 各行の select に `disabled="@(!Model.Inputs[i].CanEdit)"` を付与
    - 各行の「テスト印刷」ボタンに `disabled="@(!Model.Inputs[i].CanEdit)"` を付与
    - 行自体は Accessible/Inaccessible とも従来どおり表示。ページ別既定設定カードは変更しない
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.4_（design §5）

- [x] 3. サーバ側防御（`Index.cshtml.cs`）
  - [x] 3.1 `OnPostAsync` の保存ループに Inaccessible スキップを追加
    - 保存ループ前に `await BuildReportEditMapAsync()` を 1 回構築し、再表示 Inputs 構築でも再利用
    - ループ内で対象 `reportType` が Inaccessible（`CanEdit=false`）なら追加・更新・削除を行わず `continue`
    - Accessible の割当は既存ロジックのまま保存
    - _Requirements: 3.1, 3.2, 3.3_（design §6）

  - [x] 3.2 `OnPostTestPrintAsync` 先頭に Inaccessible 拒否を追加
    - ハンドラ先頭（プリンタ解決・キュー投入の前）で `await BuildReportEditMapAsync()` により対象 `reportType` を判定
    - Inaccessible なら拒否メッセージ（例:「この帳票のテスト印刷を実行する権限がありません。」）を設定し、`ReloadAsync` 後に `return Page()`（キュー投入なし）
    - Accessible は既存のプリンタ解決〜キュー投入を従来どおり実行
    - _Requirements: 4.1, 4.2, 4.3_（design §7）

- [x] 4. Checkpoint - 実装の整合性確認
  - 変更が `Index.cshtml.cs` と `Index.cshtml` の 2 ファイルに閉じていること、clnCoCore・DB スキーマ・ページ別既定設定カードが不変であることを確認する（_Requirements: 5.1, 5.2, 5.3, 5.4_）
  - ビルドはユーザー側で実施。疑問が生じたらユーザーに確認する。

- [x] 5. ページ別既定設定カードのアクセス権連動 UI（`Index.cshtml.cs` + `Index.cshtml`）
  - [x] 5.1 IndexModel に表示用フラグ 2 つを追加し editMap 構築 3 箇所で設定（`Index.cshtml.cs`）（完了）
    - `public bool CanEditDefaultOutputType { get; set; }` と `public bool CanEditDispatchPrintDefault { get; set; }`（画面内 DTO・永続化なし）を追加
    - `editMap` を構築する `OnGetAsync` / `OnPostAsync` 再表示 / `ReloadAsync` の 3 箇所で `CanEditDefaultOutputType = editMap.TryGetValue("order_approval", out ...) && ...;` `CanEditDispatchPrintDefault = editMap.TryGetValue("dispatch_request", out ...) && ...;` を設定
    - _Requirements: 6.1, 6.4, 6.5_（design §8）

  - [x] 5.2 cshtml で出力区分 select と印刷チェックボックスを disabled 化（`Index.cshtml`）
    - `DefaultOutputType` select に `disabled="@(!Model.CanEditDefaultOutputType)"`、`DispatchPrintDefault` チェックボックスに `disabled="@(!Model.CanEditDispatchPrintDefault)"` を付与
    - カード・保存ボタン・ラベルは常時表示（案B）
    - _Requirements: 6.2, 6.3, 6.4_（design §8）

- [x] 6. ページ別既定設定保存時のサーバ側防御（`Index.cshtml.cs`）
  - [x] 6.1 `OnPostSaveOrderSettingAsync` を項目単位防御に改修
    - 先頭で editMap を 1 回構築、canOutput=order_approval / canDispatch=dispatch_request を解決
    - 出力区分: canOutput なら送信値採用＋IsValid 値域検証、不可なら GetDefaultOutputTypeAsync+Normalize で既存値維持
    - 印刷既定: canDispatch なら送信値、不可なら GetDispatchPrintDefaultAsync+Normalize で既存値維持
    - 解決 2 値で SaveOrderSettingAsync 呼び出し。競合処理・ReloadAsync は従来どおり
    - _Requirements: 7.1, 7.2, 7.3, 7.4_（design §9）

- [x] 7. Checkpoint - カード拡張の整合性確認
  - 変更が `Index.cshtml.cs` / `Index.cshtml` の 2 ファイルに閉じ、clnCoCore・DB スキーマ不変、カードの既存挙動（1 行同時保存・初期表示）が保たれることを確認
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

## Notes

- `*` 付きサブタスク（1.5）は任意でスキップ可。MaterialModule.Tests は管理外運用のため実施はユーザー判断。
- 各タスクは最小単位（1タスク＝1成果物）。`Index.cshtml.cs` を編集するタスクは同一ファイル競合を避けるため順次実行（依存グラフで別ウェーブ。5.1 と 5.3 も別ウェーブ、5.2 は `Index.cshtml` のため 5.1 と並行可）。
- タスク 5.x（Requirement 6／design §8・Requirement 7／design §9）は帳票別と同じ `BuildReportEditMapAsync`（`report_type → CanEdit`）を流用し、新規のページ判定・純粋関数を追加しないため property test は増やさない。
- ビルドは Kiro からは実行せず、ユーザー側で実施する。
- 各タスクは design の Components and Interfaces（§1〜7）と requirements の Acceptance Criteria に対応付けている。
- 純粋関数 `ParseSectionIds` のみ property-based test 対象（Property 1）。その他は IO/副作用依存のため代表例・統合テストで検証（本 spec のタスク範囲外・任意）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3"] },
    { "id": 3, "tasks": ["1.4", "1.5"] },
    { "id": 4, "tasks": ["2.1"] },
    { "id": 5, "tasks": ["2.2", "3.1"] },
    { "id": 6, "tasks": ["3.2"] },
    { "id": 7, "tasks": ["5.1"] },
    { "id": 8, "tasks": ["5.2", "6.1"] },
    { "id": 9, "tasks": ["7"] }
  ]
}
```
