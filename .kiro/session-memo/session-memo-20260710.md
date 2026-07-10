# セッション備忘録（2026/07/10）

前日（20260709）＝CommonModule レイアウト/命名確定・Agent サービス名 Common 化＋install/uninstall スクリプト・SmtpAgent spec 整合・新規 spec `agent-service-manager`（req/design/tasks）作成、全コミット済み（push はユーザー）。本日は agent-service-manager の実装着手。

## agent-service-manager 実装着手（tasks 1.1 完了）

### 配置（確定 a）
- `\\OJIADM23120073\Labs\WindowsService\AgentServiceManager`（新規・net8.0-windows・WinForms・独立予定）。dotnet SDK 10.0.301 確認。

### tasks 1.1 完了（WinForms 雛形＋管理者昇格 manifest）
- 作成物：
  - `AgentServiceManager.csproj`（OutputType=WinExe／net8.0-windows／UseWindowsForms／ApplicationManifest=app.manifest）
  - `app.manifest`（`requireAdministrator`・Win10/11 互換宣言）
  - `Program.cs`（`ApplicationConfiguration.Initialize()` → `Application.Run(new MainForm())`）
  - `MainForm.cs`（空フォーム雛形・タイトル/サイズのみ）
  - `.gitignore`（bin/obj/.vs 等）
- ビルドは**ユーザー側実施**（project-rules: Kiro からビルド実行しない）。

### ⏳ ユーザー
- `dotnet build`（または VS）で雛形ビルド確認。
- 新規 git repo 化（`git init`＋remote）はユーザー方針で。まだ未初期化。

### tasks 1.2 完了（AgentDescriptor＋2エージェント定義）
- `Model/AgentDescriptor.cs`：record `AgentDescriptor`（DisplayName/ServiceName/DefaultBinPath/HeartbeatTable/QueueTable/QueueStatusColumn）＋`AgentCatalog`（Smtp=CommonSmtpAgent/status・Print=CommonPrintAgent/print_status・All）。

### tasks 1.3 完了（AppConfig）＝task 1 完了
- `appsettings.json`：`ConnectionStrings:CommonDb`（**パスワードは `__SET_PASSWORD__` プレースホルダ＝ユーザーが実値設定**。Agent の CommonDb と同一でよい）＋`Manager`（RefreshIntervalSeconds=5／ResponsiveThresholdSeconds=30／Smtp・PrintBinPath）。
- `Model/AppConfig.cs`：`Load()`（欠落/不正は既定へフォールバック・DB未設定は null）＋`BinPathFor(descriptor)`。
- csproj：Microsoft.Extensions.Configuration(.Json/.Binder) 8.0.* 追加＋appsettings.json を PreserveNewest でコピー。

### ⚠ ユーザー
- `appsettings.json` の `CommonDb` パスワードを実値に設定（Agent の appsettings と同じ db_common_dev 接続で可）。機密のためコミット時は取り扱い注意。

### tasks 2 完了（純粋ロジック 2.1〜2.4・I/O 非依存・PBT 対象）
- DTO/enum：`Model/AgentServiceState.cs`（NotInstalled/Running/Stopped/StartPending/StopPending/Other）・`QueueCounts`・`HeartbeatInfo`・`AgentDbStatus`。
- `Logic/HeartbeatEvaluator.IsResponsive`（null=false・境界=true・未来=true・負threshold=0）。
- `Logic/QueueAggregator.Aggregate`（1/2/3/9 集計・その他除外）。
- `Logic/ServiceStateMapper.Map(ServiceControllerStatus?)`（null=NotInstalled・全域・例外なし）。csproj に `System.ServiceProcess.ServiceController` 8.0.* 追加。
- `Logic/OperationGuard`（`GuardResult`＋CanStart=Stopped のみ/CanStop=Running のみ/未登録は不可＋理由）。

### tasks 3 完了（I/O アダプタ）
- `Services/ServiceControlService.cs`（`IServiceControlService`＋実装。GetState=ServiceStateMapper・未登録吸収／Start=停止中のみ開始→WaitForStatus(Running)／Stop=実行中のみ→WaitForStatus(Stopped)）。
- `Services/ServiceInstallService.cs`（`IServiceInstallService`＋実装。Install=exe存在＋既存チェック→sc create(start=auto)+description+failure(5秒×3)／Uninstall=停止後 delete。sc.exe は ArgumentList でインジェクション回避）。

