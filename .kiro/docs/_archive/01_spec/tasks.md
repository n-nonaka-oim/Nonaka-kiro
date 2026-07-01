# Implementation Plan: Material Module (資材モジュール)

## Overview

DemoModule パターンに準拠した Razor Class Library として Material モジュールを構築する。プロジェクト構成→DB/モデル→サービス層→Razorページ→テストの順に依存関係に沿って実装を進める。MRP計算ロジックを中心に、発注・承認・入庫・出庫・納期監視の各機能を段階的に統合する。

## Tasks

- [x] 1. プロジェクト構成とコアインターフェースのセットアップ
  - [x] 1.1 MaterialModule プロジェクトの作成
    - `MaterialModule.csproj` を作成 (net8.0, Microsoft.NET.Sdk.Razor)
    - `MaterialModule.sln` を作成
    - NuGet パッケージ参照を追加: Microsoft.EntityFrameworkCore, Microsoft.AspNetCore.Authorization 等
    - ディレクトリ構成を作成: `Areas/Material/Pages/`, `DependencyInjection/`, `Models/`, `Services/`
    - _Requirements: REQ-1_

  - [x] 1.2 DI 拡張メソッドの作成
    - `DependencyInjection/MaterialModuleExtensions.cs` を作成
    - `AddMaterialModule(IServiceCollection)` メソッドを実装
    - 全サービスの DI 登録 (internal クラスを AddScoped/AddTransient で登録)
    - MaterialDbContext の登録 (接続文字列キー: "MaterialDb")
    - _Requirements: REQ-1_

  - [x] 1.3 Razor ページ共通ファイルの作成
    - `Areas/Material/Pages/_ViewImports.cshtml` を作成
    - `Areas/Material/Pages/_ViewStart.cshtml` を作成
    - `[Authorize(Policy = "DbPermissionCheck")]` を全ページに適用する設定
    - _Requirements: REQ-1_

- [x] 2. データベースコンテキストとモデルの実装
  - [x] 2.1 マスタテーブルのエンティティモデル作成
    - `Models/` 配下に以下のエンティティクラスを作成:
    - `MItem`, `MSupplier`, `MWarehouse`, `MPackageType`, `MDepartment`, `MDeliveryLocation`, `MOrderStatus`, `MForecastSource`, `MBomHeader`, `MBomDetail`
    - 全エンティティに `id`, `created_at`, `updated_at` カラムを含める
    - DB命名規則: snake_case, m_ プレフィックス
    - _Requirements: REQ-1, REQ-2, REQ-3_

  - [x] 2.2 トランザクションテーブルのエンティティモデル作成
    - `Models/` 配下に以下のエンティティクラスを作成:
    - `TOrder`, `TReceiving`, `TDispatch`, `TStock`, `TStockLedger`, `TConsumptionForecast`, `TOrderForecast`
    - 全エンティティに `id`, `created_at`, `updated_at` カラムを含める
    - DB命名規則: snake_case, t_ プレフィックス
    - _Requirements: REQ-2, REQ-3, REQ-4, REQ-5, REQ-6_

  - [x] 2.3 DTO / ViewModel クラスの作成
    - 各ページで使用する DTO / ViewModel を作成
    - 発注入力用、承認一覧用、入庫用、出庫用、MRP結果表示用 等
    - _Requirements: REQ-2, REQ-3, REQ-4, REQ-5, REQ-6_

  - [x] 2.4 MaterialDbContext の実装
    - `MaterialDbContext` クラスを作成
    - 全エンティティの DbSet プロパティを定義
    - `OnModelCreating` でテーブル名マッピング (snake_case) とリレーション設定
    - 接続文字列キー: "MaterialDb" (db_material_dev / db_material_prod)
    - _Requirements: REQ-1_

- [x] 3. チェックポイント - プロジェクト構成とモデルの確認
  - ビルドが通ることを確認し、ユーザーに質問があれば確認する。

