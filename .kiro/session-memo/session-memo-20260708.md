# セッション備忘録（2026/07/08）

前日（07/07）の送信元マスタ化検討の続き。本日はテスト送信の設計方針を確定（実装は未着手）。

## 引継ぎ状態
- FAX新仕様（config_key 3モード）は実装・テスト移行・docs 完了・コミット済み。動作確認フェーズ。
- 動作確認: sample SQL の @output_type=1（印刷のみ）だと SmtpMonitor 空が正しい。FAX検証は output_type=2/3。
- 07/07: 送信元マスタ化のベストプラクティス検討。ApplicationUser に Email＋FaxNumber(fax_number) 既存を確認。

## 🔴 本日の確定事項（テスト送信の再設計・要件）
ユーザー決定:
1. **recipient 上書き方式へ切替**（先日実装の「test-fax 固定アドレスを Agent が宛先無視で使う」方式は**取り下げ**）。
2. **送信元 From は固定のシステムアドレス**（本番・テスト共通・個人アドレスにしない）。
3. マスタ・管理画面は **CommonModule 側**（全社共通基盤）に配置。
4. **Mail テストを含める**（FAX・Mail 両対応）。
5. テスト宛先は**固定だが DBマスタで可視・編集可**（開発担当変更による属人化を回避）。**常駐テストレコードは廃案**（t_smtp_queue/t_orders への常駐はしない）。テストは都度・使い捨て。
6. テスト目的は **(a) Agent単体疎通 と (b) 上流〜下流全経路の両方**。

## 設計方針（確定・詳細は spec で）
- **新規「送信設定マスタ」（CommonModule・db_common_dev）**＋**管理画面**（Area Common・DbPermissionCheck）:
  - `from_address`（送信元・本番/テスト共通のシステムアドレス）
  - `test_fax_number`（テストFAX宛先・固定・編集可）
  - `test_email`（テストメール宛先・固定・編集可）
  - row_version＋監査列。1行運用（将来複数化余地）。
- **投入ロジック**:
  - From = マスタ from_address（ハードコード `FaxDispatchOptions.FromAddress` は廃止）。
  - テストON: recipient をマスタのテスト宛先へ上書き（FAX→config_key `fax`＋test_fax_number／Mail→config_key `mail`＋test_email）。テスト宛先未設定→エラー。
  - 本番: recipient=実宛先（destination_fax 等）。
- **両経路テスト**:
  - (b) 上流〜下流: 承認画面「FAXテスト送信」チェック → recipient をマスタのテスト宛先に。使い捨て発注（sample SQL）で都度。
  - (a) Agent疎通: 管理画面に「テスト送信」ボタン → 使い捨てジョブ1件をマスタ宛先へ enqueue（常駐なし）。or t_smtp_queue 直接INSERT。

## ⚠ 手戻り（spec 再改訂が必要）
- **smtp-sender**: test-fax（固定アドレス・IsFullAddress 分岐）取り下げ。config_key は `mail`/`fax` の2モードへ（fax_domain: 空=メール直送/@始まりドメイン=FAX送信）。固定宛先モードの記述・Property・m_smtp_config test-fax 行を見直し。SmtpAgent ResolveToAddress の IsFullAddress 分岐は撤去 or 不使用化。
- **dispatch-monitoring-consolidation**: R10/Comp7/Prop4 の「config_key=test-fax 選定」を「config_key=fax/mail＋recipient をマスタのテスト宛先に上書き」へ改訂。FaxDispatchOptions は from をマスタ参照へ（or 廃止）。
- **新規 spec**: CommonModule「送信設定マスタ＋管理画面＋テスト送信」。Mail 送信経路（何を送るか）も要定義（Mail テスト含むため）。
- 既にコミット済みの実装（SmtpAgent 7435a26／MaterialModule 7bb1220／CommonModule dbfe065）から一部差し替え。

## 本日の実装（小規模単位・実装フェーズ着手）
- **Unit1**: 送信設定マスタ `m_send_config`（entity `MSendConfig`＋DbSet＋DDL `create_m_send_config.sql`）。列: id/from_address/test_fax_number/test_email/is_active/created_at/updated_at/row_version。1行運用・初期シード付き。→ CommonModule `f687e13`。
- **Unit2**: `ISendConfigService`/`SendConfigService`（is_active=1 の有効行を AsNoTracking で取得）＋ AddCommonModule に Scoped 登録。→ CommonModule `0d54cc5`。
- **Unit3**: `DispatchEnqueueService` を **recipient上書き方式**へ改修。
  - ISendConfigService 注入。送信元 from = マスタ from_address（無ければ FaxDispatchOptions.FromAddress フォールバック）。
  - config_key は常に `fax`（NormalConfigKey）。テスト時は recipient を `m_send_config.test_fax_number` へ上書き（未設定はスキップ+ログ）。本番は実FAX番号。
  - `FaxDispatchOptions.TestConfigKey` 廃止（test-fax 固定宛先方式・取り下げ）。dispatch_log は recipientForSend/config_key/testSend を記録。
  - → MaterialModule `ab31934`。診断クリア。
