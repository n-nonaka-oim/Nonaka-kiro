# Design Document

## Overview

SMTP送信監視画面（`CommonModule/Areas/Common/Pages/SmtpMonitor/Index`）の送信ジョブ一覧に「ユーザー」列（投入者のコード＋氏名）を追加する。すでに実装済みの PrintMonitor ③-2（`t_print_queue.user_code` 追加〜氏名解決表示）と同型の**非破壊的**アプローチを SMTP 側へ横展開する。

処理の流れは次の 4 段構成で、いずれも既存ロジックを変更せず新規列・省略可能引数・表示列の追加のみで成立する。

- **DB**: `t_smtp_queue` に `user_code NVARCHAR(40) NULL` を冪等 ALTER で追加する（既存列・`row_version` は不変）。
- **エンティティ**: `TSmtpQueue.UserCode`（`[Column("user_code")][MaxLength(40)]`）を追加する。
- **サービス**: `ISmtpQueueService.EnqueueAsync` の**末尾**に省略可能引数 `string? userCode = null` を追加し、実装で空白正規化のうえ `UserCode` を INSERT にセットする。既存の投入ロジック（差出人・宛先・件名・本文・CC・BCC・添付・ステータス・`row_version`）は不変。
- **投入元（MaterialModule）**: SMTP 投入経路（PrintSettings のテストメール送信、および FAX/メール送信経路）で実行ユーザーのログイン名（`User.Identity?.Name`）を `userCode` として渡す。
- **表示（SmtpMonitor）**: `IUserRepository.GetAllUsersAsync()` で `UserName`→`FullName` 辞書（OrdinalIgnoreCase）を構築し、`user_code` を氏名へ解決して「コード（氏名）」形式で表示する。未設定／未一致は「-」。

スコープは CommonModule 内（SmtpMonitor 画面・`ISmtpQueueService`＋実装・`TSmtpQueue`・冪等 ALTER SQL・DBドキュメント）と、投入側 MaterialModule の SMTP 投入経路に限定する。`clnCoCore`（SharedCore / MainWeb / AuthModule / SharedInfrastructure）は読み取り参照のみとし、一切変更しない。既存の削除／再送／フィルタ／自動更新／ページャ／選択削除ボタン活性化の挙動は維持する。

> **DB スキーマ変更の適用**: `t_smtp_queue` への `user_code` 列追加はユーザー承認のうえ、**ユーザーが `db_common_dev`（`OJIADM23120073\DEVELOPMENT`）に対して ALTER スクリプトを実行**する。Kiro からはスクリプトを配置するのみで DB へは適用しない。

言語: C#（.NET 8 / ASP.NET Core Razor Pages）。

## Architecture

```
┌──────────────────── SMTP ユーザー列対応（投入〜表示・PrintMonitor ③-2 同型） ─┐
│ [投入側 MaterialModule]                                                       │
│   PrintSettings/Index.cshtml.cs  ─┐                                           │
│   FAX/メール送信経路             ─┼─► ISmtpQueueService.EnqueueAsync(         │
│   （DispatchEnqueueService 等）  ┘        …, userCode: loginName)             │
│                                              │                                │
│ [CommonModule]                               ▼                                │
│   SmtpQueueService  … TSmtpQueue.UserCode にセット（空白は NULL 正規化）       │
│   TSmtpQueue        … user_code 列（NVARCHAR(40) NULL）                        │
│   t_smtp_queue      ← alter_t_smtp_queue_add_user_code.sql（冪等・ユーザー適用）│
│                                              │                                │
│   SmtpMonitor/Index.cshtml.cs                ▼                                │
│     OnGetAsync: IUserRepository で UserName→FullName 辞書（OrdinalIgnoreCase） │
│     → JobRow.UserName を解決                                                   │
│   SmtpMonitor/Index.cshtml  … 「ユーザー」列追加（UserCode（UserName） or -）  │
└───────────────────────────────────────────────────────────────────────────────┘
```

依存方向: MaterialModule → CommonModule（`ISmtpQueueService`）／SmtpMonitor → SharedCore（`IUserRepository`）。いずれも既存の許可された参照方向であり、新規参照は追加しない（`IUserRepository` は PrintMonitor が既に利用中で、CommonModule は SharedCore を参照済み）。

