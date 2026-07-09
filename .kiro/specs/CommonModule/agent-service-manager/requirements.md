# Requirements Document

## Introduction

CommonModule プラットフォームの2つの常駐 Windows サービス（`CommonSmtpAgent`・`CommonPrintAgent`）を、運用担当者が1画面で**起動・停止・登録/解除・状態把握**できるようにする Windows デスクトップ管理アプリ（`agent-service-manager`）を定義する。

- UI 技術: **WinForms（.NET 8）**。
- 対象範囲: **ローカルマシン限定**（アプリが動作するサーバ自身のサービスと、そのサーバから見た共通DB `db_common_dev` を対象とする。リモートサーバ集中管理は対象外）。
- 管理対象サービス: `CommonSmtpAgent`・`CommonPrintAgent`（`sc.exe`/`ServiceController` 名）。
- 状態は2系統を統合表示する: (a) Windows サービス状態（`ServiceController`）、(b) DB ハートビート（`m_smtp_agent_control`/`m_print_agent_control`）＋キュー滞留件数（`t_smtp_queue`/`t_print_queue`）。
- サービス制御・登録には**管理者権限（昇格）**が必要。

## Glossary

- **サービス状態**: Windows サービスマネージャ上の状態（Running/Stopped/未登録 等）。
- **ハートビート**: 各 Agent がポーリング毎に更新する `m_*_agent_control.last_heartbeat_at`（UTC）。
- **応答しきい値**: ハートビートが「応答なし」と判定されるまでの経過秒数（既定 30 秒）。
- **滞留件数**: キューの待機(status/print_status=1)等の状態別件数。
- **登録/解除**: Windows サービスとしての install（`New-Service`/`sc create`）/uninstall（stop+`sc delete`）。

## Requirements

### Requirement 1: 対象サービスの一覧表示

**User Story:** 運用担当者として、2つの Agent の状態を1画面で見たい。個別にサービスマネージャを開かずに済むように。

#### Acceptance Criteria
1. THE アプリ SHALL 起動時に `CommonSmtpAgent` と `CommonPrintAgent` の行を一覧表示する。
2. THE アプリ SHALL 各行に「サービス名・サービス状態・ハートビート状態・滞留件数・操作ボタン」を表示する。
3. WHERE サービスが未登録である場合、THE アプリ SHALL 当該行のサービス状態を「未登録」と表示する。

### Requirement 2: サービスの起動・停止

**User Story:** 運用担当者として、画面のボタンで Agent を起動・停止したい。

#### Acceptance Criteria
1. WHEN 起動ボタンが押され対象サービスが停止中である場合、THE アプリ SHALL 当該サービスを開始する。
2. WHEN 停止ボタンが押され対象サービスが実行中である場合、THE アプリ SHALL 当該サービスを停止する。
3. WHILE サービス制御の完了を待つ間、THE アプリ SHALL 状態遷移（開始中/停止中）が分かる表示を行い、完了後に最新状態へ更新する。
4. IF 対象サービスが未登録である場合、THEN THE アプリ SHALL 起動/停止を実行せずメッセージを表示する。
5. IF 制御が既定時間内に完了しない、または失敗した場合、THEN THE アプリ SHALL エラー内容を表示し、行の状態を最新化する。

### Requirement 3: サービス状態の表示と自動更新

**User Story:** 運用担当者として、常に最新の状態を見たい。手動更新の手間なく。

#### Acceptance Criteria
1. THE アプリ SHALL `ServiceController` により各サービスの状態（Running/Stopped/StartPending/StopPending/未登録）を取得し表示する。
2. THE アプリ SHALL 一定間隔（既定 5 秒）で状態・ハートビート・滞留件数を自動更新する。
3. THE アプリ SHALL 手動更新（再取得）操作を提供する。

### Requirement 4: サービスの登録・解除（install/uninstall）

**User Story:** 運用担当者として、初回導入やメンテ時にこの画面からサービスを登録・解除したい。