### tasks 4 完了（DB 読み取り）
- `Services/AgentStatusReader.cs`（`IAgentStatusReader`＋実装）。Microsoft.Data.SqlClient（ADO.NET）読み取り専用。heartbeat 1行（last_heartbeat_at/machine_name）＋状態列 GROUP BY 件数→QueueCounts。`HeartbeatEvaluator` で応答判定。識別子は正規表現で防御検証。接続文字列未設定/接続不可/クエリ失敗は `AgentDbStatus.Unreachable`（OperationCanceled は再throw）。csproj に Microsoft.Data.SqlClient 5.2.*。

### tasks 5 完了（UI・MainForm）
- `Model/AgentRowViewModel.cs`：状態/ハートビート/滞留の文言化＋操作可否（CanStart/Stop/Install/Uninstall）。
- `MainForm.cs` 本実装：TableLayoutPanel で2行（名称/状態/ハートビート/滞留/操作4ボタン）。自動更新タイマー（RefreshIntervalSeconds・既定5秒）＋「更新」ボタン。操作は `Task.Run`＋`_busy` でボタン無効化→完了後 RefreshAll。起動/停止は OperationGuard 判定・登録は BinPathFor・解除は確認ダイアログ。例外は status ラベル＋MessageBox。非管理者は警告表示。DB 取得不可は「取得不可」表示で制御継続。サービス/登録/DB を DI 無しで直接生成。

### tasks 6 完了（任意PBT・`AgentServiceManager.Tests` 新設）
- csproj（net8.0-windows・UseWindowsForms・FsCheck 2.16.6・xunit）＋ProjectReference→AgentServiceManager。
- `HeartbeatEvaluatorPropertyTests`（P1・境界/単調/null）／`QueueAggregatorPropertyTests`（P2・保存則）／`ServiceStateMapperPropertyTests`（P3・全域＋既知値 Theory）／`OperationGuardPropertyTests`（P4・遷移整合/未登録不可）。
- 実行はユーザー（`dotnet test AgentServiceManager.Tests`）。

### 実装ステータス
- **tasks 1〜6 完了**（コア実装＋PBT）。残＝7 実機CP（ユーザー）。

### ⏳ ユーザー
- `dotnet build`（AgentServiceManager）済み=OK。`dotnet test AgentServiceManager.Tests` でPBTグリーン確認。
- `appsettings.json` の CommonDb パスワード設定。7 実機確認（管理者起動→表示/起動停止/登録解除/ハートビート/DB停止時「取得不可」）。

### 次アクション
- 7 実機CP（ユーザー）。その後コミット（AgentServiceManager／.Tests は各 git 方針・Nonaka/.kiro spec/memo）。

---

## スコープ拡張：リモート対応（ユーザー選択 c）＋実装 8.1〜8.4

### 経緯
- 「ローカルで起動OK＝サーバサイド制御可能か？」→ 現状ローカル限定（ServiceController はローカル対象）。ユーザーが **c（リモート対応まで拡張）** を選択。

### spec 改訂（req/design/tasks・直接編集・全診断クリア）
- requirements：ローカル限定→ローカル+リモート（複数サーバ）。R8 を対象サーバ（マシン指定）に、**R10 新設**（リモート前提＝対象マシン管理者権限・RPC到達・FW許可／到達不可は当該行エラーで継続／対象マシン名表示／`sc \\machine`）。非目標からリモート集中管理を削除。
- design：`AgentTarget`（種別＋対象マシン＋binPath）・`Manager:Targets` 設定・`IServiceControlService`/`IServiceInstallService` に machineName・リモートエラー処理・UI 対象マシン列。
- tasks：**task 8**（8.1〜8.5）追加＋依存グラフ更新。

### 実装（tasks 8.1〜8.4 完了・8.2〜8.4 は 8.1 と連動のため一括）
- `Model/AgentTarget.cs`（IsLocal/MachineLabel）。`AppConfig.Targets`（`Manager:Targets`：Kind/Machine/BinPath・未設定は Smtp/Print@ローカル2件・後方互換）＋appsettings に Targets。
- `ServiceControlService`：GetState/Start/Stop に machineName（ローカル/リモート ServiceController 切替）。未登録吸収・到達不可は伝播。
- `ServiceInstallService`：Install/Uninstall に machineName（`sc \\machine`・Exists は GetServices(machine)・exe 存在チェックはローカルのみ）。
- `AgentRowViewModel(AgentTarget)`＋`MainForm` を Targets 駆動・**対象マシン列**追加・操作は target の machine/binPath・GetState 失敗は当該行 Other＋status で他行継続。