## Components and Interfaces

### C1. 冪等 ALTER SQL — `CommonModule/docs/sql/alter_t_smtp_queue_add_user_code.sql`（新規）

- `COL_LENGTH('t_smtp_queue', 'user_code') IS NULL` による存在チェックで再追加を防止する（冪等。Req 1.2 / 1.3 / 1.4）。
- 既に実装済みの `alter_t_print_queue_add_user_code.sql` と同型のヘッダ・ガード・PRINT 通知を踏襲する。
- 実行先 DB は `db_common_dev`（`OJIADM23120073\DEVELOPMENT`）。**適用はユーザーが実施**する旨をヘッダに明記する。
- 追加列は NULL 許容のため既存行に影響しない（既存行の `user_code` は NULL＝未設定/不明）。既存の 18 列（id/module/config_key/from_address/from_name/recipient/cc/bcc/subject/body/pdf_path/status/picked_at/completed_at/error_message/created_at/updated_at/row_version）は変更しない（Req 1.5）。

```sql
/* ===========================================================================
 * t_smtp_queue（共通送信キュー）改修 ALTER スクリプト
 *   投入ユーザー表示（SmtpMonitor 監視画面）対応: user_code 列を追加する。
 *
 *   目的:
 *     監視画面（Common/SmtpMonitor）で「誰が投入した送信ジョブか」を表示するため、
 *     投入時にログインユーザーコードを保持する user_code 列を追加する。
 *     氏名は表示側で ApplicationUser（SharedCore）から解決する。
 *
 *   変更内容:
 *     user_code NVARCHAR(40) NULL を追加（存在チェック COL_LENGTH でガード・冪等）。
 *     既存行は NULL（未設定=不明）となる。
 *
 * 実行先DB: db_common_dev（OJIADM23120073\DEVELOPMENT）
 * ※実行はユーザーが db_common_dev に対して行うこと。
 * ------------------------------------------------------------------------- */

USE db_common_dev;
GO

IF COL_LENGTH('dbo.t_smtp_queue', 'user_code') IS NULL
BEGIN
    ALTER TABLE dbo.t_smtp_queue ADD user_code NVARCHAR(40) NULL;
    PRINT 'Added column t_smtp_queue.user_code.';
END
ELSE
    PRINT 'Skip add (user_code already exists).';
GO
```

### C2. `TSmtpQueue`（エンティティ）— `UserCode` 追加

既存プロパティの並びに合わせ、`row_version`（`[Timestamp]`）の直前（`UpdatedAt` の後）に nullable 列を追加する。属性パターンは既存の `[Column("xxx")]`＋`[MaxLength(n)]` を踏襲する（Req 2.1〜2.4）。

```csharp
/// <summary>投入ユーザーの識別コード（ApplicationUser.UserName に対応。NULL=未設定/不明）。監視画面での投入者表示に使用。</summary>
[Column("user_code")]
[MaxLength(40)]
public string? UserCode { get; set; }
```

- 既存プロパティおよび `RowVersion`（`[Timestamp][Column("row_version")]`）の定義は変更しない（Req 2.4 / 6.4）。

### C3. `ISmtpQueueService.EnqueueAsync` — 省略可能な `userCode` 引数（末尾追加）

既存呼び出しを非破壊にするため、`userCode` を **`CancellationToken ct = default` の後ろ（末尾）** に省略可能引数として追加する（Req 3.1 / 3.2）。

> 設計判断: `userCode` を `ct` より前に置くと、`ct` を位置引数で渡している既存呼び出しが `string?` に `CancellationToken` を渡す形になりコンパイルできない。末尾（`ct` の後）に置くことで、`userCode` を渡さない既存呼び出しはソース変更なしでそのまま成立する。PrintMonitor ③-2 と同一の設計判断。

