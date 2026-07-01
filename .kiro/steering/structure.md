---
inclusion: fileMatch
fileMatchPattern: "**/clnCoCore/**"
---

> スコープ: 本書は CoCore（Auth）ソリューション（`clnCoCore`）固有。MaterialModule 等の作業には適用されない。

# Project Structure

## ソリューション構成

```
slnCoCore.sln
├── MainWeb/              # Composition Root (Microsoft.NET.Sdk.Web)
├── AuthModule/           # 認証・認可モジュール (Microsoft.NET.Sdk.Razor)
├── SharedCore/           # ドメイン層: モデル、インターフェース、DTO (Microsoft.NET.Sdk)
├── SharedInfrastructure/ # インフラ層: DbContext、リポジトリ、マイグレーション (Microsoft.NET.Sdk)
└── AuthModule.Tests/     # テスト (Microsoft.NET.Sdk)
```

## 依存方向ルール（厳守）

| プロジェクト | 参照可能 | 参照禁止 |
|---|---|---|
| SharedCore | なし | 全プロジェクト |
| SharedInfrastructure | SharedCore | AuthModule, MainWeb |
| AuthModule | SharedCore | SharedInfrastructure |
| MainWeb | 全プロジェクト | — |

## DI登録パターン

各モジュールは`DependencyInjection.cs`に拡張メソッドを定義。MainWebの`Program.cs`で呼び出す:
```csharp
builder.Services.AddAuthModule();
builder.Services.AddSharedInfrastructure(connectionString);
```

## 主要ディレクトリ規約

- モデル: `SharedCore/Models/` — 名前空間は`SharedCore.Models`に統一
- インターフェース: `SharedCore/Interfaces/`
- リポジトリ実装: `SharedInfrastructure/Repositories/`
- サービス実装: `{Module}/Services/`
- 認可ハンドラー: `{Module}/Authorization/`
- ミドルウェア: `{Module}/Middleware/`
- UI: `{Module}/Areas/{AreaName}/Pages/`（Razor Pages）
- テスト: `AuthModule.Tests/` — ソース構造をミラー

## Path Base

アプリケーションは`/AuthTest`をPathBaseとして使用（IIS配置用）。ミドルウェアでのリダイレクトは`context.Request.PathBase.Value`を付与すること。