### ⚠ ユーザー
- `dotnet build`（AgentServiceManager）＋`dotnet test`（.Tests）確認。
- リモート利用時：appsettings の Targets に `"Machine": "サーバ名"` を設定。対象マシンの管理者権限・RPC/FW（リモートサービス管理）許可が前提。
- 8.5 リモート実機CP（別サーバの Common*Agent を起動/停止/登録/解除・到達不可時に当該行のみエラーで継続）。

### 実装ステータス（更新）
- **tasks 1〜6＋7＋8.1〜8.4 完了**（コア＋PBT＋リモート拡張＋ローカルCP：ビルド/起動OK）。
- 残＝**8.5 リモート実機CP**（別サーバの Common*Agent 制御・到達不可時の行単位継続）＝ユーザー（要リモート機）。

### コミット（未実施・次アクション）
- `AgentServiceManager`／`AgentServiceManager.Tests` は**新規フォルダで git 未初期化**（配置 a＝新規 repo 予定）。→ ユーザー方針で `git init`＋remote 後に初回コミット、or 既存 WindowsService 運用に合わせる。
- `Nonaka/.kiro`：agent-service-manager spec（req/design/tasks 改訂）＋session-memo(20260710) をコミット。

### コミット済み（2026/07/10）
- Nonaka/.kiro `c202af9`（agent-service-manager spec リモート改訂＋memo）。
- AgentServiceManager 新規 repo 初期化＋初回コミット `77b3ef1`（23ファイル・push なし・remote 未設定）。※`AgentServiceManager.sln`/`.github` はユーザー生成分も含む。
- AgentServiceManager.Tests は git 未管理のまま（WindowsService 配下テストの慣例）。

---

## task 9 追加：実行時ターゲット編集（入力UI・保存）＝ユーザー選択 b

### 経緯
- 「リモートはサーバ情報入力テキストボックス？」→ 現状は appsettings 駆動。ユーザーが **b（画面から入力・追加/除外・保存）** を選択。

### spec 改訂（診断クリア）
- requirements：**R11 新設**（実行時に種別/マシン/exeパス入力で追加・一覧除外・appsettings 保存・既定フォールバック）。
- design：実行時ターゲット編集（入力UI）＋`IConfigWriter`＋MainForm 再構築方式。
- tasks：**task 9**（9.1 ConfigWriter／9.2 入力UI＋動的行＋一覧除外／9.3 保存／9.4 CP）＋依存グラフ更新。

### 実装（9.1〜9.3 完了）
- `Services/ConfigWriter.cs`（`IConfigWriter`）：JsonNode で `Manager:Targets` のみ差し替え保存・ConnectionStrings 温存。
- `MainForm` 改修：上部に対象追加パネル（種別 Combo/マシン/exeパス/追加/設定に保存）、`_grid` を可変 `List<AgentTarget>` から `RebuildRows` で再構築、各行「一覧除外」（サービス非削除）。保存は `AppContext.BaseDirectory\appsettings.json`。

### ⚠ ユーザー
- `dotnet build` 確認。9.4 CP：追加→行表示/操作対象化・一覧除外・「設定に保存」→再起動後も反映（保存先は実行フォルダの appsettings.json＝publish 済み配置で永続。`dotnet run` 時は bin 配下で再ビルドで上書きされる点に注意）。
- 追加コミット（AgentServiceManager：ConfigWriter/MainForm 更新／Nonaka/.kiro：spec/memo）。

### 実装ステータス（更新）
- tasks 1〜7・8.1〜8.4・9.1〜9.3 完了。残＝8.5（リモート実機CP）・9.4（入力UI CP）＝ユーザー。

