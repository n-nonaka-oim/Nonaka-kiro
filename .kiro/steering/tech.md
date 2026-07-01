---
inclusion: fileMatch
fileMatchPattern: "**/clnCoCore/**"
---

> スコープ: 本書は CoCore（Auth）ソリューション（`clnCoCore`）固有。MaterialModule 等の作業には適用されない。

# Technology Stack

- .NET 8.0 / ASP.NET Core / C# (nullable reference types, implicit usings)
- Razor Pages + Blazor Server + Bootstrap
- SQL Server via EF Core (Code-first)
- 接続文字列キー: `DefaultAccountConnection`

## コマンド

```cmd
dotnet build slnCoCore.sln
dotnet run --project MainWeb
dotnet test AuthModule.Tests
dotnet ef migrations add <Name> --project SharedInfrastructure --startup-project MainWeb
dotnet ef database update --project SharedInfrastructure --startup-project MainWeb
```

## テスト

- xUnit + Moq + FsCheck 2.16.6（`Prop.ForAll`は最大3つの`Arbitrary`パラメータ）
- Microsoft.EntityFrameworkCore.InMemory でリポジトリ統合テスト

## 新規モジュール追加時のSDK選択

- UI含むモジュール: `Microsoft.NET.Sdk.Razor`
- ドメイン/インフラ/テスト: `Microsoft.NET.Sdk`
- Webホスト: `Microsoft.NET.Sdk.Web`（MainWebのみ）
