# .kiro/docs（ワークスペース横断ドキュメントハブ）

本フォルダはワークスペース横断（複数モジュール／複数DBにまたがる）ドキュメントを集約する。
各プロジェクトモジュール固有のドキュメントは、当該モジュールの `docs/`（例: `MaterialModule/docs/`、`CommonModule/docs/`、`PrintAgent/docs/`、`SmtpAgent/docs/`）で管理する。

## 構成

```
.kiro/
├── steering/   ← プロジェクトルール等
├── specs/      ← spec 正本
├── session-memo/ ← 進捗ログ
└── docs/       ← 横断ドキュメント（本フォルダ）
    ├── README.md
    ├── system-architecture.md        ← システム全体構成（基盤clnCoCore＋追加モジュール＋Worker＋DB）
    ├── concurrency-control-design.md ← 排他制御・楽観ロックの横断設計
    ├── 未実装案件一覧.md              ← 全案件の一元管理バックログ（横断）
    ├── db/                            ← 横断DB参照（全DB）
    │   ├── テーブル定義書.md           ← 全DB（db_material_dev / db_common_dev）の列定義
    │   ├── ER図.md / ER図.mmd / ER図.drawio
    │   └── common-db-design.md        ← 共通DB(db_common_dev)設計・CommonModule集約構想
    └── _archive/                      ← 旧 Nonaka/Doc スケルトン（可逆退避・通常使用しない）
```

## 位置づけ
- ワークスペース共通の管理物は `.kiro/` に統一（steering / specs / session-memo / docs）。
- 役割は「横断（複数DB・複数モジュールにまたがる）ドキュメント専用」。モジュール固有は各モジュール `docs/` へ。

## 関連
- DBスキーマ変更時は `.kiro/docs/db/テーブル定義書.md` と `.kiro/docs/db/ER図.md` を更新する（project-rules 準拠）。
- 命名規則・構築基準は `\\OJIADM23120073\Labs\sdoc\` を参照。