- [ ] 4. マスタサービスと在庫サービスの実装
  - [x] 4.1 IMasterService / MasterService の実装
    - `Services/IMasterService.cs` (public インターフェース) を作成
    - `Services/MasterService.cs` (internal クラス) を作成
    - m_items, m_suppliers, m_warehouses 等のマスタデータ取得メソッド
    - async/await パターンで実装
    - _Requirements: REQ-1, REQ-2_

  - [x] 4.2 IStockService / StockService の実装
    - `Services/IStockService.cs` (public) / `Services/StockService.cs` (internal) を作成
    - 在庫数量の取得・更新メソッド (stock_qty の増減)
    - 在庫台帳 (t_stock_ledgers) への記録
    - async/await パターンで実装
    - _Requirements: REQ-5, REQ-6_

  - [ ]* 4.3 StockService のユニットテスト作成
    - 在庫増減の正確性テスト
    - 在庫台帳記録の整合性テスト
    - _Requirements: REQ-5, REQ-6_

- [ ] 5. 発注機能の実装 (手動発注)
  - [x] 5.1 IOrderService / OrderService の実装
    - `Services/IOrderService.cs` (public) / `Services/OrderService.cs` (internal) を作成
    - 発注登録メソッド: order_type='manual', order_status='承認待ち'
    - m_items から content_qty, package_type の自動表示ロジック
    - m_items.default_delivery_days からデフォルト納期日算出 (既定14日)
    - バリデーション、備考、async/await
    - _Requirements: REQ-2_

  - [ ]* 5.2 OrderService のユニットテスト作成
    - デフォルト納期日計算のテスト
    - バリデーションエラーケースのテスト
    - order_type, order_status の初期値テスト
    - _Requirements: REQ-2_

  - [x] 5.3 発注入力 Razor ページの作成
    - `Areas/Material/Pages/Orders/Create.cshtml` + `Create.cshtml.cs`
    - 品目選択時の content_qty / package_type 自動表示
    - デフォルト納期日の自動設定
    - フォームバリデーション
    - _Requirements: REQ-2_

- [ ] 6. MRP ロジックの実装
  - [x] 6.1 IConsumptionForecastProvider / ManualForecastProvider の実装
    - `Services/IConsumptionForecastProvider.cs` (public) を作成
    - `Services/ManualForecastProvider.cs` (internal) を作成
    - t_consumption_forecasts テーブルから手動入力の消費予測を取得 (source_id=manual)
    - 将来の ProductionPlanProvider / BomExplosionProvider 拡張を考慮したインターフェース設計
    - _Requirements: REQ-3a_

  - [x] 6.2 消費予測入力 Razor ページの作成
    - `Areas/Material/Pages/Forecasts/Index.cshtml` + `Index.cshtml.cs`
    - t_consumption_forecasts への手動入力フォーム
    - _Requirements: REQ-3a_

  - [x] 6.3 IRequirementCalculationService / RequirementCalculationService の実装
    - `Services/IRequirementCalculationService.cs` (public) / `Services/RequirementCalculationService.cs` (internal) を作成
    - MRP計算エンジン: 総所要量→正味所要量→ロットサイジング→リードタイムオフセット→計画オーダー
    - 正味所要量 = 総所要量 - 手持在庫 - 入庫予定 + 安全在庫
    - ロットサイジング: lot_for_lot または fixed_qty
    - リードタイムオフセット: order_date = need_date - lead_time_days
    - 計算結果を t_order_forecasts に保存
    - async/await パターンで実装
    - _Requirements: REQ-3b_

  - [ ]* 6.4 MRP計算のプロパティベーステスト作成 (xUnit + FsCheck.Xunit)
    - **Property 1: 正味所要量の計算整合性** — Net = Gross - OnHand - ScheduledReceipts + SafetyStock が常に成立
    - **Validates: REQ-3b**

  - [ ]* 6.5 MRP計算のプロパティベーステスト作成 (ロットサイジング)
    - **Property 2: ロットサイジングの正確性** — lot_for_lot の場合は計画数量 = 正味所要量、fixed_qty の場合は計画数量 >= 正味所要量 かつ fixed_qty の倍数
    - **Validates: REQ-3b**

  - [ ]* 6.6 MRP計算のプロパティベーステスト作成 (リードタイムオフセット)
    - **Property 3: リードタイムオフセットの正確性** — order_date = need_date - lead_time_days が常に成立
    - **Validates: REQ-3b**

  - [ ]* 6.7 MRP計算のユニットテスト作成
    - 正味所要量が負にならないケースのテスト
    - 安全在庫を考慮した計算テスト
    - 複数品目の一括計算テスト
    - _Requirements: REQ-3b_

