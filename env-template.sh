#!/usr/bin/env bash

################################################################################
# セットアップに関する設定
################################################################################
# `setup.sh`を実行する前に空欄を埋めてください

# チームのメールアドレス
GIT_EMAIL=

# チームの名前
GIT_USERNAME=

# アプリケーションのプログラムや設定ファイルを管理するGitHubのレポジトリ
# GITHUB_REPO=account_name/repository_name
GITHUB_REPO=

# アプリケーションのプログラムや設定ファイルを管理するサーバー上のディレクトリのパス
REPO_DIR=

# チームメイトのGitHubアカウント
TEAMMATE_GITHUB_ACCOUNTS=()

# サーバーのリスト
# `ssh (指定に用いる文字列)`でそれぞれのサーバーにアクセスできる必要があります
# SERVERS=("s1" "s2" "s3")
SERVERS=()

# サーバー上で使うユーザー名
REMOTE_USER=

################################################################################
# コマンドに関する設定
################################################################################
# `make (コマンド)`を実行する前に空欄を埋めてください

# アプリケーションを動かしているサービスの名前
SERVICE_NAME=

# MySQLのユーザー名
MYSQL_USER=root

# MySQLのパスワード
MYSQL_PASSWORD=root

# Nginxのアクセスログのパス
NGINX_ACCESS_LOG=/var/log/nginx/access.log

# MySQLのスロークエリログのパス
MYSQL_SLOW_LOG=/var/log/mysql/slow.log

# SQLiteのログのパス
SQLITE_TRACE_LOG=

# ログの解析結果を保管するディレクトリのパス
STATS_DIR=

# ベンチマークサーバー
# 注意事項
# 1. 競技者用サーバーからアクセス可能なアドレスを指定してください
# 2. AWSのEC2インスタンスを指定する場合、パブリックアドレスは起動のたびに変わる可能性が
#    あるので、プライベートアドレスを指定することを推奨します
# 3. 指定したサーバーではベンチマーカーが`cd ~/bench; ./bench`で動作する必要があります
# 4. `bench`は引数なしで実行されます。サーバーのアドレスなどが引数として必要な場合は
#    オリジナルのベンチマーカーの名前を`bench-orig`などに変更し、それを引数付きで呼び出す
#    スクリプトを`bench`としてください。
BENCHMARK_SERVER=
