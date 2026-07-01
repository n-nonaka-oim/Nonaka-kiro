# 共有DB設計（db_common）

## 概要

全モジュール共通で使用するマスタデータを管理する専用DB。
現時点ではMaterialModuleのみが参照しているが、次のプロジェクトでも使用予定。

## DB情報

| 項目 | 内容 |
|---|---|
| DB名（開発） | db_common_dev |
| DB名（本番） | db_common_prod |
| サーバー | OJIADM23120073\DEVELOPMENT |
| 接続文字列キー | CommonDb |
| 認証 | SA認証 |

## テーブル一覧

### m_calendar（カレンダーマスタ）

| カラム名 | 型 | 必須 | 説明 |
|---|---|---|---|
| id | int | PK | 主キー（IDENTITY） |
| calendar_date | date | YES, UK | 日付（ユニーク） |
| is_business_day | bit | YES | 営業日フラグ（1=営業日, 0=休日） |
| day_type | nvarchar(20) | YES | 種別（weekday/saturday/sunday/holiday/company_holiday） |
| holiday_name | nvarchar(100) | NO | 祝日・休日名 |
| created_at | datetime | YES | 登録日時 |
| updated_at | datetime | YES | 更新日時 |

**初期データ**: 2026/04/01〜2027/03/31（365日、営業日245日、休日120日）

## 現在のアクセス方式

### MaterialModule内
- `Data/CommonDbContext.cs` — 読み取り専用DbContext
- `Data/Entities/MCalendar.cs` — エンティティ
- `Services/MasterService.GetBusinessDayAfterAsync()` — 営業日計算

### DI登録
```csharp
services.AddDbContext<CommonDbContext>(options =>
    options.UseSqlServer(configuration.GetConnectionString("CommonDb")));
```

## 将来の移行計画

次のプロジェクトでもカレンダーマスタを使用する場合:

1. **CommonModule プロジェクトを新規作成**（Microsoft.NET.Sdk）
2. `CommonDbContext` と `MCalendar` エンティティを CommonModule に移動
3. 各モジュール（MaterialModule, 次プロジェクト）から CommonModule をプロジェクト参照
4. DI登録は各モジュールの Extensions で実施

### CommonModule 構成案
```
CommonModule/
├── Data/
│   └── CommonDbContext.cs
├── Entities/
│   └── MCalendar.cs
├── Services/
│   ├── ICalendarService.cs
│   └── CalendarService.cs
├── Extensions/
│   └── CommonModuleExtensions.cs
└── CommonModule.csproj
```

## 運用

- カレンダーデータは年度ごとに事前登録（4月〜翌3月）
- 会社休日（夏季休暇、年末年始等）はマスタメンテナンスページで追加
- 祝日は毎年確認して更新（振替休日の確認含む）
