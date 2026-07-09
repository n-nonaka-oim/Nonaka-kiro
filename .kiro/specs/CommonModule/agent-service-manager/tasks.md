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

- [ ] 1. プロジェクト雛形と対象定義
  - [ ] 1.1 WinForms プロジェクト作成（net8.0-windows・`UseWindowsForms`）＋ app.manifest（`requireAdministrator`）
    - 空の MainForm・エントリポイントのみ。ビルドが通る状態。
    - _Requirements: 7.1, 9.1_
  - [ ] 1.2 `AgentDescriptor` と2エージェントの定義（Smtp/Print・サービス名・既定binPath・テーブル/状態列）
    - `CommonSmtpAgent`/`CommonPrintAgent`・`t_smtp_queue.status`/`t_print_queue.print_status`・`m_*_agent_control`。
    - _Requirements: 1.1, 8.1_
  - [ ] 1.3 `AppConfig`（appsettings.json 読込: CommonDb・RefreshInterval=5・ResponsiveThreshold=30・既定binPath）
    - _Requirements: 3.2, 5.2, 8.2_

- [ ] 2. 純粋ロジック（I/O 非依存・PBT 対象）
  - [ ] 2.1 `HeartbeatEvaluator.IsResponsive(nowUtc, lastUtc, thresholdSeconds)` を実装
    - `last==null→false`／`(now-last)<=threshold→true`／`>threshold→false`。
    - _Requirements: 5.2, 5.3_
  - [ ] 2.2 `QueueAggregator.Aggregate(statusValues)` → `QueueCounts`（1/2/3/9 集計）
    - _Requirements: 6.1, 6.2, 6.3_
  - [ ] 2.3 `ServiceStateMapper.Map(status?)` → `AgentServiceState`（未登録=NotInstalled・全域・例外なし）
    - _Requirements: 1.3, 3.1_
  - [ ] 2.4 `OperationGuard`（Start は Stopped のみ可／Stop は Running のみ可／NotInstalled は不可＋理由）
    - _Requirements: 2.1, 2.2, 2.4_

- [ ] 3. サービス制御・登録アダプタ（I/O）
  - [ ] 3.1 `ServiceControlService`（`ServiceController` で GetState/Start/Stop・タイムアウト待機・未登録吸収）
    - _Requirements: 2.1, 2.2, 2.3, 2.5, 3.1_
  - [ ] 3.2 `ServiceInstallService`（sc.exe create+failure/delete・exe存在/既存チェック・既存スクリプトと同等）
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [ ] 4. DB 読み取り（ハートビート/滞留件数）
  - [ ] 4.1 `AgentStatusReader.ReadAsync`（heartbeat 1行取得＋状態列 GROUP BY 件数・`AsNoTracking`）
    - DB 接続不可は `DbReachable=false` で返し例外を伝播させない。
    - _Requirements: 5.1, 5.4, 6.1, 6.2, 8.3_

- [ ] 5. UI（MainForm・統合表示・自動更新）
  - [ ] 5.1 2エージェント行の表示（サービス状態・ハートビート・件数・操作ボタン）＋`AgentRowViewModel` 集約
    - _Requirements: 1.1, 1.2, 1.3, 5.2, 5.3, 5.4, 6.3_
  - [ ] 5.2 自動更新タイマー（既定5秒）＋手動更新。操作は async・実行中ボタン無効化→完了後再取得
    - _Requirements: 2.3, 3.2, 3.3_
  - [ ] 5.3 起動/停止/登録/解除ボタンの結線（OperationGuard 経由）＋エラー・非管理者・DB取得不可の表示
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 4.1, 4.2, 7.2, 7.3, 8.3_

- [ ] 6. プロパティテスト（`AgentServiceManager.Tests`・FsCheck 2.16.6）
  - [ ]* 6.1 Property 1: `IsResponsive` の境界・単調性（now 固定で経過増→true→false・境界=true・null=false）
    - _Requirements: 5.2, 5.3_
  - [ ]* 6.2 Property 2: 件数集計の保存則（既知4状態合計+その他=総数・各状態件数一致）
    - _Requirements: 6.1, 6.2, 6.3_
  - [ ]* 6.3 Property 3: 状態マッピングの全域性（任意 status・未登録→NotInstalled・例外なし）
    - _Requirements: 1.3, 3.1_
  - [ ]* 6.4 Property 4: 操作ガード（Start=Stopped のみ/Stop=Running のみ/NotInstalled 不可）
    - _Requirements: 2.1, 2.2, 2.4_

- [ ] 7. チェックポイント（ユーザー・実機）
  - 管理者で起動→2行表示／`dotnet run` の Agent または登録済みサービスに対し 起動・停止・状態遷移・ハートビート「ポーリング中/応答なし」・滞留件数・登録/解除・DB停止時の「取得不可」継続 を確認。
  - _Requirements: 1.1, 2.1, 2.2, 4.1, 4.2, 5.2, 6.1, 8.3_

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
    { "id": 5, "tasks": ["7"] }
  ]
}
```
