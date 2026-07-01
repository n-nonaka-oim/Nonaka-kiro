# DB操作 競合対策設計書

## 最終更新: 2026-04-28

## 概要
多人数利用を想定し、DB操作の同時実行による不整合を防止する。

---

## 対策1: 発注番号採番のロック（最優先）

### 問題
GenerateOrderNoAsyncで同時に発注確定すると、同じ発注番号が採番される可能性がある。

### 対策
DBシーケンスまたはトランザクション+UPDLOCKで排他制御。

### 実装方針
- t_ordersへのINSERT/UPDATE時にトランザクションを使用
- 採番クエリに`WITH (UPDLOCK, HOLDLOCK)`を付与
- または、採番専用テーブル（m_sequences）で管理

---

## 対策2: 楽観的並行性制御（全テーブル共通）

### 問題
Read→判断→Writeの間に他ユーザーが変更すると、古いデータで上書きされる。

### 対策
t_ordersにrow_version（タイムスタンプ）カラムを追加し、更新時にバージョンチェック。

### 実装方針
- TOrder.csに`[Timestamp] public byte[] RowVersion`を追加
- EF CoreがUPDATE時にWHERE row_version = @oldVersionを自動付与
- バージョン不一致時はDbUpdateConcurrencyException → ユーザーに再読み込みを促す

---

## 対策3: 承認操作の排他制御

### 問題
同じ発注を2人が同時に承認/差戻しする可能性。

### 対策
楽観的並行性制御（対策2）で対応。RowVersionチェックで後から操作した方がエラーになる。

---

## 対策4: 在庫操作の排他制御（将来）

### 問題
同時入出庫で在庫数量が不整合になる可能性。

### 対策
StockServiceのIncrement/Decrementでトランザクション+行ロックを使用。

---

## 実装順序

1. ✅ 発注番号採番のトランザクション化
2. ✅ t_ordersにrow_versionカラム追加
3. ✅ 承認・差戻し・確定操作にConcurrencyExceptionハンドリング追加
4. ⏸ 在庫操作の排他制御（在庫機能実装時に対応）
