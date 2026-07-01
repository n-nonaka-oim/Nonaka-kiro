# Implementation Plan: Dispatches セクションフィルタ化

## 概要

Dispatchesページのエントリフィルタリングを UserId 単位から SectionId 単位に変更する。TDispatchエンティティにSectionIdプロパティを追加し、全ハンドラのフィルタロジックを共通メソッド（ApplySectionFilter）に統一する。既存データの後方互換性はフォールバックフィルタで保証する。

## Tasks

- [x] 1. TDispatch エンティティに SectionId プロパティを追加
  - `MaterialModule/Data/Entities/TDispatch.cs` に `SectionId` プロパティを追加
  - `[Column("section_id")]` `[MaxLength(50)]` 属性を付与
  - 型は `string?`（nullable）
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. ApplySectionFilter 共通メソッドの実装とエントリ作成の修正
  - [x] 2.1 ApplySectionFilter メソッドを IndexModel に追加
    - `IQueryable<TDispatch>` を受け取り、セクションフィルタを適用して返すprivateメソッド
    - 条件: `(d.SectionId == userSectionId) OR ((d.SectionId == null || d.SectionId == "") && d.UserId == loginName)`
    - userSectionIdが空の場合は従来通り `d.UserId == loginName` にフォールバック
    - _Requirements: 3.4, 4.3, 5.3, 6.3_

  - [x] 2.2 OnPostAddAsync で SectionId を保存するよう修正
    - `GetUserSectionIdAsync()` で取得した値を `dispatch.SectionId` に設定
    - 既存パターン（DepartmentName, CostCenter保存）に倣う
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ]* 2.3 Property Test: エントリ作成時のSectionId保存
    - **Property 1: エントリ作成時のSectionId保存**
    - **Validates: Requirements 2.1, 2.3**

- [x] 3. LoadEntriesAsync のフィルタロジック変更
  - [x] 3.1 LoadEntriesAsync を ApplySectionFilter を使用するよう修正
    - `d.UserId == loginName` を `ApplySectionFilter(query, userSectionId, loginName)` に置換
    - Status=0（未登録）と Status=1（搬入前）の両方に適用
    - `GetUserSectionIdAsync()` の呼び出しを追加
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ]* 3.2 Property Test: セクションフィルタの可視性
    - **Property 2: セクションフィルタの可視性**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 7.1, 7.2**

- [x] 4. OnPostRemoveAsync のフィルタロジック変更
  - [x] 4.1 OnPostRemoveAsync を ApplySectionFilter を使用するよう修正
    - `d.UserId == loginName` を ApplySectionFilter に置換
    - `GetUserSectionIdAsync()` の呼び出しを追加
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 4.2 Property Test: 削除のセクションフィルタ整合性
    - **Property 3: 削除のセクションフィルタ整合性**
    - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 5. OnPostSubmitAsync のフィルタロジック変更
  - [x] 5.1 OnPostSubmitAsync を ApplySectionFilter を使用するよう修正
    - 選択あり・なし両方のクエリで `d.UserId == loginName` を ApplySectionFilter に置換
    - `GetUserSectionIdAsync()` の呼び出しを追加
    - _Requirements: 5.1, 5.2, 5.3_

  - [ ]* 5.2 Property Test: 登録のセクションフィルタ整合性
    - **Property 4: 登録のセクションフィルタ整合性**
    - **Validates: Requirements 5.1, 5.2, 5.3**

- [x] 6. OnPostRecoverAsync のフィルタロジック変更
  - [x] 6.1 OnPostRecoverAsync を ApplySectionFilter を使用するよう修正
    - `d.UserId == loginName` を ApplySectionFilter に置換
    - `GetUserSectionIdAsync()` の呼び出しを追加
    - SuperUser チェックは既存のまま維持
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ]* 6.2 Property Test: 戻し操作のセクションフィルタ整合性
    - **Property 5: 戻し操作のセクションフィルタ整合性**
    - **Validates: Requirements 6.1, 6.2, 6.3**

- [x] 7. チェックポイント - 全ハンドラの動作確認
  - Ensure all tests pass, ask the user if questions arise.
  - 全ハンドラ（Add, Remove, Submit, Recover, LoadEntries）がApplySectionFilterを使用していることを確認

- [x] 8. バックフィルSQLスクリプトの作成
  - [x] 8.1 既存データのsection_id更新スクリプトを作成
    - `MaterialModule/Sql/` または適切なディレクトリにSQLファイルを配置
    - UPDATE文: user_sectionsテーブルからsection_idを参照してt_dispatches.section_idを設定
    - WHERE section_id IS NULL 条件で既設定レコードを保護
    - _Requirements: 7.3, 7.4_

  - [ ]* 8.2 単体テスト: バックフィルの後方互換性
    - SectionId=NULLのレコードがフォールバックフィルタで表示されることを確認
    - バックフィル後にセクションフィルタで正しく表示されることを確認
    - _Requirements: 7.1, 7.2_

- [x] 9. 最終チェックポイント - 全テスト実行
  - Ensure all tests pass, ask the user if questions arise.
  - セクション内共有（同一セクションの2ユーザーが互いのエントリを閲覧可能）を確認
  - セクション間分離（異なるセクションのユーザーが互いのエントリを閲覧不可）を確認

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- 各タスクは特定の要件にトレーサビリティを持つ
- ApplySectionFilter の共通化により、フィルタロジックの一貫性を保証
- バックフィルスクリプトは本番実行前にステージング環境でテストすること
- GetUserSectionIdAsync() は既存メソッドをそのまま利用（変更不要）
