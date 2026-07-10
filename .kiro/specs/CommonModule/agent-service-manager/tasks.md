# Implementation Plan: agent-service-manager（Agent 起動/停止/状態管理 WinForms アプリ）

## Overview

design.md に基づき、CommonModule プラットフォームの2常駐サービス（`CommonSmtpAgent`・`CommonPrintAgent`）をローカルで管理する WinForms(.NET8) アプリを実装する。純粋ロジック（ハートビート判定・件数集計・状態マッピング・操作ガード）を I/O から分離し PBT で検証する。Agent 本体・DB スキーマは変更しない（DB は読み取りのみ）。

前提・運用ルール（全タスク共通）:
- 新規独立プロジェクト（例 `\\...\WindowsService\AgentServiceManager`・net8.0-windows・WinForms）。SmtpAgent/PrintAgent/CommonModule/MainWeb は参照/変更しない。
- DB `db_common_dev` は `AsNoTracking` の読み取り専用。書き込みなし。
- サービス制御・登録は管理者昇格前提（app.manifest）。
- テスト: xUnit + FsCheck 2.16.6（`AgentServiceManager.Tests` 新設）。ビルド/実行はユーザー。
- Spec 正本は `.kiro/specs/CommonModule/agent-service-manager/`。

## Tasks

- [x] 1. プロジェクト雛形と対象定義
  - [x] 1.1 WinForms プロジェクト作成（net8.0-windows・`UseWindowsForms`）＋ app.manifest（`requireAdministrator`）（2026/07/10）
    - 空の MainForm・エントリポイントのみ。ビルドが通る状態。
    - 作成: `\\...\WindowsService\AgentServiceManager\`（AgentServiceManager.csproj／Program.cs／MainForm.cs／app.manifest／.gitignore）。ビルド確認はユーザー。
    - _Requirements: 7.1, 9.1_
  - [x] 1.2 `AgentDescriptor` と2エージェントの定義（Smtp/Print・サービス名・既定binPath・テーブル/状態列）（2026/07/10）
    - `CommonSmtpAgent`/`CommonPrintAgent`・`t_smtp_queue.status`/`t_print_queue.print_status`・`m_*_agent_control`。
    - 作成: `Model/AgentDescriptor.cs`（record `AgentDescriptor`＋`AgentCatalog`（Smtp/Print/All））。
    - _Requirements: 1.1, 8.1_
  - [x] 1.3 `AppConfig`（appsettings.json 読込: CommonDb・RefreshInterval=5・ResponsiveThreshold=30・既定binPath）（2026/07/10）
    - 作成: `appsettings.json`（ConnectionStrings:CommonDb＝パスワードは `__SET_PASSWORD__` プレースホルダ・ユーザーが設定／Manager 節）＋`Model/AppConfig.cs`（`Load()`・欠落/不正は既定へフォールバック・`BinPathFor`）。csproj に Configuration 系パッケージ＋appsettings コピー設定。
    - _Requirements: 3.2, 5.2, 8.2_

- [x] 2. 純粋ロジック（I/O 非依存・PBT 対象）（2026/07/10）
  - [x] 2.1 `HeartbeatEvaluator.IsResponsive(nowUtc, lastUtc, thresholdSeconds)` を実装
    - `last==null→false`／`(now-last)<=threshold→true`／`>threshold→false`。境界=true・未来時刻=true・負しきい値は0扱い。`Logic/HeartbeatEvaluator.cs`。
    - _Requirements: 5.2, 5.3_
  - [x] 2.2 `QueueAggregator.Aggregate(statusValues)` → `QueueCounts`（1/2/3/9 集計）
    - `Logic/QueueAggregator.cs`。0=対象外 等は既知4カテゴリ外。`Model/QueueCounts.cs`。
    - _Requirements: 6.1, 6.2, 6.3_
  - [x] 2.3 `ServiceStateMapper.Map(status?)` → `AgentServiceState`（未登録=NotInstalled・全域・例外なし）
    - `Logic/ServiceStateMapper.cs`＋`Model/AgentServiceState.cs`。ServiceControllerStatus? を写像・null=NotInstalled・その他=Other。
    - _Requirements: 1.3, 3.1_
  - [x] 2.4 `OperationGuard`（Start は Stopped のみ可／Stop は Running のみ可／NotInstalled は不可＋理由）
    - `Logic/OperationGuard.cs`（`GuardResult`＋`CanStart`/`CanStop`）。
    - _Requirements: 2.1, 2.2, 2.4_

- [x] 3. サービス制御・登録アダプタ（I/O）（2026/07/10）
  - [x] 3.1 `ServiceControlService`（`ServiceController` で GetState/Start/Stop・タイムアウト待機・未登録吸収）
    - `Services/ServiceControlService.cs`（`IServiceControlService`＋実装）。未登録は InvalidOperationException 吸収→NotInstalled。Start/Stop は WaitForStatus。
    - _Requirements: 2.1, 2.2, 2.3, 2.5, 3.1_
  - [x] 3.2 `ServiceInstallService`（sc.exe create+failure/delete・exe存在/既存チェック・既存スクリプトと同等）
    - `Services/ServiceInstallService.cs`（`IServiceInstallService`＋実装）。ArgumentList でインジェクション回避・create/description/failure(5秒×3)・uninstall は停止後 delete。
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 4. DB 読み取り（ハートビート/滞留件数）（2026/07/10）
  - [x] 4.1 `AgentStatusReader.ReadAsync`（heartbeat 1行取得＋状態列 GROUP BY 件数・読み取り専用）
    - `Services/AgentStatusReader.cs`（`IAgentStatusReader`＋実装）。Microsoft.Data.SqlClient（ADO.NET）で読み取りのみ。識別子を正規表現で防御検証。heartbeat は `HeartbeatEvaluator.IsResponsive` で判定。接続文字列未設定/接続不可/クエリ失敗は `AgentDbStatus.Unreachable`（例外を伝播させない・OperationCanceled は再throw）。csproj に Microsoft.Data.SqlClient 5.2.* 追加。
    - _Requirements: 5.1, 5.4, 6.1, 6.2, 8.3_

- [x] 5. UI（MainForm・統合表示・自動更新）（2026/07/10）
  - [x] 5.1 2エージェント行の表示（サービス状態・ハートビート・件数・操作ボタン）＋`AgentRowViewModel` 集約
    - `Model/AgentRowViewModel.cs`（状態/ハートビート/滞留の文言・操作可否）＋`MainForm` TableLayoutPanel で2行表示。
    - _Requirements: 1.1, 1.2, 1.3, 5.2, 5.3, 5.4, 6.3_
  - [x] 5.2 自動更新タイマー（既定5秒）＋手動更新。操作は async・実行中ボタン無効化→完了後再取得
    - `System.Windows.Forms.Timer`（RefreshIntervalSeconds）＋「更新」ボタン。操作は `Task.Run` で実行中 `_busy` によりボタン無効化→完了後 RefreshAll。
    - _Requirements: 2.3, 3.2, 3.3_
  - [x] 5.3 起動/停止/登録/解除ボタンの結線（OperationGuard 経由）＋エラー・非管理者・DB取得不可の表示
    - 起動/停止は `OperationGuard` 判定後実行／登録は `BinPathFor`／解除は確認ダイアログ。例外は status ラベル＋MessageBox。非管理者は起動時に警告表示。DB 取得不可は「取得不可」表示（制御は継続）。
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 4.1, 4.2, 7.2, 7.3, 8.3_

- [x] 6. プロパティテスト（`AgentServiceManager.Tests`・FsCheck 2.16.6）（2026/07/10・実行はユーザー）
  - [x]* 6.1 Property 1: `IsResponsive` の境界・単調性（now 固定で経過増→true→false・境界=true・null=false）
    - `HeartbeatEvaluatorPropertyTests.cs`。
    - _Requirements: 5.2, 5.3_
  - [x]* 6.2 Property 2: 件数集計の保存則（既知4状態合計+その他=総数・各状態件数一致）
    - `QueueAggregatorPropertyTests.cs`。
    - _Requirements: 6.1, 6.2, 6.3_
  - [x]* 6.3 Property 3: 状態マッピングの全域性（任意 status・未登録→NotInstalled・例外なし）
    - `ServiceStateMapperPropertyTests.cs`（＋既知値 Theory）。
    - _Requirements: 1.3, 3.1_
  - [x]* 6.4 Property 4: 操作ガード（Start=Stopped のみ/Stop=Running のみ/NotInstalled 不可）
    - `OperationGuardPropertyTests.cs`。
    - _Requirements: 2.1, 2.2, 2.4_

- [x] 7. チェックポイント（ユーザー・実機／ローカル）（2026/07/10・ビルド＋起動OK）
  - 管理者で起動→行表示を確認（ビルド/起動OK）。起動・停止・登録/解除・ハートビート/滞留・DB停止時「取得不可」継続は実環境で随時確認。
  - _Requirements: 1.1, 2.1, 2.2, 4.1, 4.2, 5.2, 6.1, 8.3_

- [ ] 8. リモート対応拡張（ローカル/リモート・複数ターゲット）【2026/07/10 スコープ拡張】
  - design「リモート対応の前提」「エージェント種別とターゲット」に基づき、ローカル限定から対象マシン指定（複数サーバ）へ拡張する。
  - [x] 8.1 `AgentTarget` 追加＋`AppConfig` を `Manager:Targets`（配列）対応（未設定は Smtp/Print@ローカルの2件・後方互換）＋appsettings.json に Targets 例（2026/07/10）
    - `Model/AgentTarget.cs`（IsLocal/MachineLabel）＋`AppConfig.Targets`（BuildTargets・Kind/Machine/BinPath）。appsettings に Targets 2件。
    - _Requirements: 8.1, 8.3, 10.3_
  - [x] 8.2 `IServiceControlService` に `machineName` 追加（空=ローカル／指定=`ServiceController(name, machine)`）（2026/07/10）
    - GetState/Start/Stop に machineName。未登録は InvalidOperationException 吸収→NotInstalled。到達不可(Win32Exception)は伝播→UI 行エラー。
    - _Requirements: 8.2, 10.2, 10.4_
  - [x] 8.3 `IServiceInstallService` に `machineName` 追加（`sc \\machine create/delete`・停止は `ServiceController(name, machine)`・exe 存在チェックはローカル時のみ）（2026/07/10）
    - `ServerToken(machine)`＝`\\machine`。Exists は `GetServices(machine)`。RunSc は server 先頭付与。
    - _Requirements: 8.2, 10.4, 4.4, 4.5_
  - [x] 8.4 `MainForm` をターゲット駆動へ（`Targets` から行生成・**対象マシン列**追加・行単位のリモートエラー表示で他行継続）（2026/07/10）
    - `AgentRowViewModel(AgentTarget)`＋列6化（対象マシン列）。操作は target.MachineName/BinPath を使用。GetState 失敗は当該行 Other＋status 表示で他行継続。
    - _Requirements: 1.1, 1.2, 10.2, 10.3_
  - [ ] 8.5 チェックポイント（ユーザー・リモート実機）: 別サーバの Common*Agent を起動/停止/登録/解除・到達不可/権限不足時に当該行のみエラーで他行継続
    - _Requirements: 8.2, 10.1, 10.2_

- [ ] 9. 実行時ターゲット編集（入力UI・保存）【2026/07/10 追加】
  - design「実行時ターゲット編集」に基づき、画面から対象の追加/除外と appsettings への保存を行う。
  - [x] 9.1 `IConfigWriter`/`ConfigWriter`（`System.Text.Json.Nodes` で `Manager:Targets` のみ差し替え保存・他ノード温存）（2026/07/10）
    - `Services/ConfigWriter.cs`。JsonNode で読み込み Manager:Targets を再構築して書き戻し（ConnectionStrings 温存）。
    - _Requirements: 11.4_
  - [x] 9.2 `MainForm` に対象追加パネル（種別 Combo＋マシン TextBox＋binPath TextBox＋「追加」）＋各行「一覧除外」＋`RebuildRows`（可変 `List<AgentTarget>`）（2026/07/10）
    - 上部 FlowLayoutPanel（種別/マシン/exeパス/追加/設定に保存）＋`_grid` 動的再構築＋各行「一覧除外」（サービス非削除）。
    - _Requirements: 11.1, 11.2, 11.3, 11.5, 11.6, 11.7_
  - [x] 9.3 「設定に保存」ボタン（現一覧を `ConfigWriter` で appsettings へ永続化）（2026/07/10）
    - `OnSaveTargets`→`_writer.SaveTargets(AppContext.BaseDirectory\appsettings.json, _targets)`。
    - _Requirements: 11.4_
  - [ ] 9.4 チェックポイント（ユーザー）: 追加→行表示/操作対象化・除外・保存→再起動後も反映
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

## Notes

- `*` 付き（6.1〜6.4）は任意 PBT。純粋ロジックは 2.x を先に実装してから 6.x で検証する。
- I/O（ServiceController/sc.exe/実DB/実サービス）を伴う確認は 7（ユーザー・実サーバ）。CI 自動化は対象外。
- 新規独立プロジェクトのため他モジュールに影響しない。コミットは当該プロジェクトの配置先 repo 方針に従う（ユーザー）。

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["3.1", "3.2", "4.1", "6.1", "6.2", "6.3", "6.4"] },
    { "id": 3, "tasks": ["5.1"] },
    { "id": 4, "tasks": ["5.2", "5.3"] },
    { "id": 5, "tasks": ["8.1"] },
    { "id": 6, "tasks": ["8.2", "8.3"] },
    { "id": 7, "tasks": ["8.4"] },
    { "id": 8, "tasks": ["7", "8.5", "9.1"] },
    { "id": 9, "tasks": ["9.2"] },
    { "id": 10, "tasks": ["9.3", "9.4"] }
  ]
}
```
