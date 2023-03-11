# isucon-toolkit
ISUCONにおいて初動を速くしたり、何度もやる動作を簡単にするためのツール群です。

サーバー環境の整備担当は[サーバー環境を整備する](#サーバー環境を整備する)、それ以外のメンバーは[典型的な操作を行なう](#典型的な操作を行なう)を見てください。

## 最初にやること
ローカル環境に[gh](https://github.com/cli/cli)をインストールし、アカウントの認証を済ませてください。

## サーバー環境を整備する

0. 大会で指定されたユーザー名でログインできるようにする。最初からSSHできるユーザー名と大会で指定されたユーザー名が異なる場合は設定が必要です。特に過去の回の環境を構築するときは注意してください。
1. `cp env-template.sh env.sh`を実行する。
2. `env.sh`を編集する。`env.sh`にはセットアップに関する設定とコマンドに関する設定がありますが、この時点ではセットアップに関する設定のみが必須です。
3. `setup.sh`を実行する。
4. `env.sh`の残りの設定を行なう。

最初からSSHできるユーザー名と大会で指定されたユーザー名が異なる場合、以下のスクリプトをすべてのサーバーについて実行してください。
```
./ssh-pass-id.sh -i (あなたの公開鍵へのパス) -u (指定されたユーザー名) (SSH可能なユーザー名)@(サーバーのアドレス)
```

`setup.sh`は複数のサーバーの環境をまとめて整備するスクリプトです。実行すると以下の処理が行われます。

- ローカル環境からサーバーに必要なファイルをコピーする
- ツールをインストールする
- gitの設定を行なう
- チームメンバーのssh公開鍵をサーバーに送る
- ssh鍵を作成する。作成した公開鍵を他のサーバーに送ることでサーバー間でsshできるようにする。また、GitHubにデプロイキーとして登録し、サーバーからpush、pullができるようにする。

詳しくは`setup-internal.mk`をご覧ください。一方、以下の処理は**行われません**。

- アプリケーションをgitで管理する
- MySQL、Nginxの設定を行なう

## 典型的な操作を行なう
典型的な操作をまとめたMakefileが`~/Makefile`にあります。このMakefileは以下のコマンドを持ちます。

- analyze: MySQL、Nginx、SQLiteのログを解析します。
- analyze-mysql: MySQLのログを解析します。
- analyze-nginx: Nginxのログを解析します。内部ではalpが使われています。設定ファイルは`~/alp/config.yml`にあります。
- analyze-sqlite: SQLiteのログを解析します。内部ではdsqが使われています。dsqが使うSQL文は適宜変更してください。
- before-bench: ログロテートとシステムの再起動を行ないます。
- bench: ベンチマーカーを動かします。
- log-rotate: ログロテートを行ないます。
- restart: システムの再起動を行ないます。
- sync-all: **すべての**サーバー内のファイルをリモートレポジトリと同期します。`BRANCH=(ブランチ名)`を付けると与えられたブランチに切り替わります。
- sync: コマンドを実行しているサーバー内のファイルをリモートレポジトリと同期します。`BRANCH=(ブランチ名)`を付けると与えられたブランチに切り替わります。

`~/Makefile`は次のようにして使います。

- ホームディレクトリをカレントディレクトリにした上で`make (コマンド)`
- ホームディレクトリ以外の場所から使いたいときは`make -f ~/Makefile (コマンド)`。何度も実行するときはシェルのコマンド検索機能を使うと楽です
- ローカル環境から実行したいときは`ssh (サーバー) make -f ~/Makefile (コマンド)`

sync、sync-allが各サーバーに行なう操作は`~/sync.sh`に記述されています。サーバー特有の操作が必要な場合は対象のサーバーの`sync.sh`のみを書き換えてください。
