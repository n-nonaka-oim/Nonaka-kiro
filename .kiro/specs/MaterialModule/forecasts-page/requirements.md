# 要件定義書

## はじめに

需要予測ページ（Forecasts/Index）の機能仕様。品目ごとの消費予測を登録・表示・削除する画面。品目選択により現在庫数量と登録済み予測一覧（±3ヶ月）を表示し、新規予測の登録および既存予測の削除を行う。対象はMaterialModule内のRazor Pagesアプリケーション。

## 用語集

- **Forecasts_Page**: MaterialModule/Areas/Material/Pages/Forecasts/Index に配置された消費予測入力画面
- **TConsumptionForecast**: 消費予測エンティティ（Id, ItemId, ForecastDate, ForecastQty, UserId, Remarks, UpdatedAt）
- **IConsumptionForecastProvider**: 消費予測の取得・保存・削除を担うサービスインターフェース
- **IMasterService**: マスタデータ取得を担うサービスインターフェース
- **IStockService**: 在庫情報取得を担うサービスインターフェース
- **ItemSelectDto**: 品目選択用DTO（Id, ItemCode, ItemName）
- **StockLedgerDto**: 在庫受払履歴DTO
- **CurrentStockQty**: 全倉庫の在庫合計数量

## 要件

### 要件 1: 品目選択

**ユーザーストーリー:** 購買担当者として、品目を選択して消費予測を管理できることで、品目ごとの需要計画を効率的に行いたい。

#### 受入基準

1. THE Forecasts_Page SHALL display a dropdown list of all active items via `IMasterService.GetActiveItemsAsync()`
2. THE item dropdown SHALL display items in the format "{ItemCode} - {ItemName}"
3. THE item dropdown SHALL include a placeholder option "-- 品目を選択 --" with empty value
4. WHEN an item is selected from the dropdown, THE Forecasts_Page SHALL automatically submit the form to reload with the selected ItemId
5. THE ItemId parameter SHALL support GET binding (SupportsGet = true)
6. WHEN no item is selected (ItemId is null or 0), THE Forecasts_Page SHALL display only the item selection card

### 要件 2: 現在庫数量表示

**ユーザーストーリー:** 購買担当者として、選択品目の現在庫を確認できることで、予測入力時の判断材料としたい。

#### 受入基準

1. WHEN an item is selected, THE Forecasts_Page SHALL display the current stock quantity via `IStockService.GetStocksByItemAsync(itemId)`
2. THE current stock quantity SHALL be calculated as the sum of StockQty across all warehouses
3. THE current stock quantity SHALL be displayed with "N2" format (小数点2桁)
4. THE current stock quantity SHALL be displayed as a badge (bg-info) in the "現在庫" card

### 要件 3: 消費予測登録

**ユーザーストーリー:** 購買担当者として、将来の消費予測を登録できることで、MRP計算の精度を向上させたい。

#### 受入基準

1. WHEN an item is selected, THE Forecasts_Page SHALL display a forecast entry form with fields: 予測日(date), 予測数量(number), 備考(text)
2. THE 予測日 field SHALL default to today's date
3. THE 予測数量 field SHALL accept values greater than 0 with decimal input (min="0.01", step="any")
4. THE 備考 field SHALL accept up to 256 characters (maxlength=256)
5. WHEN the "登録" button is clicked, THE Forecasts_Page SHALL call `IConsumptionForecastProvider.SaveForecastAsync(ItemId, ForecastDate, ForecastQty, userId, Remarks)`
6. WHEN the save succeeds, THE Forecasts_Page SHALL redirect to the same page with the current ItemId to refresh the list
7. IF ItemId is not selected (null or 0) on save, THEN THE Forecasts_Page SHALL display the error "品目を選択してください。"
8. IF ForecastQty is 0 or negative, THEN THE Forecasts_Page SHALL display the validation error "予測数量は0より大きい値を入力してください。"

### 要件 4: 消費予測一覧表示

**ユーザーストーリー:** 購買担当者として、登録済みの消費予測を一覧で確認できることで、予測の重複や漏れを把握したい。

#### 受入基準

1. WHEN an item is selected, THE Forecasts_Page SHALL display forecast records for the range of today ±3 months via `IConsumptionForecastProvider.GetForecastRecordsAsync(itemId, fromDate, toDate)`
2. THE forecast list SHALL display the following columns: 予測日, 予測数量, 備考, 登録者, 更新日時
3. THE 予測日 column SHALL be formatted as "yyyy-MM-dd"
4. THE 予測数量 column SHALL be formatted with "N2" format and right-aligned
5. THE 更新日時 column SHALL be formatted as "yyyy-MM-dd HH:mm"
6. WHEN no forecast records exist, THE Forecasts_Page SHALL display "登録済みの消費予測はありません。"

### 要件 5: 消費予測削除

**ユーザーストーリー:** 購買担当者として、不要な消費予測を削除できることで、予測データの正確性を維持したい。

#### 受入基準

1. THE Forecasts_Page SHALL display a "削除" button for each forecast record
2. WHEN the "削除" button is clicked, THE Forecasts_Page SHALL show a confirmation dialog "この予測を削除しますか？"
3. WHEN the deletion is confirmed, THE Forecasts_Page SHALL call `IConsumptionForecastProvider.DeleteForecastAsync(forecastId)`
4. WHEN the deletion succeeds, THE Forecasts_Page SHALL redirect to the same page with the current ItemId to refresh the list

### 要件 6: 在庫受払履歴表示

**ユーザーストーリー:** 購買担当者として、在庫の受払履歴を参照できることで、消費予測の根拠となる実績データを確認したい。

#### 受入基準

1. WHEN an item is selected, THE Forecasts_Page SHALL display a "在庫受払履歴（直近30件）" section
2. THE stock ledger history SHALL display the following columns: 日付, 繰越数量, 入庫数量, 出庫数量, 在庫数量
3. THE numeric columns SHALL be formatted with "N2" format and right-aligned, displaying "-" for null values
4. WHEN no stock ledger history exists, THE Forecasts_Page SHALL display "在庫受払履歴はありません。"

### 要件 7: 認可制御

**ユーザーストーリー:** システム管理者として、消費予測ページへのアクセスが権限のあるユーザーに限定されることで、予測データの不正操作を防止したい。

#### 受入基準

1. THE Forecasts_Page SHALL require authorization via the "DbPermissionCheck" policy
2. WHEN an unauthorized user attempts to access the page, THE system SHALL deny access according to the configured authorization policy
