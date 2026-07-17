# AWS 移行 設計ドキュメント（先行・ドラフト）

> ステータス: **ドラフト（環境未確定）**。本書は AWS 環境確定前に骨子を先行整備するもの。
> 未確定事項は `TODO:` で明示し、環境確定後に確定値へ更新する。
> 実装（RDS 構築・接続切替・カットオーバー）は環境確定後に本書を基に別途着手する。

## 1. 目的・スコープ

- 現在オンプレ（`OJIADM23120073\DEVELOPMENT`・SQL Server・SQL認証）で稼働する本システムの DB を、**AWS クラウド（RDS for SQL Server 想定）** へ移行できるようにする。
- 対象は **dev / staging / prod の3面**。現状は dev のみ実在。
- 本書のスコープ：DB 移行に関わる構成・接続・シークレット・スキーマ適用・カットオーバーの設計方針。
- スコープ外（別途）：アプリ機能変更、UI、業務ロジック。

## 2. 現状整理（As-Is）

### 2.1 論理DBロールと物理DB名

`docs/sql` は 2026/07/17 に論理ロール別へ整理済み（`sql-scripts-db-split`）。

| 論理ロール | dev（現在） | staging | prod |
|---|---|---|---|
| material | db_material_dev | `TODO:` db_material_staging（想定） | `TODO:` db_material_prod（想定） |
| common | db_common_dev | `TODO:` db_common_staging（想定） | `TODO:` db_common_prod（想定） |
| auth | dbAuthTest | `TODO:` 未定 | `TODO:` 未定 |
| factory | db_factory_dev | `TODO:` 未定 | `TODO:` 未定 |

> ※ material/common の staging/prod 名は命名規約からの想定値。auth/factory は要確定。

### 2.2 接続文字列（現状）

- 保持場所：`clnCoCore/MainWeb/appsettings.json` の `ConnectionStrings`。
- キー：`DefaultAccountConnection`(dbAuthTest) / `MaterialDb`(db_material_dev) / `CommonDb`(db_common_dev) / `FactoryDb`(db_factory_dev) / `ProposalConnection` / `SafetyReportConnection`。
- サーバ：`OJIADM23120073\DEVELOPMENT`、SQL認証（`sa`・**平文パスワード**）。
- アプリ側：各モジュールは `configuration.GetConnectionString("<key>")` で取得済み（抽象化されている）。

### 2.3 重要な制約

- **接続文字列は MainWeb（clnCoCore）が保持** ＝ プラットフォーム所有。機能 spec（MaterialModule 等）からは変更しない（プロジェクトルール）。本移行の接続系変更は**プラットフォーム側の作業**として扱い、実施前にユーザー承認を得る。
- SA 平文パスワードのソース混入は本移行を機に解消する（→ 6章 Secrets）。

## 3. To-Be 構成（AWS）

- **RDS for SQL Server**（Single-AZ/Multi-AZ は `TODO:` 要件次第）。
  - エンジンエディション：`TODO:`（Express/Web/Standard/Enterprise）。ライセンス込み。
  - 認証：**SQL認証を継続**（ユーザー指定）。IAM 認証は SQL Server では非対応のため採用しない。
  - 接続：エンドポイント `<rds-endpoint>:1433`、**TLS 必須**（接続文字列に `Encrypt=True;TrustServerCertificate=False;` ＋ RDS の CA 証明書信頼）。
  - `TODO:` インスタンスクラス・ストレージ・バックアップ保持・メンテナンス窓。
- ネットワーク：`TODO:` VPC/サブネット/セキュリティグループ（アプリからの 1433 許可）、オンプレからの移行経路。
- 1インスタンスに material/common/auth/factory の各DBを同居させるか、分けるかは `TODO:`（コスト/分離要件で判断）。

## 4. 接続文字列の環境別化（アプリは原則コード不変）

- ASP.NET Core 標準の構成階層で吸収する：
  - `appsettings.json`（既定＝開発想定）
  - `appsettings.Staging.json` / `appsettings.Production.json`（環境別上書き）
  - **環境変数**（最優先上書き。例：`ConnectionStrings__MaterialDb`）