- **付随**: MaterialModule.Tests の DispatchEnqueue スイートが 10.2 リファクタ（IApprovalReportPdfProvider）以降 **compile 断**だった問題を、ハーネスに `StubApprovalReportPdfProvider`（既存 StubOrderPdfService をラップし GeneratedGroups/ThrowSelector 維持＋合成パス返却）＋`StubSendConfigService` を追加して解消。Property9 を新仕様（config_key常にfax・テスト時 recipient=マスタ test番号）に更新。※テスト .cs は git 管理外・ディスク上のみ・診断クリア。

## コミット（本日 07/08 実装分）
- CommonModule `f687e13`（m_send_config）・`0d54cc5`（ISendConfigService）。
- MaterialModule `ab31934`（DispatchEnqueue recipient上書き・FaxDispatchOptions整理）。
- ※テストハーネス修正は git 管理外。

## 残タスク（次回・優先順）
1. **Unit4: m_send_config 管理画面**（Common Area・閲覧/編集・DbPermissionCheck・row_version 楽観ロック）＝「可視化・属人化回避」の本体。
2. Mail テスト経路（config_key=mail＋test_email）と、管理画面の「単発テスト送信」ボタン（Agent疎通・使い捨て）。
3. Unit5: SmtpAgent の test-fax（IsFullAddress 固定宛先モード）撤去（任意・現状は未使用で無害）。
4. **spec 再改訂**: smtp-sender（test-fax 取り下げ・config_key は mail/fax の2モード）／dispatch（R10/Comp7/Prop4 を recipient上書き＋m_send_config に）／新規 spec（送信設定マスタ＋管理画面）。※実装先行のため spec 追随が必要。
5. ユーザー: `create_m_send_config.sql` 実行（db_common_dev）・slnCoCore ビルド・実FAX(本番/テスト)確認。

## 注意（未整合・要追随）
- 実装が spec 先行。smtp-sender/dispatch spec はまだ「test-fax 方式」記述のまま → 次回 spec 再改訂で整合させる。
- SmtpAgent は test-fax(IsFullAddress) が残存するが、投入側が test-fax config_key を使わなくなったため実害なし（撤去は任意）。

---

## 🔴 チェックポイント（コンテキスト80%・新セッション引継ぎ）

### 現在地（送信設定マスタ化＝Unit1-4 実装完了・コミット済み）
- **Unit4 管理画面まで完了**。「送信元・テスト宛先を画面で可視・編集（属人化回避）」の本体が動作。
- コミット（07/08）: CommonModule `f687e13`(m_send_config) / `0d54cc5`(ISendConfigService) / `30e9396`(管理画面 /Common/SendConfig＋register SQL)。MaterialModule `ab31934`(DispatchEnqueue recipient上書き)。Nonaka memo `97dab9c`。
- 管理画面: `CommonModule/Areas/Common/Pages/SendConfig/Index.cshtml(.cs)`。有効行(is_active=1)を1件編集/無ければ新規。EmailAddress 検証・row_version 楽観ロック（競合時「他のユーザーが先に更新しました。画面を再読み込みしてください。」）。

### 🟡 次アクション（新セッション・優先順）
1. **管理画面の「単発テスト送信」ボタン**（Agent疎通・使い捨て）: マスタ test_fax_number/test_email 宛に t_smtp_queue へ1件 enqueue（fax/mail）。常駐しない・ISmtpQueueService 経由。
2. **Mail テスト経路の位置づけ確定**（発注承認は FAX のみ。Mail は上記単発テスト送信で疎通、発注書メール送信機能化は別途）。
3. **spec 再改訂（実装先行の追随・重要）**: smtp-sender（test-fax取り下げ→mail/fax 2モード）／dispatch（R10/Comp7/Prop4 を config_key=fax＋recipientマスタ上書きに）／新規 spec（送信設定マスタ＋管理画面＋テスト送信）。
4. SmtpAgent test-fax(IsFullAddress) 撤去（任意・無害）。
5. **ユーザー実行**: `create_m_send_config.sql`(db_common_dev)＋`register_send_config_content.sql`(dbAuthTest) 実行・slnCoCore 再ビルド・/Common/SendConfig 編集確認・FAX承認テスト(output_type=2/3・「FAXテスト送信」ON→recipient=マスタ test_fax_number)。

