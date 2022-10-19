# isucon-toolkit
ISUCONにおいて初動を速くしたり、何度もやる動作を簡単にするためのツール群です。

## 準備

1. `cp env-template.sh env.sh`を実行する
2. `env.sh`を編集する
3. `toolkit.mk`の空欄をできるだけ埋めておく。埋めていないところは後で埋めることになります。
3. `setup.sh`を実行する

## setup.sh
複数のサーバーの環境をまとめて整えるスクリプトです。`setup.sh`を実行すると以下の処理が行われます。

- ローカル環境からサーバーに必要なファイルをコピーする
- ツールをインストールする
- gitの設定を行なう
- ssh鍵を作成する。作成した公開鍵を他のサーバーに送ることでサーバー間でsshできるようにする

詳しくは`setup-internal.mk`をご覧ください。一方、以下の処理は**行われません**。

- MySQL、Nginxの設定を行なう
- アプリケーションをgitで管理する

デフォルトではローカル環境のファイルと同名のファイルがサーバーにすでに存在する場合、そのファイルをコピーしません。
コピーしたい場合は`-f`を付けてください。

## toolkit.mk
典型的な処理をまとめたMakefileです。以下のコマンドを持ちます。

- analyze: MySQL、Nginx、SQLiteのログを解析します。
- analyze-mysql: MySQLのログを解析します。
- analyze-nginx: Nginxのログを解析します。内部ではalpが使われています。設定ファイルは`/home/user/alp/config.yml`にあります。
- analyze-sqlite: SQLiteのログを解析します。内部ではdsqが使われています。dsqが使うSQL文は適宜変更してください。
- before-bench: ログロテートとシステムの再起動を行ないます。
- bench: ベンチマーカーを動かします。
事前に`/home/user/env.sh`において`BENCHMARK_SERVER`にベンチマークサーバーのアドレスを設定しておく必要があります。
ベンチマーカーの名前は`~/bench/bench`である必要があります。
- log-rotate: ログロテートを行ないます。
- restart: システムの再起動を行ないます。
- sync-all: **すべての**サーバー内のファイルをリモートレポジトリと同期します。`BRANCH=(ブランチ名)`を付けると与えられたブランチに切り替わります。
- sync: コマンドを実行しているサーバー内のファイルをリモートレポジトリと同期します。`BRANCH=(ブランチ名)`を付けると与えられたブランチに切り替わります。

`setup.sh`の実行後、`toolkit.mk`は`/home/user/Makefile`にあります。使い方は以下の通りです。

- カレントディレクトリを`/home/user`にした上で`make (コマンド)`
- `/home/user`以外のところから使いたいときは`make -f /home/user/Makefile (コマンド)`。何度も実行するときはシェルのコマンド検索機能を使うと楽です
- ローカル環境から実行したいときは`ssh (サーバー) make -f /home/user/Makefile (コマンド)`