#### Acceptance Criteria
1. WHEN 登録操作が実行された場合、THE アプリ SHALL 指定した実行ファイルパスで対象サービスを自動起動として登録する。
2. WHEN 解除操作が実行された場合、THE アプリ SHALL 対象サービスを停止してから削除する。
3. THE アプリ SHALL 登録時の実行ファイルパスを入力/選択できる手段を提供する（既定値は規約パス）。
4. IF 登録対象の実行ファイルが存在しない場合、THEN THE アプリ SHALL 登録を実行せずメッセージを表示する。
5. IF 登録しようとしたサービスが既に存在する場合、THEN THE アプリ SHALL 二重登録せずメッセージを表示する。
6. THE アプリ SHALL 各 Agent リポジトリの `install-service.ps1`/`uninstall-service.ps1` と同等の登録内容（自動起動・障害時再起動）を満たす。

### Requirement 5: ハートビート状態の表示

**User Story:** 運用担当者として、サービスが起動しているだけでなく実際にポーリング動作しているかを見たい。

#### Acceptance Criteria
1. THE アプリ SHALL 共通DB（`db_common_dev`）の `m_smtp_agent_control`/`m_print_agent_control` から最新の `last_heartbeat_at`（UTC）と `machine_name` を取得する。
2. WHEN 現在時刻と `last_heartbeat_at` の差が応答しきい値（既定 30 秒）以内である場合、THE アプリ SHALL 「ポーリング中」と表示する。
3. IF 差が応答しきい値を超える、または `last_heartbeat_at` が未設定である場合、THEN THE アプリ SHALL 「応答なし」と表示する。
4. THE アプリ SHALL 最終ハートビート時刻をローカル時刻で併記する。

### Requirement 6: キュー滞留件数の表示

**User Story:** 運用担当者として、未処理・エラーの件数を把握したい。

#### Acceptance Criteria
1. THE アプリ SHALL `t_smtp_queue.status` 別件数（待機1/処理中2/完了3/エラー9）を集計し SmtpAgent 行に表示する。
2. THE アプリ SHALL `t_print_queue.print_status` 別件数（待機1/処理中2/完了3/エラー9）を集計し PrintAgent 行に表示する。
3. THE アプリ SHALL 少なくとも「待機」「エラー」の件数を明示する。

### Requirement 7: 管理者権限（昇格）

**User Story:** 運用担当者として、権限不足で操作が中途半端に失敗する事態を避けたい。

#### Acceptance Criteria
1. THE アプリ SHALL 管理者として実行されることを前提とする（マニフェストで昇格要求）。
2. IF 管理者権限なしで起動された場合、THEN THE アプリ SHALL その旨を表示する（または昇格を要求する）。
3. THE アプリ SHALL サービス制御・登録/解除の失敗（権限起因を含む）をエラーとして表示する。

### Requirement 8: ローカル限定・接続前提

**User Story:** 運用担当者として、対象がこのサーバのサービスと DB であることを明確にしたい。

#### Acceptance Criteria
1. THE アプリ SHALL 制御対象をローカルマシンのサービスに限定する（リモート制御は行わない）。
2. THE アプリ SHALL 共通DB 接続文字列を設定（`appsettings.json` 等）から読み込む。
3. IF DB へ接続できない場合、THEN THE アプリ SHALL ハートビート/滞留件数を「取得不可」と表示し、サービス制御機能は継続して利用可能とする。

### Requirement 9: 変更範囲・非目標

**User Story:** 開発者として、この管理アプリの責務境界を明確にしたい。既存の Agent や監視画面の役割と重複・干渉しないように。

#### Acceptance Criteria
1. THE アプリ SHALL 新規の独立プロジェクト（WinForms・.NET 8）として作成し、Agent 本体（SmtpAgent/PrintAgent）のコード・DB スキーマを変更しない。
2. THE 本 spec SHALL リモートサーバ集中管理・キュー行単位の再送/削除（それは監視画面 `/Common/*Monitor` の役割）・ログビューアを対象外とする。
3. THE アプリ SHALL MainWeb・AuthModule・SharedCore を参照/変更しない。
