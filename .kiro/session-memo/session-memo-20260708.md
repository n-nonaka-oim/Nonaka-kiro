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

## 本日のコミット
- コード変更なし（要件・設計方針の確定・Q&A のみ）。本 memo 20260708 作成。

## 🟡 次アクション（次回）
1. **新規 spec 起草**（CommonModule・送信設定マスタ＋管理画面＋テスト送信 recipient上書き・fax/mail）: requirements から。Mail 送信の対象（疎通のみ or 発注書メール送信機能）を requirements で確定。
2. smtp-sender / dispatch spec の再改訂（test-fax 取り下げ・recipient上書き方式へ）。
3. 実装差し替え（SmtpAgent の固定宛先モード撤去・投入側の from/テスト宛先マスタ参照・管理画面）。
4. 並行: FAX enqueue 実機検証（output_type=2/3）はユーザー継続（暫定は現行 test-fax でも可だが、上記改訂後に再確認）。

## 再開合図
「再開します、session-memoを確認」。最新は本ファイル（20260708）。次アクション＝**CommonModule 送信設定マスタ＋テスト送信 recipient上書き方式の spec 起草（requirements）**。Mail 送信対象の定義から。
