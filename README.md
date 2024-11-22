# isucon-toolkit

ISUCONにおいて初動を速くしたり、何度もやる動作を簡単にするためのツール群です。

サーバー環境の整備担当は[サーバー環境を整備する](#サーバー環境を整備する)、それ以外のメンバーは[典型的な操作を行なう](#典型的な操作を行なう)を見てください。

## サーバー環境を整備する

0. 大会で指定されたユーザー名でログインできるようにする。最初からSSHできるユーザー名と大会で指定されたユーザー名が異なる場合は設定が必要です。特に過去の回の環境を構築するときは注意してください。
1. `cp env-template.sh env.sh`を実行する。
2. `env.sh`を編集する。`env.sh`にはセットアップに関する設定とコマンドに関する設定がありますが、この時点ではセットアップに関する設定のみが必須です。
3. GitHubでfine-grained personal access tokenを作成する ([参考](https://docs.github.com/ja/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#fine-grained-personal-access-token-の作成))。
   作成するtokenには(2)で指定した`GITHUB_REPO`への読み込み・書き込み権限を付けてください。
4. `read -r GITHUB_TOKEN`を実行し、(3)で作成したpersonal access tokenを入力する。
5. `setup.sh (サーバーのアドレス)`を実行する。`env.sh`のパスを自由に指定したいときは`--envfile ENVFILE`を使用してください。
6. `env.sh`の残りの設定を行なう。

`setup.sh`は以下の処理を行います。

- タイムゾーンを`Asia/Tokyo`に設定する
- ツールをインストールする
- Gitの設定を行なう
- アプリケーションをGitで管理する
- ローカル環境からサーバーに必要なファイルをコピーする

一方、以下の処理は**行いません**。

- MySQL、Nginxの設定を行なう
- チームメンバーのSSH公開鍵をサーバーに送る
- サーバーのSSH鍵を作成する

## 典型的な操作を行なう

`isutool`コマンドを使います。このコマンドはサブコマンドを持っています。
代表的なサブコマンドは以下の通りです。

- analyze: MySQL、Nginxなどのログを解析します。
- .analyze-mysql: MySQLのログを解析します。設定ファイルは`~/.isucon-toolkit/pt-query-digest/pt-query-digest.conf`にあります。
- .analyze-nginx: Nginxのログを解析します。内部ではalpが使われています。設定ファイルは`~/.isucon-toolkit/alp/config.yml`にあります。
- before-bench: ログロテートとシステムの再起動を行ないます。
- bench: ベンチマーカーを動かします。
  このコマンドを使う前に`env.sh`の`BENCHMARK_SERVER`にベンチマークサーバーのアドレスを指定する必要があります。
  また、そのサーバーにおいて、`cd ~/bench; ./bench`でベンチマーカーが動くようにする必要があります。
  **`bench`は引数なしで実行されるため、サーバーのアドレスなどが引数として必要な場合はオリジナルのベンチマーカーの名前を`bench-orig`などに変更し、それを引数付きで呼び出すスクリプトを`bench`としてください。**
- build: アプリケーションをコンパイルします。
- log-rotate: ログロテートを行ないます。
- mysql: MySQLサーバーを操作するためのCLIを起動します。
- restart: システムの再起動を行ないます。
- show-branch: アプリケーションのディレクトリ内での現在のブランチを表示します。
- switch-branch: アプリケーションのディレクトリ内でのブランチを変更します。

すべてのサブコマンドは`isutool help`で確認できます。
また、サブコマンドの詳細は`isutool help (サブコマンド名)`で確認できます。

補足事項:

- ローカル環境から実行したいときは`ssh (サーバー) isutool (サブコマンド)`
- 以前実行したサブコマンドを再度使うときはシェルのコマンド検索機能が便利です。
- `isutool`コマンドは補完が効きます。
