# 要件定義書

## はじめに

原材料工場入請求登録ページ（Dispatches/Index）のエントリフィルタリングを、ユーザーID単位からセクション（課）単位に変更する機能改修。同一セクションに所属するユーザー全員が互いのエントリを閲覧・操作できるようにすることで、チーム内の業務効率を向上させる。

## 用語集

- **Dispatches_Page**: MaterialModule/Areas/Material/Pages/Dispatches/Index に配置された原材料工場入請求登録画面
- **TDispatch**: 出庫請求データを格納するエンティティ（t_dispatches テーブル）
- **SectionId**: TDispatchに新規追加するカラム。エントリ作成時のユーザー所属セクションIDを保持する
- **UserSectionId**: ログインユーザーの所属セクションID。SharedCore.IUserRepository.GetUserSectionIdsAsync() から取得
- **Section_Filter**: SectionIdカラムを用いたエントリのフィルタリングロジック
- **Fallback_Filter**: SectionIdがNULLの既存レコードに対し、従来のUserId一致でフィルタリングするロジック
- **SuperUser**: 戻し操作が許可されたロール

## 要件

### 要件 1: データモデル拡張

**ユーザーストーリー:** 開発者として、t_dispatchesテーブルにSectionIdカラムを追加することで、エントリのセクション帰属を記録できるようにしたい。

#### 受入基準

1. THE TDispatch entity SHALL include a SectionId property of type nullable string with a maximum length of 50 characters
2. THE t_dispatches table SHALL have a section_id column that is nullable and stores varchar(50)
3. THE SectionId column SHALL be mapped to the column name "section_id" in the database

### 要件 2: エントリ作成時のセクションID保存

**ユーザーストーリー:** 請求担当者として、エントリ作成時に自分の所属セクションIDが自動的に保存されることで、セクション単位のフィルタリングが可能になるようにしたい。

#### 受入基準

1. WHEN a new TDispatch entry is created via OnPostAddAsync, THE Dispatches_Page SHALL save the current user's section_id to the TDispatch.SectionId field
2. THE section_id value SHALL be retrieved using the existing GetUserSectionIdAsync method
3. IF the user has no section_id, THEN THE Dispatches_Page SHALL save an empty string to TDispatch.SectionId

### 要件 3: エントリ一覧のセクションフィルタリング

**ユーザーストーリー:** 請求担当者として、同一セクションの全メンバーが作成したエントリを一覧で確認できることで、チーム全体の請求状況を把握したい。

#### 受入基準

1. WHEN loading entries in LoadEntriesAsync, THE Dispatches_Page SHALL filter TDispatch records where SectionId matches the current user's section_id
2. THE Section_Filter SHALL apply to both Status=0 (未登録) and Status=1 (搬入前) views
3. WHEN a TDispatch record has a NULL or empty SectionId, THE Dispatches_Page SHALL apply the Fallback_Filter using UserId matching the current user's login name
4. THE combined filter logic SHALL be: (d.SectionId == userSectionId) OR (d.SectionId is NULL/empty AND d.UserId == loginName)

### 要件 4: エントリ削除のセクション対応

**ユーザーストーリー:** 請求担当者として、同一セクション内の他メンバーが作成したエントリも削除できることで、チーム内で柔軟に作業を分担したい。

#### 受入基準

1. WHEN the Remove action is executed, THE Dispatches_Page SHALL allow deletion of any TDispatch entry where SectionId matches the current user's section_id and Status is 0
2. WHEN a target entry has a NULL or empty SectionId, THE Dispatches_Page SHALL allow deletion only if UserId matches the current user's login name
3. THE deletion filter logic SHALL be: SelectedEntryIds AND Status==0 AND ((SectionId == userSectionId) OR (SectionId is NULL/empty AND UserId == loginName))

### 要件 5: 一括登録のセクション対応

**ユーザーストーリー:** 請求担当者として、同一セクション内の全エントリを一括登録できることで、チーム全体の請求処理を効率的に行いたい。

#### 受入基準

1. WHEN the Submit action is executed with selected entries, THE Dispatches_Page SHALL target entries where SectionId matches the current user's section_id and Status is 0
2. WHEN no entries are explicitly selected, THE Dispatches_Page SHALL target all Status=0 entries where SectionId matches the current user's section_id or where SectionId is NULL/empty and UserId matches the current user's login name
3. THE submission filter logic SHALL be consistent with the Section_Filter and Fallback_Filter defined in Requirement 3

### 要件 6: 戻し操作のセクション対応

**ユーザーストーリー:** 管理者（SuperUser）として、同一セクション内のエントリを戻し操作できることで、チームメンバーの操作ミスを修正したい。

#### 受入基準

1. WHEN the Recover action is executed by a SuperUser, THE Dispatches_Page SHALL target entries where SectionId matches the current user's section_id and Status is 1
2. WHEN a target entry has a NULL or empty SectionId, THE Dispatches_Page SHALL allow recovery only if UserId matches the current user's login name
3. THE recovery filter logic SHALL be: SelectedEntryIds AND Status==1 AND ((SectionId == userSectionId) OR (SectionId is NULL/empty AND UserId == loginName))

### 要件 7: 既存データの後方互換性

**ユーザーストーリー:** システム管理者として、既存のSectionIdが未設定のレコードが引き続き正しく表示されることで、データ移行期間中もシステムが正常に動作するようにしたい。

#### 受入基準

1. THE Dispatches_Page SHALL display existing TDispatch records with NULL or empty SectionId to the user who created them (UserId match)
2. THE Fallback_Filter SHALL ensure that no existing records become invisible after the migration
3. WHEN a backfill SQL script is executed, THE script SHALL update t_dispatches SET section_id = (corresponding section_id from user_sections lookup) WHERE section_id IS NULL
4. THE backfill script SHALL not modify records where section_id is already populated