- [ ] 7. チェックポイント - MRP ロジックの確認
  - 全テストが通ることを確認し、ユーザーに質問があれば確認する。

- [ ] 8. アラートサービスと仮発注の実装
  - [x] 8.1 IAlertService / AlertService の実装
    - `Services/IAlertService.cs` (public) / `Services/AlertService.cs` (internal) を作成
    - 最低在庫アラート判定: Red / Orange / Yellow / Green レベル
    - async/await パターンで実装
    - _Requirements: REQ-3c_

  - [ ]* 8.2 AlertService のユニットテスト作成
    - 各アラートレベル (Red/Orange/Yellow/Green) の閾値判定テスト
    - _Requirements: REQ-3c_

  - [x] 8.3 仮発注生成ロジックの実装
    - MRP計算結果 (t_order_forecasts) から仮発注 (order_type='provisional') を生成
    - OrderService に仮発注生成メソッドを追加
    - _Requirements: REQ-3d_

  - [x] 8.4 MRP結果表示・アラート Razor ページの作成
    - `Areas/Material/Pages/Mrp/Index.cshtml` + `Index.cshtml.cs`
    - MRP計算結果の一覧表示
    - アラートレベルの色分け表示 (Red/Orange/Yellow/Green)
    - 仮発注生成ボタン
    - _Requirements: REQ-3b, REQ-3c, REQ-3d_

- [ ] 9. 承認ワークフローの実装
  - [x] 9.1 IApprovalService / ApprovalService の実装
    - `Services/IApprovalService.cs` (public) / `Services/ApprovalService.cs` (internal) を作成
    - ステータス遷移: 承認待ち→承認済み→発注済み, 承認待ち→却下
    - 一括承認 (チェックボックス選択)
    - approved_at / approved_by の記録
    - async/await パターンで実装
    - _Requirements: REQ-4_

  - [ ]* 9.2 ApprovalService のプロパティベーステスト作成 (ステータス遷移)
    - **Property 4: ステータス遷移の整合性** — 承認待ち→承認済み→発注済み、承認待ち→却下 のみ許可され、不正な遷移は拒否される
    - **Validates: REQ-4**

  - [ ]* 9.3 ApprovalService のユニットテスト作成
    - 一括承認の正常系テスト
    - 不正なステータス遷移の拒否テスト
    - approved_at / approved_by の記録テスト
    - _Requirements: REQ-4_

  - [x] 9.4 承認一覧・承認操作 Razor ページの作成
    - `Areas/Material/Pages/Approvals/Index.cshtml` + `Index.cshtml.cs`
    - チェックボックスによる一括承認 UI
    - 承認・却下ボタン
    - 印刷機能
    - _Requirements: REQ-4_