### テスト（git管理外・ディスク上・診断クリア）
- MaterialModule.Tests ハーネスに StubApprovalReportPdfProvider（10.2 断解消）＋StubSendConfigService 追加。Property9 は config_key常にfax・テスト時 recipient=マスタ番号 に更新済。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260708）。次アクション＝**管理画面の単発テスト送信ボタン**→**spec 再改訂**。

## 🟡 次アクション（次回）
1. **新規 spec 起草**（CommonModule・送信設定マスタ＋管理画面＋テスト送信 recipient上書き・fax/mail）: requirements から。Mail 送信の対象（疎通のみ or 発注書メール送信機能）を requirements で確定。
2. smtp-sender / dispatch spec の再改訂（test-fax 取り下げ・recipient上書き方式へ）。
3. 実装差し替え（SmtpAgent の固定宛先モード撤去・投入側の from/テスト宛先マスタ参照・管理画面）。
4. 並行: FAX enqueue 実機検証（output_type=2/3）はユーザー継続（暫定は現行 test-fax でも可だが、上記改訂後に再確認）。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260708）。次アクション＝**CommonModule 送信設定マスタ＋テスト送信 recipient上書き方式の spec 起草（requirements）**。Mail 送信対象の定義から。


---

## ① spec 再改訂 着手：新規 spec `send-config-master` 3点作成（requirements/design/tasks）

- 経緯: session-memo が 20260702 まで遡って誤認されていたが、真の最新は本 20260708。実装が spec 先行のため「① spec 再改訂」を最優先で実施することにユーザー合意。
- 運用モード変更（ユーザー合意）: **重い自動処理（要件一括詳細化・アナライズ・並列サブエージェント）は行わない**。粒度は「1ターン=1成果物」。spec 改訂は外科的差分。各文書完了で memo に1行記録。
  - ⚠ ワークフロー用サブエージェント起動の直後に IDE が `i.map is not a function` でクラッシュする事象が2回連続で再現（ファイルは毎回無事）。→ **以後サブエージェントを使わず直接編集（fs_write/str_replace）で進める**。
- **作成（単一正本 `.kiro/specs/CommonModule/send-config-master/`・全て診断クリア）**:
  - requirements.md（R1〜R8。R1〜R5・R8=実装済、R6 単発テスト送信ボタン=未実装、R7 Mailテスト経路=未実装）。※サブエージェントで作成（この後クラッシュ）。
  - design.md（実装忠実。recipient上書き方式・旧test-fax取り下げ明記・契約は dispatch 所有・未実装2点は設計方針のみ・Property1 有効行選択の決定性）。※サブエージェントで作成（この後クラッシュ）。
  - tasks.md（**直接編集で作成・クラッシュ無し**。1〜4=[x] 実装済文書化、5.1 単発テスト送信ボタン=未実装、6.1 Mailテスト経路=未実装、8.x 任意PBT。1.3 テーブル定義書追記のみ要確認）。

### 次アクション（① の続き・最小単位）
1. `send-config-master` の残実装（未実装）: 5.1 管理画面の単発テスト送信ボタン（FAX/Mail・使い捨て enqueue・ISmtpQueueService 経由）→ 6.1 Mail 分岐。※実装フェーズはユーザー確認後。
2. **②smtp-sender 再改訂**（外科的差分）: タスク15「test-fax 固定宛先3モード」→「mail/fax 2モード・recipient上書き」へ是正。SmtpAgent ResolveToAddress の IsFullAddress 分岐は撤去 or 不使用化を記述。
3. **③dispatch-monitoring-consolidation 再改訂**（外科的差分）: R10/Comp7/Prop4 の「config_key=test-fax 選定」→「config_key=fax＋recipient を m_send_config のテスト宛先に上書き」へ。FaxDispatchOptions.TestConfigKey 廃止を反映。
4. その後（印刷系カットオーバーの締め・独立）: dispatch 5.1/5.2（旧 Material 監視画面廃止）・6.1（導線解除SQL）・9.1（カットオーバーノート）。

