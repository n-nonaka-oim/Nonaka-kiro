---
inclusion: manual
---

# エージェント起動コマンド（PrintAgent / SmtpAgent）

MaterialModule の帳票出力で使うワーカー（Windows Service 系）のローカル起動コマンド。
`#Agent` でチャットに取り込んで参照する（常時インクルードはしない）。

## PrintAgent（PDFエージェント：サーバ登録プリンタへサイレント印刷）

```cmd
dotnet run --project \\ojiadm23120073\Labs\WindowsService\PrintAgent
```

- 印刷キュー（`t_print_queue`）を消費し、指定プリンタへ印刷する。
- 外部出力(ii)（Dispatches `dispatch_request`）や PrintSettings のテスト印刷はこのエージェント稼働が前提。
- 対象プリンタが載るマシンで起動する（例：`OJP-33094` は machine=OJIADM23120069）。

## SmtpAgent（SMTPエージェント：メール/FAX 送信）

```cmd
dotnet run --project \\ojiadm23120073\Labs\WindowsService\SmtpAgent
```

- 送信キュー（`t_smtp_queue`）を消費し、メール/FAX を送信する。
- PrintSettings のテストメール送信や FAX 投入はこのエージェント稼働が前提。
