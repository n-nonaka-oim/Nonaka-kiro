# 要件定義書

## はじめに

CommonModule（共有モジュール）が保持するサーバ登録プリンタ一覧（`m_printer`）を、利用側モジュール（今回は MaterialModule）から**読み取り取得**できる公開インターフェースを追加する。利用側は、ユーザーが「PDFエージェント（サーバサイド・サイレント印刷）」の出力プリンタを選択・割当する際の**選択元一覧**として本I/Fを使う。

本改修は CommonModule 内で完結する読み取り専用I/Fの追加であり、`m_printer` のスキーマ変更・書き込みは行わない。利用側は CommonModule の DbContext を直接参照せず、本インターフェース経由でのみアクセスする（モジュール間はインターフェース経由の原則）。

## 用語集

- **m_printer**: プリンタマスタ（`CommonModule.Data.Entities.MPrinter` / `CommonDbContext.Printers`）。`machine_name`×`printer_name` 単位。`is_default`・`is_active`・`last_seen_at`・`row_version` を持つ。PrintAgent の棚卸しが登録・更新する。
- **PrinterInfo**: 本I/Fが返す読み取り専用DTO（プリンタ1件分）。
- **IPrinterQueryService**: 本改修で追加する CommonModule の公開読み取りインターフェース。
- **利用側モジュール**: 本I/Fを消費するモジュール（今回 MaterialModule）。

## 要件

### 要件 1: プリンタ一覧の読み取り公開I/F

**ユーザーストーリー:** 開発者（利用側モジュール）として、サーバ登録プリンタ一覧を読み取り取得できることで、ユーザーが出力プリンタを選択できる画面を構築したい。

#### 受入基準

1. THE CommonModule SHALL 公開インターフェース `IPrinterQueryService` を追加する（名前空間 `CommonModule.Services`）。
2. THE `IPrinterQueryService` SHALL メソッド `Task<IReadOnlyList<PrinterInfo>> GetAvailablePrintersAsync(string? machineName = null, CancellationToken ct = default)` を提供する。
3. WHEN `GetAvailablePrintersAsync` が呼ばれた, THE 実装 SHALL `m_printer` のうち `is_active = true` の行のみを返す。
4. WHERE `machineName` が指定された（非空）, THE 実装 SHALL `machine_name` が一致する行のみに絞り込む。
5. WHERE `machineName` が null または空白, THE 実装 SHALL マシンで絞り込まず有効な全プリンタを返す。
6. THE 実装 SHALL 読み取り専用クエリとして `AsNoTracking()` を用い、`m_printer` への書き込みを一切行わない。

### 要件 2: 戻り値DTO（PrinterInfo）

**ユーザーストーリー:** 開発者として、必要な項目だけを含む安定した戻り値を受け取ることで、エンティティ内部構造に依存せず利用したい。

#### 受入基準

1. THE CommonModule SHALL 公開 record `PrinterInfo` を追加する（名前空間 `CommonModule.Services`）。
2. THE `PrinterInfo` SHALL `MachineName`（string）・`PrinterName`（string）・`IsDefault`（bool）・`IsActive`（bool）・`LastSeenAt`（DateTime?）を保持する。
3. THE 実装 SHALL `m_printer` の各行を `PrinterInfo` に射影して返す（`row_version` 等の内部列は公開しない）。

### 要件 3: 並び順の安定性

**ユーザーストーリー:** 利用側として、一覧の並びが安定していることで、選択UIの表示が一貫するようにしたい。

#### 受入基準

1. THE 実装 SHALL 結果を `machine_name` 昇順、次に `printer_name` 昇順で整列して返す。
2. THE 実装 SHALL 同一条件の呼び出しに対して決定的な並びを返す。

### 要件 4: DI 登録と消費

**ユーザーストーリー:** 開発者として、`IPrinterQueryService` が DI で解決できることで、利用側モジュールが注入して使えるようにしたい。

#### 受入基準

1. THE `AddCommonModule`（`CommonModuleExtensions`）SHALL `IPrinterQueryService` の実装を Scoped で登録する。
2. THE 利用側モジュール SHALL `IPrinterQueryService` を注入して一覧を取得できる（CommonModule の `CommonDbContext` を直接参照しない）。

### 要件 5: 変更スコープの限定

**ユーザーストーリー:** 開発者として、共有モジュールへの影響を最小化することで、既存機能への波及を避けたい。

#### 受入基準

1. THE 本改修 SHALL CommonModule 配下の追加（`IPrinterQueryService`／実装／`PrinterInfo`／DI登録）のみとする。
2. THE 本改修 SHALL `m_printer` のスキーマを変更しない（既存テーブルを読み取るのみ）。
3. THE 本改修 SHALL 既存の `IPrintQueueService`・`ISmtpQueueService`・`ISendConfigService` の挙動を変更しない。