### 追補：対象マシン名 正規化（自機/localhost/UNC→ローカル）
- 事象：リモート欄に自機名 `OJIADM23120073` を入力 → `Cannot open Service Control Manager on computer 'OJIADM23120073'`（リモート SCM 経路になり追加権限要求）。UNC 入力は不要（bare 名でよい）。
- 対応：`Logic/MachineNameNormalizer.Normalize(input, localMachineName)`（純粋）追加。先頭 `\\` 除去・`.`/`localhost`/自機名→null（ローカル扱い＝ローカル SCM 経路）。`MainForm.OnAddTarget`／`AppConfig.BuildTargets` に適用。machine 欄プレースホルダを「空/自機名=ローカル」に。
- テスト：`AgentServiceManager.Tests/MachineNameNormalizerTests.cs`（自機/localhost/UNC→null・リモート名 trim）。
- 真のリモート制御の前提（変わらず）：対象サーバの**管理者権限**＋**ファイアウォールで「リモート サービス管理(RPC)」許可**。自機は空欄/自機名でローカル動作。

### ⚠ ユーザー（再確認）
- 再ビルド → 自機名入力でもローカルとして動作するはず。別サーバ名は上記前提が満たされれば制御可能。
- 追加コミット（MainForm/AppConfig/新規 Normalizer＋Tests・Nonaka/.kiro memo）。

### リモート/ローカル実機トラブルシュート → 解決（CP 8.5/9.4 完了）
実機確認で判明した事象と解決:
1. リモートで「Cannot open SCM 'OJIADM23120073' … other privileges」→ 権限。ドメイン構成なので **d86223 を対象機ローカル Administrators に追加**＋クライアントで**管理者昇格実行**で解決（`sc.exe \\server query type= service` が列挙成功＝権限OKを確認）。UNC 入力は不要（bare 名。自機名/localhost/`\\`は正規化でローカル扱い）。
2. ローカル起動 5（アクセス拒否）→ 非昇格。管理アプリは manifest で requireAdministrator だが `dotnet run`/非昇格 VS では昇格されない。exe 直接起動 or 管理者で実行。
3. ローカル起動 1053（応答なし）→ 直接実行で `SmtpAgent.dll not found`/`runtimeconfig.json not found`。**配置先に exe 単体しか無い＝発行物不完全**が真因。`dotnet publish -c Release -o C:\SmtpAgent\App`（一式）で解決 → START_PENDING→RUNNING 確認。
- docs 反映: PrintAgent/SmtpAgent `spec.md` に「トラブルシュート」（1053/5/SCM/1060）追記。

### PowerShell 注意
- PS では `sc` が `Set-Content` エイリアス。サービス操作は `sc.exe` を使う。

### 実装ステータス（最終）
- **agent-service-manager：tasks 全完了**（1〜9・7/8.5/9.4 の実機CP含む・サーバ/ローカル OK）。spec クローズ可。

### 本日コミット（追記）
- Nonaka/.kiro `c202af9`/`4a78275`（既）＋本追記分（tasks 完了・memo）。
- AgentServiceManager `77b3ef1`/`3bc9267`（既）＋本追記分（MachineNameNormalizer・MainForm ヒント・AppConfig 正規化）。
- PrintAgent/SmtpAgent：spec.md トラブルシュート追記（各 repo）。
- ※AgentServiceManager.Tests は git 管理外の慣例（MachineNameNormalizerTests も同様）。

### 再開合図（更新）
「再開します、session-memoを確認」。最新は本ファイル（20260710）。agent-service-manager は実装・実機確認 完了。次テーマは未定。

### 運用メモ（継続）
- spec は直接編集（サブエージェント不使用）。1ターン1タスク。ビルド/テストはユーザー。MainWeb/AuthModule/SharedCore 不変更。
- AgentServiceManager は他モジュール参照なし・DB(db_common_dev) は読み取りのみ。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260710）。次アクション＝tasks 1.2（AgentDescriptor）。

---

## 配置方針の確認：PrintAgent＋SumatraPDF はオンプレ同梱（クラウド移行時も）

- SumatraPDF＝PDF「印刷」ツール（生成は QuestPDF・クラウド可）。サイレント印刷はオンプレプリンタ対象。
- 決定：**PrintAgent と SumatraPDF は同一オンプレ機（プリンタ到達可）に同梱設置**。`SumatraPdfPath` はその機のローカルパス。Web/DB を AWS 化しても PrintAgent＋SumatraPDF はオンプレ据置（`t_print_queue` は DB 共有＝投入がクラウドでも PrintAgent がオンプレでポーリング印刷）。Linux クラウドでは SumatraPDF 不可。
- docs 反映：`PrintAgent/docs/spec.md` 前提準備に「配置方針」注記。ユーザーは PrintAgent とリンクして管理する方針。