### 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260708）。次アクション＝send-config-master 未実装(5.1/6.1) or ②smtp-sender 再改訂（外科的差分）。

---

## ① spec 再改訂 着手：新規 spec `send-config-master`（CommonModule）3点作成完了

- 実装先行だった「送信設定マスタ＋管理画面＋テスト送信（recipient 上書き方式）」を単一正本 spec 化。配置 `.kiro/specs/CommonModule/send-config-master/`。
- **requirements.md**（R1〜R8・EARS・各要件に実装状態明記）／**design.md**（実装忠実・診断クリア）／**tasks.md**（直接作成・診断クリア）。
- 実装済み＝R1 マスタ `m_send_config`／R2 `ISendConfigService`／R3 管理画面 `/Common/SendConfig`／R4-R5 投入側契約・承認画面FAXテスト送信。未実装＝**R6 管理画面「単発テスト送信」ボタン**・**R7 Mail テスト経路**・**tasks 2.1 テーブル定義書/ER図に m_send_config 追記**（grep 未反映を確認）・任意テスト（3.3/4.4/6.2）。
- ⚠ **IDE クラッシュ回避策**: spec ワークフロー用サブエージェント完了描画で `i.map is not a function` が再現（生成物は毎回無事）。以降は **spec ファイルを直接編集（fs_write/str_replace）** して回避する運用に切替。
- 運用モード合意: 重い自動処理（一括詳細化・アナライズ・並列サブエージェント）はオフ。粒度は「1ターン=1成果物」。spec 改訂は全文再生成せず外科的差分。

### 次アクション（① の続き・最小単位）
1. **smtp-sender 再改訂**（外科的差分）: task group 15「test-fax 固定宛先（3モード）」を取り下げ→ config_key は `mail`/`fax` の2モード・recipient 上書き方式に整合。
2. その後 **dispatch-monitoring-consolidation 再改訂**: R10/Comp7/Prop4 を「config_key=fax＋recipient=マスタ test_fax_number 上書き・From=m_send_config」に是正。
3. その後 印刷系残（dispatch 5.1/5.2 旧監視画面廃止・6.1 導線解除SQL・9.1 カットオーバーノート）。

---

## ② smtp-sender 再改訂 完了（外科的差分・test-fax 固定宛先方式の取り下げ注記）

- 方針=案1（本文残置＋改訂注記）。直接編集（str_replace）でクラッシュ回避。
- **requirements.md**: Glossary（config_key／固定宛先モード／テスト送信指定）・R2(AC6/AC7)・R6（見出し直下ノート）・R8（見出し直下＝本要件は取り下げ・AC1〜8 無効）・Non-Goals に「【改訂 2026/07/08】固定宛先(test-fax)取り下げ→recipient 上書き方式・正は send-config-master/dispatch」を注記。診断クリア。
- **design.md**: 冒頭に🔴改訂ノート1箇所（送信モードは mail/fax の2モード正・固定宛先は非推奨未使用・テストは recipient 上書き・test-fax 記述は履歴残置で無効）。診断クリア。
- **tasks.md**: task 15 見出しに改訂注記（15.1〜15.7 は `[x]` 維持・履歴。IsFullAddress/固定宛先分岐の撤去は任意）。診断クリア。
- コードは無改変（SmtpAgent の3モード実装は残存・無害。撤去は任意 Unit）。

### 次アクション（① の続き）
- **③ dispatch-monitoring-consolidation 再改訂**（外科的差分）: R10／Comp7／Prop4 の「config_key=test-fax 選定」を「config_key=fax＋recipient を m_send_config の test_fax_number に上書き・From=m_send_config.from_address」へ注記是正。※既に実装は recipient 上書き（`ab31934`）に移行済みのため spec 追随のみ。
- その後: 印刷系残（dispatch 5.1/5.2 旧監視画面廃止・6.1 導線解除SQL・9.1 カットオーバーノート）。

---

## ③ dispatch-monitoring-consolidation 再改訂 完了（外科的差分・recipient 上書き方式へ追随）＝① spec 再改訂 完了

