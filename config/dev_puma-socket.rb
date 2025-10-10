# Rails アプリを読み込む
require_relative 'application'
Rails.application.load_tasks

# スレッド設定
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# ログ出力先
stdout_redirect 'log/puma.stdout.log', 'log/puma.stderr.log'

# ワーカータイムアウト（開発環境のみ）
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# ソケット指定
bind "unix:///var/run/puma/puma.sock"

# 環境
environment ENV.fetch("RAILS_ENV") { "development" }

# PIDファイル
pidfile ENV.fetch("PIDFILE") { "/var/run/puma/server.pid" }

# tmp_restart プラグイン（Rails再起動用）
plugin :tmp_restart