```csharp
/// <summary>
/// 送信ジョブを共通送信キューに1件投入する。status=1(待機)で登録される。
/// </summary>
/// ...（既存の param コメントは不変）...
/// <param name="ct">キャンセルトークン。</param>
/// <param name="userCode">投入ユーザーの識別コード（ログイン名＝ApplicationUser.UserName）。
/// 省略/空/空白のみは user_code を NULL として登録する（監視画面では「-」表示）。</param>
Task<int> EnqueueAsync(
    string module,
    string configKey,
    string fromAddress,
    string? fromName,
    string recipient,
    string subject,
    string? body = null,
    string? cc = null,
    string? bcc = null,
    string? pdfPath = null,
    CancellationToken ct = default,
    string? userCode = null);   // 追加（省略可能・末尾）
```

### C4. `SmtpQueueService`（internal 実装）— `UserCode` セット

`EnqueueAsync` のシグネチャに合わせて末尾へ `string? userCode = null` を追加し、INSERT する `TSmtpQueue` に `UserCode` を設定する。空白のみ・空文字は NULL に正規化し、非空白は Trim して保存する（Req 3.3 / 3.4）。既存の必須項目バリデーション（module/configKey/fromAddress/recipient/subject）・`status=1`・`created_at == updated_at = UtcNow`・cc/bcc/pdfPath の扱いは不変（Req 3.5）。

```csharp
public async Task<int> EnqueueAsync(
    string module,
    string configKey,
    string fromAddress,
    string? fromName,
    string recipient,
    string subject,
    string? body = null,
    string? cc = null,
    string? bcc = null,
    string? pdfPath = null,
    CancellationToken ct = default,
    string? userCode = null)          // 追加
{
    // 必須項目の空文字バリデーション（既存のまま・不変）
    RequireNonBlank(module, nameof(module));
    RequireNonBlank(configKey, nameof(configKey));
    RequireNonBlank(fromAddress, nameof(fromAddress));
    RequireNonBlank(recipient, nameof(recipient));
    RequireNonBlank(subject, nameof(subject));

    var now = DateTime.UtcNow;

    var job = new TSmtpQueue
    {
        Module = module,
        ConfigKey = configKey,
        FromAddress = fromAddress,
        FromName = fromName,
        Recipient = recipient,
        Subject = subject,
        Body = body,
        Cc = cc,
        Bcc = bcc,
        PdfPath = pdfPath,
        Status = 1,
        CreatedAt = now,
        UpdatedAt = now,
        // 任意項目。空/空白のみは NULL 正規化、非空白は Trim して保存。
        UserCode = string.IsNullOrWhiteSpace(userCode) ? null : userCode.Trim(),
    };

    _db.SmtpQueue.Add(job);
    await _db.SaveChangesAsync(ct);

    return job.Id;
}
```

- `userCode` は任意項目のため `RequireNonBlank` の対象にしない。

### C5. 投入元（MaterialModule）— `userCode` を渡す

投入経路で実行ユーザーのログイン名（`User.Identity?.Name`＝`ApplicationUser.UserName`）を `userCode` に名前付きで渡す。`ct` を渡す経路は `ct:` も名前付きにして引数順序の曖昧さを避ける。ログイン名が取得できない場合（`null`）は、そのまま渡す（`SmtpQueueService` が NULL 正規化する）か、`userCode` を指定せず投入する（Req 4.1 / 4.2 / 4.3）。変更対象は MaterialModule 内に限定する（Req 4.4）。

| 経路 | ファイル / メソッド | 渡す値 | 由来 |
|---|---|---|---|
| テストメール送信 | `PrintSettings/Index.cshtml.cs` `OnPostTestMailAsync` | `userCode` | `User.Identity?.Name`（ログイン名＝`UserName`） |
| FAX/メール送信経路 | `DispatchEnqueueService` 等（**タスク段階で全経路を洗い出し確定**） | `loginName` | 実行ユーザーの `User.Identity?.Name` |

```csharp
// PrintSettings/Index.cshtml.cs（OnPostTestMailAsync 内）
// 変更前: smtpQueueService.EnqueueAsync(module:"material", configKey:"mail",
//           fromAddress, fromName:null, recipient:toEmail, subject, body, ct:ct);
await smtpQueueService.EnqueueAsync(
    module: "material",
    configKey: "mail",
    fromAddress: fromAddress,
    fromName: null,
    recipient: toEmail,
    subject: subject,
    body: body,
    ct: ct,
    userCode: User.Identity?.Name);   // 追加（実行ユーザーのログイン名）
```

