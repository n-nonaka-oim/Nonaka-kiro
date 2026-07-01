# セッション備忘録（2026/05/29）

## 本日の完了作業

### 1. タンク残量チェックページ — Spec完成 + 実装完了
- requirements.md レビュー確認（前回作成済み）
- design.md 作成（アーキテクチャ、エンティティ定義、ハンドラ設計、Correctness Properties 7件）
- tasks.md 作成（5ステップ、14サブタスク）
- 全タスク実行完了:
  - SQLスクリプト作成 + DB実行（m_tanks, t_tank_checks テーブル）
  - MTank / TTankCheck エンティティ作成
  - MaterialDbContext に DbSet + インデックス設定追加
  - PageModel 実装（OnGet, SaveCheck, GenerateTanks）
  - Razor ページ実装（テーブル + AJAX保存JS）
- ビルドエラー修正:
  - `<option>` タグヘルパーの C# 式エラー → if/else ブロックに変更
  - `ToHashSetAsync()` → `ToListAsync().ToHashSet()` に変更

### 2. 前回セッション（05/28）の確認
- session-memo-20260528.md の内容確認・把握

---

## 未完了（次回タスク）

### タンク残量チェックページ（最優先）
- **ビルド確認**（エラー修正済み、未確認）
- **動作確認**: `/Material/TankCheck` にアクセス → タンクマスタ生成 → データ入力 → 保存
- ナビメニューにリンク追加

### 発注計画ダッシュボード（残課題）
- 入庫ステータスの色表示が一部反映されない（要調査）
- 計画出庫インライン編集の動作確認
- try-catch デバッグ表示を本番用に戻す
- UX改善（レイアウト微調整）

### 受払台帳（StockLedger）
- 計画データ編集UI — 動作確認・微調整

### マスタメンテナンス
- 用途1〜3の編集UI追加（任意）

### 印刷・帳票
- 印刷対応
- 搬入部門への帳票自動出力（Worker Service）

### 将来機能（生産計画プロジェクト構築時）
- usage別集計・加重平均による所要計算
- 現場発注（B管理品）ページ
- マスタメンテナンスの機能拡充

---

## 参照ファイル一覧（再開時に読むべきファイル）

### ドキュメント
- `MaterialModule/Doc/session-memo-20260529.md`（本ファイル）
- `.kiro/steering/project-rules.md`（プロジェクトルール — 自動読込）
- `.kiro/specs/tank-check/` — requirements.md, design.md, tasks.md

### 主要変更ファイル（本日）
- `Data/Entities/MTank.cs` — 新規
- `Data/Entities/TTankCheck.cs` — 新規
- `Data/MaterialDbContext.cs` — DbSet + OnModelCreating 追加
- `Areas/Material/Pages/TankCheck/Index.cshtml.cs` — PageModel 全体
- `Areas/Material/Pages/TankCheck/Index.cshtml` — Razor ページ + JS
- `Doc/sql/create_tank_tables.sql` — テーブル作成SQL（実行済み）
- `.kiro/specs/tank-check/design.md` — 新規
- `.kiro/specs/tank-check/tasks.md` — 新規
- `MaterialModule/Doc/specs/tank-check/design.md` — コピー
- `MaterialModule/Doc/specs/tank-check/tasks.md` — コピー
