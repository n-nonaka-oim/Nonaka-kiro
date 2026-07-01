---
inclusion: fileMatch
fileMatchPattern: "**/clnCoCore/**"
---

> スコープ: 本書は CoCore（Auth）ソリューション（`clnCoCore`）固有。MaterialModule 等の作業には適用されない。

# Product Overview

ASP.NET Core 8.0のモジュラー認証・認可Webアプリケーション。Clean Architecture + Repository パターン。

主要機能:
- ASP.NET Core Identityによるユーザー認証
- コンテンツベース認可（URLパスからArea/Pageを自動解決し、所属・ロールのRankでDB照合）
- 複数所属のOR論理による認可判定
- パスワード有効期限管理とセッション検証ミドルウェア
- 日本語ローカライズ（Identity エラーメッセージ）