> FAX/メール送信の実経路（`DispatchEnqueueService` 等）は本ワークスペースの MaterialModule ソース外に存在する可能性があるため、**タスク段階で `ISmtpQueueService.EnqueueAsync` の全呼び出し元を確定**し、実行ユーザーの `loginName` を渡せる箇所へ一律 `userCode` を追加する。取得できない経路（バックグラウンド等で `User` が無い）は `userCode` 未指定のままとし、監視画面では「-」表示となる（Req 4.3）。

### C6. `SmtpMonitor/Index.cshtml.cs` — 氏名解決（PrintMonitor と同ロジック）

- コンストラクタ（primary constructor）に `SharedCore.Interfaces.IUserRepository userRepository` を追加注入する。`using SharedCore.Interfaces;` を追加する。
  - 変更前: `public class IndexModel(CommonDbContext context) : PageModel`
  - 変更後: `public class IndexModel(CommonDbContext context, IUserRepository userRepository) : PageModel`
- `JobRow` に `UserCode`（`string?`）と `UserName`（`string?`）を追加する。
- `OnGetAsync` の `Select` 射影に `UserCode = r.UserCode` を追加する（`UserName` は辞書解決が必要なため射影では設定しない）。他の射影・フィルタ・ページング・サマリ・死活監視・並び順は不変。
- `Jobs` の `ToListAsync` 後に、`UserCode` を持つ行が存在する場合のみ `GetAllUsersAsync()` を1回呼び、`UserName`→`FullName` 辞書（`StringComparer.OrdinalIgnoreCase`）を構築して `JobRow.UserName` を解決する（ページ内 Jobs に対しループ内 await を行わない。PrintMonitor と同一実装。Req 5.2 / 5.3）。

```csharp
// Select 射影に追加
.Select(r => new JobRow
{
    Id = r.Id,
    Module = r.Module,
    ConfigKey = r.ConfigKey,
    FromAddress = r.FromAddress,
    FromName = r.FromName,
    Recipient = r.Recipient,
    Subject = r.Subject,
    PdfPath = r.PdfPath,
    Status = r.Status,
    PickedAt = r.PickedAt,
    CompletedAt = r.CompletedAt,
    ErrorMessage = r.ErrorMessage,
    CreatedAt = r.CreatedAt,
    UserCode = r.UserCode,        // 追加
})
.ToListAsync();

// 氏名解決（user_code → 氏名）。全ユーザーを1回だけ取得し辞書引きで解決する。
if (Jobs.Any(j => !string.IsNullOrEmpty(j.UserCode)))
{
    var users = await userRepository.GetAllUsersAsync();
    var nameByUserCode = users
        .Where(u => !string.IsNullOrEmpty(u.UserName))
        .GroupBy(u => u.UserName!, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.First().FullName, StringComparer.OrdinalIgnoreCase);

    foreach (var job in Jobs)
    {
        if (!string.IsNullOrEmpty(job.UserCode)
            && nameByUserCode.TryGetValue(job.UserCode, out string? fullName))
        {
            job.UserName = fullName;
        }
    }
}
```

- キーワード検索は現状（`Recipient.Contains(kw) || Subject.Contains(kw)`）のまま維持する（Req 5.7）。

### C7. `SmtpMonitor/Index.cshtml` — 「ユーザー」列（見出し＋セル）

- 「ユーザー」列を追加する。列位置は PrintMonitor に倣い、識別系メタ列に隣接させて **「接続プロファイル」列の直後・「差出人」列の手前** に配置する。
- 表示規則（PrintMonitor と同一のインライン三項式）:
  - `UserCode` が NULL/空 → `-`
  - `UserName` 未解決（未一致・空） → `UserCode` のみ
  - 解決済み → `UserCode（UserName）`

```razor
<!-- thead -->
<th>接続プロファイル</th>
<th>ユーザー</th>          @* 追加 *@
<th>差出人</th>
...
<!-- tbody（各行） -->
<td>@job.ConfigKey</td>
<td>@(string.IsNullOrEmpty(job.UserCode) ? "-" : (string.IsNullOrEmpty(job.UserName) ? job.UserCode : $"{job.UserCode}（{job.UserName}）"))</td>
<td>@* 差出人セル（既存） *@</td>
```