- `ASPNETCORE_ENVIRONMENT`（Development/Staging/Production）で切替。
- アプリコードは `GetConnectionString` 済みのため**変更不要**（切替は構成とデプロイで吸収）。
- 変更が必要になるのは **MainWeb の構成ファイル/デプロイ設定**（＝clnCoCore・プラットフォーム所有・要承認）。
- `TODO:` 各環境の `ASPNETCORE_ENVIRONMENT` 設定方法（IIS/サービス/コンテナ）。

## 5. スキーマ適用（環境非依存 SQL の活用）

- `docs/sql` は USE 削除・ロール別（material/common/auth）に整理済み。各環境へは対象DBを選択して適用：
  - `sqlcmd -S <rds-endpoint> -d <物理DB名> -U <user> -i <role>\<file>.sql`（TLS 引数 `TODO:`）
- 実行順は各 `docs/sql/README.md` に準拠（create → alter/migration → seed）。冪等スクリプトは再実行可。
- `TODO:` staging/prod の物理DB名確定 → `docs/sql/README.md` 対応表を更新。
- データ移行（既存 dev データの持ち込み要否）：`TODO:`（新規構築なら seed のみ／移行ならバックアップ復元 or BCP/DMS）。

## 6. シークレット管理

- SA 平文の廃止。**AWS Secrets Manager**（または SSM Parameter Store SecureString）に接続情報を格納。
- 注入方式（案）：
  - コンテナ/EC2 起動時に Secrets を環境変数（`ConnectionStrings__*`）へ展開、または
  - アプリ起動時に AWS SDK で取得して構成に投入（構成プロバイダ）。
- ローテーション方針：`TODO:`。
- ※ 導入箇所は MainWeb 構成＝clnCoCore・要承認。

## 7. カットオーバー / ロールバック

- 手順（案・確定後に詳細化）：
  1. RDS 構築・ネットワーク疎通確認。
  2. 各ロールDBを RDS に作成（`docs/sql` 適用）。必要ならデータ移行。
  3. staging で接続切替・全機能リグレッション（印刷/FAX エージェント含む）。
  4. 移行時間帯を設定し prod 切替（接続文字列切替 or DNS/構成切替）。
  5. 監視・問題時は旧接続へ即時ロールバック（構成を戻す）。
- エージェント（PrintAgent/SmtpAgent）の接続先も同時切替が必要（各エージェントの接続構成）。`TODO:` エージェント側の接続設定所在の確認。
- `TODO:` ダウンタイム許容・切替タイミング・関係者調整。

## 8. リスク・確認事項（TODO 一覧）

- [ ] RDS エンジンエディション/インスタンスクラス/Multi-AZ/ストレージ/バックアップ
- [ ] ネットワーク（VPC/SG/オンプレ接続経路）
- [ ] staging/prod の物理DB名（material/common/auth/factory）確定 → README 更新
- [ ] Secrets Manager 採用可否・ローテーション
- [ ] `ASPNETCORE_ENVIRONMENT` の各環境設定方法（ホスティング形態＝IIS/EC2/コンテナ）
- [ ] データ移行の要否と方式（新規 seed / バックアップ復元 / DMS）
- [ ] PrintAgent/SmtpAgent の接続先切替方法（各エージェントの構成所在）
- [ ] 文字コード・照合順序（Collation）の一致確認（日本語データ）
- [ ] ダウンタイム/カットオーバー時間帯・ロールバック判断基準

## 9. 位置づけ・次アクション

- 本書は **横断設計ドキュメント**（`.kiro/docs/`）。実装フェーズに入る際は、確定事項を反映しつつ、必要なら別途 spec（プラットフォーム所有）を起票する。
- 前提整備（`docs/sql` の環境非依存化）は完了済み（`sql-scripts-db-split`・2026/07/17）。
- 環境確定後、8章 TODO を埋めて本書を「確定版」に更新する。