- 発見: dispatch spec は「config_key=`fax`/`test-fax` 選定・`TestConfigKey`・宛先を上書きしない」という**中間版のまま**で、現行実装（Unit3 `ab31934`＝config_key 常に `fax`＋recipient を `m_send_config.test_fax_number` に上書き・From=`m_send_config.from_address`・`TestConfigKey` 廃止）と乖離していた。→ 注記で現行に追随。
- **requirements.md**: R10 見出し直下ノート（AC1/AC3/AC6 を読み替え・config_key 常に fax・recipient 上書き・From=マスタ）／Introduction 項6／Glossary（config_key・FAXテスト送信指定）に注記。診断クリア。
- **design.md**: 目標6／「### 7. config_key 選定」章見出し直下／**Property 4（意味が反転：旧「宛先を上書きしない」→現「テスト時 recipient を m_send_config.test_fax_number に上書き」＝Property 4' として再定義）** に注記。診断クリア。
- **tasks.md**: task 11 見出し／11.5 Property 4／Notes に注記（11.1〜11.4 `[x]` は履歴維持）。診断クリア。
- コード無改変（実装は既に recipient 上書き `ab31934`）。

### ① 完了サマリ（spec＝実装 に追随）
- 新規 `send-config-master`（requirements/design/tasks）作成。
- `smtp-sender` 改訂（test-fax 固定宛先方式 取り下げ→mail/fax 2モード・recipient 上書き注記）。
- `dispatch-monitoring-consolidation` 改訂（config_key 常に fax＋recipient を m_send_config へ上書き・From=マスタ・Property4 反転）。
- すべて直接編集（str_replace）＝IDE クラッシュ回避。全ファイル診断クリア。

### 次アクション候補
1. `send-config-master` 未実装の残実装：tasks 5.1 管理画面「単発テスト送信」ボタン（FAX/Mail・使い捨て enqueue・ISmtpQueueService 経由）→ 6.1 Mail 分岐。※実装フェーズ（ユーザー確認後）。
2. `send-config-master` tasks 2.1：テーブル定義書・ER図に `m_send_config` 追記（doc・未反映を確認済み）。
3. 印刷系カットオーバーの締め（独立）：dispatch 5.1/5.2 旧 Material 監視画面廃止・6.1 導線解除SQL・9.1 カットオーバーノート。
4. 任意PBT・ユーザー実行系（DDL 適用・ビルド・実送信）。

---

## send-config-master doc 追記 完了（テーブル定義書・ER図に m_send_config・tasks 2.1=[x]）

- `.kiro/docs/db/テーブル定義書.md`: 「共通DB（db_common_dev）— 送信設定マスタ（send-config-master）」節を新設し `m_send_config` の列定義表（id/from_address(nvarchar256)/test_fax_number(nvarchar40)/test_email(nvarchar256)/is_active/created_at/updated_at/row_version）を追記。監査列は created_at/updated_at のみ・1行運用・独立マスタ。「新DBのみ（db_common_dev・正）」一覧にも追記。
- `.kiro/docs/db/ER図.md`: 「送信設定マスタ（send-config-master）」節＋mermaid（単独マスタ）＋テーブル分類を追記。
- `send-config-master/tasks.md`: 2/2.1＝[x]。診断クリア。
- 直接編集（str_replace）・クラッシュ無し。

### send-config-master 残（未実装＝実装フェーズ）
- 5.1 管理画面「単発テスト送信」ボタン（FAX/Mail・使い捨て enqueue・ISmtpQueueService 経由・宛先未設定はメッセージ）／6.1 Mail 分岐。任意テスト 3.3/4.4/6.2。
- ユーザー実行: `create_m_send_config.sql`（db_common_dev）・`register_send_config_content.sql`（dbAuthTest）。

### 次アクション候補
1. send-config-master 5.1/6.1 の実装（管理画面 単発テスト送信ボタン）＝コード変更・ユーザー確認後。
2. 印刷系カットオーバー締め（dispatch 5.1/5.2 旧監視画面廃止・6.1 導線解除SQL・9.1 ノート）。

---

## send-config-master 単発テスト送信ボタン 実装完了（R6/R7・tasks 6/6.1=[x]）

- `CommonModule/Areas/Common/Pages/SendConfig/Index.cshtml.cs`: primary ctor に `ISendConfigService sendConfig`・`ISmtpQueueService smtpQueue` を追加注入。ハンドラ2つ追加:
  - `OnPostTestSendFaxAsync`: 有効行取得→未登録/`test_fax_number` 未設定はメッセージで投入せず。OKなら `EnqueueAsync(module:"common", configKey:"fax", fromAddress:from_address, recipient:test_fax_number, subject:"[テスト送信] FAX疎通確認", body:…)` で使い捨て1件投入。
  - `OnPostTestSendMailAsync`: 同様に `configKey:"mail"`・`recipient:test_email`。未設定はメッセージ。
  - 常駐レコードなし・From はマスタ from_address・config_key は本番同一（fax/mail）＝recipient 上書き方式と整合。