- 列を 1 本追加するため、空行メッセージの `colspan="14"` を **`colspan="15"`** に更新する。
- 選択削除ボタン活性化 JS・ツールチップ初期化・自動更新・ページャ・再送フォームは不変。

### DB ドキュメント更新（Req 1.6 / 1.7）

- `.kiro/docs/db/テーブル定義書.md` の `t_smtp_queue` 列一覧に `user_code`（列名＝user_code・日本語名＝投入ユーザーコード・型＝NVARCHAR(40)・NULL可・備考＝投入者のログイン名。監視画面で氏名解決表示、NULL=未設定）を追記する。
- `.kiro/docs/db/ER図.md` の `t_smtp_queue` 定義に `user_code`（`nvarchar user_code`）を追記する。

## Data Models

### `t_smtp_queue`（変更後の関連列のみ抜粋）

| 列 | 型 | NULL | 説明 |
|---|---|---|---|
| config_key | NVARCHAR(40) | NOT NULL | 接続プロファイルキー（既存・不変） |
| user_code | NVARCHAR(40) | NULL | **新規**。投入ユーザー識別コード（`ApplicationUser.UserName`）。NULL=未設定/不明 |
| row_version | rowversion | NOT NULL | 楽観的ロック（`[Timestamp]`・既存・不変） |

### `JobRow`（画面 DTO・変更後）

| プロパティ | 変更 | 用途 |
|---|---|---|
| UserCode (`string?`) | 追加 | 氏名解決の入力（`user_code` 射影値） |
| UserName (`string?`) | 追加 | 解決した氏名（`ApplicationUser.FullName`）。ユーザー列表示に使用 |

その他 `JobRow` 既存プロパティ（Id/Module/ConfigKey/FromAddress/FromName/Recipient/Subject/PdfPath/Status/PickedAt/CompletedAt/ErrorMessage/CreatedAt）は不変。

## Error Handling

- **氏名解決の欠落**: `UserCode` に一致する `ApplicationUser` が無い／`UserName` 未設定／`FullName` 空のいずれも、例外を投げず表示は `UserCode` のみ（または `-`）へフォールバックする（Req 5.4 / 5.5 / 5.6）。
- **`IUserRepository` 呼び出し**: 読み取り専用（`GetAllUsersAsync`）。監視画面の表示処理であり、取得済みデータに対する整形のみで副作用を持たない。`UserCode` を持つ行が 1 件も無ければ呼び出さない。
- **投入時の `userCode`**: 任意項目のため未指定・空白は NULL 登録とし、投入自体は成功させる（Req 3.3）。必須バリデーション（module/configKey/fromAddress/recipient/subject）は従来どおり（Req 3.5）。
- **既存行の `user_code`**: 列追加は NULL 許容のため既存行は NULL（未設定）となり、監視画面では「-」表示となる（Req 6.3）。
- **冪等 ALTER SQL**: 既に `user_code` が存在する環境では列追加をスキップし、既存データ・定義を維持する（Req 1.3）。**適用はユーザーが承認のうえ `db_common_dev` に対して実行**する。
- **排他制御**: 既存の `row_version`（`[Timestamp]`）による楽観ロックを踏襲し、新規列追加のみで既存の排他制御ロジックは変更しない（Req 6.4）。
- **スコープ維持**: 変更は CommonModule と MaterialModule の SMTP 投入経路に限定。`clnCoCore`（SharedCore / MainWeb / AuthModule / SharedInfrastructure）は読み取り参照のみ（Req 6.1 / 6.2）。

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

