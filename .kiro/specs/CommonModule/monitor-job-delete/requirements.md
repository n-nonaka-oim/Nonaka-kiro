# Requirements Document

## Introduction

共通監視画面 **Common_SmtpMonitor（`/Common/SmtpMonitor`）** と **Common_PrintMonitor（`/Common/PrintMonitor`）** の一覧に、**ジョブの削除機能**を追加する。運用担当が不要なジョブ（待機中の取り消し／完了・エラー済みの整理）を画面から除去できるようにする。

削除できるのは **「処理中(2)」以外のジョブ**（＝待機(1)・完了(3)・エラー(9)）に限定する。処理中(2) は Worker が取得中のため削除不可とする。削除は対象行の**物理削除**（`t_smtp_queue` / `t_print_queue` から行を DELETE）とし、誤操作防止のため**確認ダイアログ**を挟む。

削除操作の UI は **Material/Dispatches 一覧の削除を踏襲した「チェックボックス複数選択＋一括削除」方式**とする（各行のチェックボックスで対象を選択し、一覧外の削除ボタンで実行）。選択の中に削除不可（処理中2）の行が含まれる場合は、**削除可能な行のみを削除**し、削除件数を通知する（Material/Dispatches が削除対象ステータスのみを `RemoveRange` する挙動に倣う）。

本機能は CommonModule 内で完結する（MainWeb・AuthModule は変更しない）。監視画面そのものの所有は `print-platform`（PrintMonitor）・`smtp-sender`（SmtpMonitor）だが、本 spec はそれら画面への「削除機能の追加」を所有する。

### スコープ

- 対象：`Common_SmtpMonitor`（`t_smtp_queue`）・`Common_PrintMonitor`（`t_print_queue`）の2画面。
- 削除可否：処理中(2) 以外（待機1／完了3／エラー9）。
- 削除方式：物理削除（論理削除列は持たない）。確認ダイアログあり。
- 認可：`DbPermissionCheck`（画面と同一）。
- DDL 適用・ビルド・テスト実行はユーザー側。成果物は CommonModule 内で完結。

## Glossary

- **送信ジョブ**: `t_smtp_queue` の1行（Common_SmtpMonitor の一覧行）。ステータス列は `status`（1=待機/2=処理中/3=完了/9=エラー）。
- **印刷ジョブ**: `t_print_queue` の1行（Common_PrintMonitor の一覧行）。ステータス列は `print_status`（1=待機/2=処理中/3=完了/9=エラー）。
- **削除対象ステータス**: 処理中(2) 以外、すなわち 待機(1)・完了(3)・エラー(9)。
- **物理削除**: 対象行をテーブルから DELETE すること（復元不可）。
- **確認ダイアログ**: 削除実行前にブラウザで確認を求める操作（`confirm` 等）。
- **処理中(2)**: Worker（SmtpAgent / PrintAgent）が取得して処理中の状態。削除不可。

## Requirements

### Requirement 1: Common_SmtpMonitor からの送信ジョブ削除

**User Story:** 送信監視の運用担当として、不要な送信ジョブを一覧から削除したい。待機中の誤投入を取り消し、完了・エラー済みの履歴を整理するため。

#### Acceptance Criteria

1. THE Common_SmtpMonitor SHALL 一覧の各送信ジョブ行にチェックボックスを提供し、複数選択による一括削除操作を提供する（Material/Dispatches 踏襲）。
2. WHEN 運用担当が選択した送信ジョブの一括削除を実行する、THE Common_SmtpMonitor SHALL 選択されたジョブのうち `status` が 待機(1)・完了(3)・エラー(9) のものを `t_smtp_queue` から物理削除する。
3. IF 選択に `status` が 処理中(2) のジョブが含まれる、THEN THE Common_SmtpMonitor SHALL 当該処理中ジョブを削除対象から除外し、削除可能なジョブのみを削除する。
4. WHEN 削除が成功した、THE Common_SmtpMonitor SHALL 削除件数を含む成功メッセージを表示し、一覧を最新化する。
5. THE Common_SmtpMonitor SHALL `t_smtp_queue` 以外のテーブルを変更しない。

### Requirement 2: Common_PrintMonitor からの印刷ジョブ削除

**User Story:** 印刷監視の運用担当として、不要な印刷ジョブを一覧から削除したい。待機中の取り消しや、完了・エラー済みの整理のため。

#### Acceptance Criteria

1. THE Common_PrintMonitor SHALL 一覧の各印刷ジョブ行にチェックボックスを提供し、複数選択による一括削除操作を提供する（Material/Dispatches 踏襲）。
2. WHEN 運用担当が選択した印刷ジョブの一括削除を実行する、THE Common_PrintMonitor SHALL 選択されたジョブのうち `print_status` が 待機(1)・完了(3)・エラー(9) のものを `t_print_queue` から物理削除する。
3. IF 選択に `print_status` が 処理中(2) のジョブが含まれる、THEN THE Common_PrintMonitor SHALL 当該処理中ジョブを削除対象から除外し、削除可能なジョブのみを削除する。
4. WHEN 削除が成功した、THE Common_PrintMonitor SHALL 削除件数を含む成功メッセージを表示し、一覧を最新化する。
5. THE Common_PrintMonitor SHALL `t_print_queue` 以外のテーブルを変更しない。

### Requirement 3: 処理中(2) の削除禁止と削除時の再検証

**User Story:** 運用担当として、Worker が処理中のジョブを誤って削除できないようにしたい。処理の整合性を壊さないため。

#### Acceptance Criteria

1. THE 監視画面 SHALL 削除の可否をサーバ側の削除クエリ条件（ステータスが 処理中(2) でないこと）で担保し、処理中(2) の行は物理削除しない。
2. WHEN 一括削除を実行する、THE 監視画面 SHALL 削除時点のステータスに基づき「選択された行のうち 処理中(2) でないもの」のみを削除する（一覧表示後に Worker が取得して処理中へ遷移した行の誤削除を防ぐ）。
3. WHEN 選択された行の一部または全部が削除対象外（処理中2）または既に存在しない、THE 監視画面 SHALL 実際に削除された件数を成功メッセージで通知する（0 件の場合はその旨を通知する）。

### Requirement 4: 削除前の確認ダイアログ

**User Story:** 運用担当として、削除は取り消せないため、実行前に確認したい。誤操作による消失を防ぐため。

#### Acceptance Criteria

1. WHEN 運用担当が選択済みジョブの一括削除ボタンを押す、THE 監視画面 SHALL 実行前に確認ダイアログを表示し、承諾された場合のみ削除を実行する。
2. IF 削除ボタン押下時に1件も選択されていない、THEN THE 監視画面 SHALL 削除を実行せず、選択がない旨を通知する。
3. THE 削除操作の UI（行チェックボックス・一覧外の一括削除ボタン・確認フロー）SHALL 既存の Material/Dispatches 一覧の削除操作に倣う。

### Requirement 5: 認可と変更範囲の制約

**User Story:** プロジェクト保守者として、削除機能が既存の認可と変更範囲方針に従うことを保証したい。共通基盤の一貫性を保つため。

#### Acceptance Criteria

1. THE 削除機能 SHALL 監視画面と同一の認可ポリシー `DbPermissionCheck` の下で提供される。
2. THE 削除機能の成果物 SHALL CommonModule 内で完結し、MainWeb・AuthModule・SharedCore を変更しない。
3. THE 削除 SHALL 物理削除とし、論理削除用の列を新設しない（スキーマ変更なし）。
