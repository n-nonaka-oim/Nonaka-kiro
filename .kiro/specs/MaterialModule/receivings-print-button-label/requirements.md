# Requirements Document

## Introduction

入庫管理画面（MaterialModule / Areas/Material/Pages/Receivings/Index.cshtml）に配置された PDF 出力ボタンの表示ラベルを「入庫伝票」から「印刷」へ変更する。変更対象は当該ボタンのラベル文言1点のみとし、ボタンの機能・class・アイコン・活性制御、ダウンロードファイル名（帳票名）、PDF 内容および code-behind（`OnGetExportPdfAsync`）は現状維持とする。clnCoCore（MainWeb / AuthModule / SharedCore 等）は変更しない。

## Glossary

- **入庫管理画面**: `MaterialModule/Areas/Material/Pages/Receivings/Index.cshtml` に対応する Razor Pages ビュー。
- **PDF出力ボタン**: 入庫管理画面上の `onclick="downloadReceivingPdf()"` を持つ、class `btn btn-outline-danger btn-sm text-nowrap`・アイコン `bi bi-file-pdf` のボタン要素。
- **ダウンロードファイル名**: PDF ダウンロード時のファイル名 `入庫伝票_yyyyMMdd_yyyyMMdd.pdf`（帳票名）。

## Requirements

### Requirement 1: ボタンラベルの変更

**User Story:** 入庫管理画面の利用者として、PDF出力ボタンのラベルを「印刷」と表示してほしい。ボタンの役割（印刷用PDFの出力）を直感的に把握できるようにするため。

#### Acceptance Criteria

1. WHERE 入庫管理画面が表示されるとき, THE 入庫管理画面 SHALL PDF出力ボタンのラベル文字列として「印刷」を表示する。
2. THE 入庫管理画面 SHALL PDF出力ボタンの `onclick="downloadReceivingPdf()"` を変更前の状態で維持する。
3. THE 入庫管理画面 SHALL PDF出力ボタンの class（`btn btn-outline-danger btn-sm text-nowrap`）を変更前の状態で維持する。
4. THE 入庫管理画面 SHALL PDF出力ボタンのアイコン（`bi bi-file-pdf`）を変更前の状態で維持する。
5. WHILE 一覧の TotalCount が 0 である間, THE 入庫管理画面 SHALL PDF出力ボタンを disabled 状態で表示する。

### Requirement 2: 変更範囲の限定

**User Story:** 開発担当者として、今回の変更を当該ボタンのラベル文言1点に限定してほしい。副作用や意図しない挙動変更を防ぐため。

#### Acceptance Criteria

1. THE ダウンロードファイル名 SHALL `入庫伝票_yyyyMMdd_yyyyMMdd.pdf` の帳票名を変更前の状態で維持する。
2. THE PDF出力ボタン SHALL 出力される PDF の内容を変更前の状態で維持する。
3. THE 入庫管理画面 SHALL code-behind の `OnGetExportPdfAsync` を変更前の状態で維持する。
4. THE 入庫管理画面 SHALL Requirement 1 のラベル変更を除き、入庫管理画面の他ボタンおよび他要素を変更前の状態で維持する。