> **本 spec に意味のあるプロパティ（Property-Based Test）は無し。** 本機能は「DB スキーマ列追加」「`IUserRepository` による氏名辞書解決」「Razor Pages の UI 表示列追加」「投入経路での引数伝播」という副作用・外部依存中心の変更であり、`for all inputs X, P(X)` の形で意味のある普遍性質を持つ純粋関数がほぼ存在しない（PrintMonitor ③-2 と同様）。したがって受け入れ基準は**例示（Example）／統合（Integration）／スモーク（Smoke）**で検証する（下記 Testing Strategy 参照）。
>
> 唯一プロパティ化し得るのは表示整形（`UserCode`／`UserName` → 表示文字列）だが、現設計は PrintMonitor 実装に倣い cshtml のインライン三項式で表現しており、専用の純粋関数は切り出さない。**任意（オプション）** として `FormatUserDisplay(string? userCode, string? userName)` を code-behind の `static` メソッドへ切り出せば、次の 1 プロパティを PBT 化できる（必須ではない・採否は実装時の設計判断）。

### Property 1: ユーザー表示文字列の整形規則（任意・オプション）

*For any* `userCode`（NULL・空・任意文字列）と任意の `userName`（NULL・空・任意文字列）について、`FormatUserDisplay(userCode, userName)` は次を満たす:
- `userCode` が NULL または空のとき、結果は `"-"`。
- `userCode` が非空で `userName` が非空のとき、結果は `"{userCode}（{userName}）"`。
- `userCode` が非空で `userName` が NULL/空のとき、結果は `"{userCode}"`（氏名なし）。

**Validates: Requirements 5.4, 5.5, 5.6**

## Testing Strategy

**Dual Testing Approach**（ユニット＝具体例・エッジ、プロパティ＝任意）。本 spec は上記のとおり必須プロパティを持たないため、例示・統合・スモークを主とする。

- Property tests（任意・設計判断で採否）:
  - （採用する場合のみ）Property 1 → `FormatUserDisplay` を対象に、`userCode`/`userName` の生成（null・空・全角/半角・記号含む任意文字列）で 3 分岐を検証。最低 100 反復。
  - タグ形式: **Feature: smtp-monitor-user-column, Property 1: ユーザー表示文字列の整形規則**
- Unit / Example tests:
  - `SmtpQueueService.EnqueueAsync` の `userCode` 正規化: `null`／空文字／空白のみ → `UserCode` が `null`、非空白 → Trim 後の値、を InMemory `CommonDbContext` で例示確認（Req 3.3 / 3.4）。DB 名は `Guid.NewGuid().ToString()` で一意化し `IDisposable` で破棄。
  - 後方互換: `userCode` を渡さない既存形の `EnqueueAsync` 呼び出しが成立し、`UserCode` が `null` で登録されること（Req 3.2）。
  - 表示分岐: `UserCode`＝値/未解決/null の各ケースで `UserCode（UserName）`／`UserCode`／`-` の表示になること（Req 5.4 / 5.5 / 5.6）。
  - ユーザー列の存在: 「ユーザー」見出しが「接続プロファイル」直後に追加されていること、空行 `colspan` が 15 であること（Req 5.1）。
- Integration tests（1〜数例）:
  - `IUserRepository` による `UserName`→`FullName` 辞書解決（OrdinalIgnoreCase 照合）が機能すること（Req 5.2 / 5.3）。
  - MaterialModule の SMTP 投入経路が `userCode`（ログイン名）を渡すこと。取得不可経路は未指定で投入されること（Req 4.1 / 4.2 / 4.3）。
  - 冪等 ALTER SQL の 2 回適用で列が 1 本のまま（Req 1.2 / 1.3）。
  - 既存機能（再送・削除・フィルタ・自動更新・ページャ・選択削除ボタン活性化・キーワード検索＝宛先/件名）の回帰（Req 5.7 / 6.4）。
- Smoke / Review:
  - `user_code` 列のスキーマ存在（NVARCHAR(40) NULL）、SQL ファイル配置、DB ドキュメント（テーブル定義書・ER図）反映（Req 1.1 / 1.6 / 1.7）。
  - 既存列・`row_version` 非変更（Req 1.5 / 2.4 / 6.4）、スコープ限定・`clnCoCore` 非改変（Req 6.1 / 6.2）。

> テスト規約（steering）: xUnit + Moq + FsCheck 2.16.6。`Prop.ForAll` は最大 3 つの `Arbitrary` パラメータ。InMemoryDB 使用時は一意 DB 名＋`IDisposable`。プロパティテストを採用する場合は本設計の Property 番号を参照タグに含める。