- [ ] 10. 入庫機能の実装
  - [x] 10.1 IReceivingService / ReceivingService の実装
    - `Services/IReceivingService.cs` (public) / `Services/ReceivingService.cs` (internal) を作成
    - t_receivings への入庫記録
    - StockService 経由で stock_qty を増加
    - 分割入庫対応、完了ステータス管理
    - async/await パターンで実装
    - _Requirements: REQ-5_

  - [ ]* 10.2 ReceivingService のプロパティベーステスト作成 (在庫整合性)
    - **Property 5: 入庫時の在庫整合性** — 入庫数量分だけ stock_qty が正確に増加する
    - **Validates: REQ-5**

  - [ ]* 10.3 ReceivingService のユニットテスト作成
    - 分割入庫のテスト
    - 完了ステータス判定テスト
    - _Requirements: REQ-5_

  - [x] 10.4 入庫 Razor ページの作成
    - `Areas/Material/Pages/Receivings/Index.cshtml` + `Index.cshtml.cs`
    - 入庫登録フォーム、分割入庫対応
    - _Requirements: REQ-5_

- [ ] 11. 出庫機能の実装
  - [x] 11.1 IDispatchService / DispatchService の実装
    - `Services/IDispatchService.cs` (public) / `Services/DispatchService.cs` (internal) を作成
    - t_dispatches への出庫記録
    - StockService 経由で stock_qty を減少
    - 在庫 >= 出庫数量 のバリデーション
    - 検索・フィルタ・ソート対応
    - async/await パターンで実装
    - _Requirements: REQ-6_

  - [ ]* 11.2 DispatchService のプロパティベーステスト作成 (在庫整合性)
    - **Property 6: 出庫時の在庫整合性** — 出庫数量分だけ stock_qty が正確に減少し、在庫不足時はエラーとなる
    - **Validates: REQ-6**

  - [ ]* 11.3 DispatchService のユニットテスト作成
    - 在庫不足時のバリデーションエラーテスト
    - 検索・フィルタ条件のテスト
    - _Requirements: REQ-6_

  - [x] 11.4 出庫 Razor ページの作成
    - `Areas/Material/Pages/Dispatches/Index.cshtml` + `Index.cshtml.cs`
    - 出庫登録フォーム、検索・フィルタ・ソート UI
    - _Requirements: REQ-6_

- [ ] 12. チェックポイント - 入出庫機能の確認
  - 全テストが通ることを確認し、ユーザーに質問があれば確認する。

- [ ] 13. 納期監視機能の実装
  - [x] 13.1 納期監視ロジックの実装
    - OrderService または専用メソッドで納期超過判定を実装
    - 残日数計算、年月フィルタ対応
    - async/await パターンで実装
    - _Requirements: REQ-7_

  - [x] 13.2 納期監視 Razor ページの作成
    - `Areas/Material/Pages/DeliveryMonitor/Index.cshtml` + `Index.cshtml.cs`
    - 納期超過アラート表示
    - 残日数表示、年月フィルタ UI
    - _Requirements: REQ-7_

- [x] 14. 統合とワイヤリング
  - [x] 14.1 DI 登録の最終確認と統合
    - `MaterialModuleExtensions.AddMaterialModule` に全サービスの登録を確認
    - 全 Razor ページのルーティング確認
    - 認可ポリシー "DbPermissionCheck" の適用確認
    - _Requirements: REQ-1_

  - [ ]* 14.2 統合テストの作成
    - 発注→承認→入庫→出庫の一連フローのテスト
    - MRP計算→仮発注生成→承認フローのテスト
    - _Requirements: REQ-2, REQ-3, REQ-4, REQ-5, REQ-6_

- [x] 15. 最終チェックポイント - 全テスト実行と最終確認
  - 全テストが通ることを確認し、ユーザーに質問があれば確認する。

## Notes

- `*` マーク付きタスクはオプションで、MVP では省略可能
- 各タスクは特定の要件を参照しトレーサビリティを確保
- チェックポイントで段階的に検証を実施
- プロパティベーステストは xUnit + FsCheck.Xunit で実装
- ユニットテストは具体的なケースとエッジケースを検証
- DemoModule パターンに準拠: public インターフェース + internal 実装クラス