- `Index.cshtml`: 「単発テスト送信（疎通確認）」カード＋「FAXテスト送信」「メールテスト送信」ボタン（各 asp-page-handler フォーム・antiforgery 自動）。
- 診断クリア（.cs/.cshtml）。CommonModule 内で完結・MainWeb/AuthModule 不変更。
- tasks 6/6.1＝[x]。残: 6.2*（例示テスト・任意）・3.3*/4.4*（任意PBT/例示）・CP 5/7（ビルド/テスト＝ユーザー）。

### send-config-master 現況
- 実装（マスタ/サービス/管理画面/契約/単発テスト送信）＝完了。docs 反映済み。
- ⏳ ユーザー実行: `create_m_send_config.sql`（db_common_dev）・`register_send_config_content.sql`（dbAuthTest）適用 → slnCoCore ビルド → `/Common/SendConfig` で編集＋単発テスト送信ボタン動作確認（SmtpAgent 停止中は t_smtp_queue に status=1 で積まれるのが正常）。

### 次アクション候補
1. 印刷系カットオーバー締め（dispatch 5.1/5.2 旧 Material 監視画面廃止・6.1 導線解除SQL・9.1 ノート）。
2. 任意テスト（send-config-master 3.3/4.4/6.2）。
3. ユーザー: 上記 DDL/導線 SQL 適用・ビルド・GUI 動作確認。

---

## 印刷系カットオーバー締め 完了（dispatch 5.1/5.2/6.1/9.1）

- **5.1/5.2 旧監視画面 削除**（ユーザー承認済）: `MaterialModule/Areas/Material/Pages/SmtpMonitor/Index.cshtml(.cs)`・`PrintMonitor/Index.cshtml(.cs)` の4ファイルを削除。監視は `/Common/SmtpMonitor`・`/Common/PrintMonitor` に集約済み。両ページは `t_order_reports`（FaxStatus/PrintStatus/PrintPayload）・`SmtpAgentControls`/`PrintAgentControls` を参照していた＝削除で参照撤去も完了。
  - **保全（削除せず）**: `TOrderReport` エンティティ・`MaterialDbContext` の DbSet（OrderReports/SmtpAgentControls/PrintAgentControls）。削除後は未使用だがビルドエラーにならない（design 方針＝参照除去のみ・t_order_reports 保全）。空ディレクトリ SmtpMonitor/・PrintMonitor/ は名残（無害）。
- **6.1 導線解除SQL 作成**: `MaterialModule/docs/sql/unregister_material_monitor_content.sql`（dbAuthTest・`register_smtp_monitor_content.sql` と対）。`area='Material'` の `SmtpMonitor/Index`・`PrintMonitor/Index` の `r_content_auth`→`m_content` の順で DELETE＋確認クエリ＋バックアップ注記。実行はユーザー。
- **9.1 カットオーバー協調ノート**: dispatch design.md「カットオーバー協調」章に「旧監視画面の廃止・導線解除（③投入先切替後に実施・解除SQL 参照・TOrderReport 保全・可逆）」の1点を追記。
- tasks 5/5.1/5.2・6/6.1・9/9.1＝[x]。全診断クリア。

### ⏳ ユーザー確認事項
- **slnCoCore ビルド**（旧2ページ削除後の確認）: 参照撤去のみ・型参照なしのためビルド破壊は無い見込みだが要確認。
- **unregister_material_monitor_content.sql**（dbAuthTest）適用でメニューから旧 Material 監視が消える。
- 旧画面復元は git（ページ）／SQL 再登録（導線）で可能。

### dispatch-monitoring-consolidation 現況
- 実装系タスク（1/2/3/5/6/9/10/11）＝完了。残＝任意テスト（2.2/7.x/10.3/11.5）・CP（4/8/11.6）＝ユーザー実行系。
- ① spec 再改訂＋印刷系締めまで完了。send-config-master も実装完結。

### 次アクション候補
1. ユーザー: slnCoCore ビルド確認＋各SQL適用（create_m_send_config / register_send_config_content / unregister_material_monitor_content / alter_t_print_queue_drop_output_type / create_m_printer）＋GUI動作確認。
2. 任意PBT（send-config-master 3.3/4.4/6.2・dispatch 7.x/10.3/11.5・print-platform 12.14〜12.16）。
3. 区切りコミット（CommonModule 送信設定/単発テスト送信・MaterialModule 旧画面削除/解除SQL・Nonaka/.kiro spec/docs/memo）。
