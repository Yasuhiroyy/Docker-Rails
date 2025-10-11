# 構築の全体フロー（ざっくり把握）

1. Dockerfile、docker-compose.ymlなどのファイルを作成
1. Rails アプリ本体を生成
1. Dockerイメージをビルド
1. 依存関係をインストール
1. DB（MySQL）を初期化
1. Rails サーバーを起動（Puma）


# 構成図
![スクリーンショット 2025-09-29 1.47.31.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/4081358/47e1e552-603f-429a-b935-4cd2a4bb71fb.png)

# 構築環境

### ホストOS
macOS Sonoma 15.1（Apple M1チップ）

### tool
Docker Desktop　v4.47.0

### Docker images
- nginx：nginx:1.25.2-alpine
- app：ruby:3.4.1
- db：mysql:8.0.28
- php:8.3-fpm-alpine


# 各ファイルの役割と解説

## ディレクトリ
- Railsのソースは~/git/github/menta/raills
- Composeなどは~/git/github/menta/docker/div

```
menta/                      
├── rails/                  ← Railsアプリ本体
└──  docker 
      ├── Gemfile
      ├── Gemfile.lock
      ├── package.json
      ├── yarn.lock
      ├── .env 
      └── div /
           ├──docker-compose.yml 
           ├── appx/
           │   └── Dockerfile
           ├── nginx/
           │   ├── Dockerfile
           │   ├── nginx.conf         
           │   └── dev-rails.techbull.cloud.conf         
           ├── mysql/
           │   ├── Dockerfile
           │   └── db_data/             
           └── redis/
               └── data/  

```

## docker-compose.yml
配置場所：~git/github/menta/docker/div/divdocker-compose.yml

```
volumes:
  puma-sock:
  bundle-gems: 

services:
  nginx:
    container_name: rails-nginx
    build: ./nginx/
    image: rails-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
     - ~/git/github/menta/rails:/var/www/app:delegated
     - puma-sock:/var/run/puma
     - ./dev-rails.techbull.cloud.pem:/etc/nginx/certs/dev-rails.techbull.cloud.pem:ro
     - ./dev-rails.techbull.cloud-key.pem:/etc/nginx/certs/dev-rails.techbull.cloud-key.pem:ro
    tty: true
    depends_on:
      - app


  app:
    container_name: rails-app
    build:
      context:  ../../rails
      dockerfile: ../../docker/dev/app/Dockerfile
    image: rails-app
    volumes:
     - ~/git/github/menta/rails:/var/www/app:delegated
     - puma-sock:/var/run/puma
     - bundle-gems:/usr/local/bundle 
    tty: true
    depends_on:
      - db
      - redis
    env_file:
      - .env 
  

  db:
    container_name: rails-db
    build: ./mysql/
    image: rails-db
    command: --default-authentication-plugin=mysql_native_password
    ports:
      - "3306:3306"
    environment:
      MYSQL_DATABASE: ${DATABASE_NAME}
      MYSQL_ROOT_PASSWORD: ${DATABASE_PASSWORD}
    env_file:
      - .env
     # ホストの db_data は使わず、Docker volume を使う
    volumes:
      - ./mysql/db_data:/var/lib/mysql

  redis:
    container_name: rails-redis
    image: redis:latest
    ports:
      - "6379:6379"
     # ホストの db_data は使わず、Docker volume を使う
    volumes:
      - ./redis/data:/data

```
### docker-compose.ymlの解説
### volumes
ここで宣言したボリュームをサービスの中でマウントすると、コンテナを削除してもデータが消えず 永続化 されます。
```
volumes:
  puma-sock:
  bundle-gems: 
```
- **共有ボリュームの定義**
    - `puma-sock`： **Rails (Puma) と Nginx が通信するための UNIX ソケットを保存する場所**。 Rails コンテナと Nginx コンテナで両方マウントすることで、Nginx が Puma にリクエストを渡せる。
    - `bundle-gems`：**Rails の gem をインストールする場所を永続化するための Docker ボリューム**

### services

### 1. `nginx` (リバースプロキシ)

```yaml

  nginx:
    container_name: rails-nginx
    build: ./nginx/
    image: rails-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
     - ~/git/github/menta/rails:/var/www/app:delegated
     - puma-sock:/var/run/puma
     - ./dev-rails.techbull.cloud.pem:/etc/nginx/certs/dev-rails.techbull.cloud.pem:ro
     - ./dev-rails.techbull.cloud-key.pem:/etc/nginx/certs/dev-rails.techbull.cloud-key.pem:ro
    tty: true
    depends_on:
      - app
```

- `build: ./nginx/` → `./nginx/Dockerfile` を元にイメージを作る
- `image: rails-nginx` →という名前をつける
- `ports: "-80:80 - "443:443""` → ホストの 80 番、443番ポートをコンテナの 80 番、443番にマッピング
・ホストから `https://localhost` でアクセス可能
- `volumes:  ホスト側のパス:コンテナ側のパス:オプション`
・`~/git/github/menta/rails:/var/www/app`  → Rails のソースコードをコンテナに共有
・`puma-sock:/var/run/puma` → Puma ソケットを共有して Rails にリクエストを渡す
- `認証鍵、公開鍵`：これを行うことで ポート443が利用できhttps通信が実行可能になる



- `tty`: true は docker-compose.yml の設定オプション のひとつで、コンテナに「疑似ターミナル（TTY）」を割り当てるかどうかを指定
- `depends_on`: app → app コンテナが起動してから Nginx を起動

:::note info
ソースコードをマウントする理由

マウントすることで、ホストでの変更がコンテナ側でも適用される！
:::

### 2. `app` (Railsアプリ)

```yaml
  app:
    container_name: rails-app
    build:
      context:  ../../rails
      dockerfile: ../../docker/dev/app/Dockerfile
    image: rails-app
    volumes:
     - ~/git/github/menta/rails:/var/www/app:delegated
     - puma-sock:/var/run/puma
     - bundle-gems:/usr/local/bundle 
    tty: true
    depends_on:
      - db
      - redis
    env_file:
      - .env 
```



- `Context`：Dockerがbuildする際アクセスできるファイルの範囲
Railsアプリを生成する場所を記載

- `dockerfile`
:::note warn
Contextを使用した際のdockerfileのパス

Contextで指定したパスから相対パスで指定しないといけない
また、CopyはContextで設定しているファイル内しか確認できない
:::
- `volumes:`
    - アプリのソースコードをマウント。
    - `puma-sock` を Nginx と共有（Puma がここにソケットを作成）。
- `depends_on: db, redis` → DB と Redis が起動してから Rails を起動。
- `env_file:` .env を参照

### 3. `db` (MySQL)

```yaml
  db:
    container_name: rails-db
    build: ./mysql/
    image: rails-db
    command: --default-authentication-plugin=mysql_native_password
    ports:
      - "3306:3306"
    environment:
      MYSQL_DATABASE: ${DATABASE_NAME}
      MYSQL_ROOT_PASSWORD: ${DATABASE_PASSWORD}
    env_file:
      - .env
     # ホストの db_data は使わず、Docker volume を使う
    volumes:
      - ./mysql/db_data:/var/lib/mysql
```

- `build: ./mysql/` → カスタム MySQL イメージをビルド。
- `command: `MySQL 8 のデフォルト認証方式を Rails 互換の `mysql_native_password` に変更

- `ports: "3306:3306"` → ホストからも MySQL に接続できる。
- `environment:` .envでまとめて管理することで、コードにパスワードを直書きせず安全・便利に設定可能
- `volumes: ./mysql/db_data:/var/lib/mysql` → DBデータを永続化。

### 4. `redis` (セッション・ジョブキュー)

```yaml
  redis:
    container_name: rails-redis
    image: redis:latest
    ports:
      - "6379:6379"
    volumes:
      - ./redis/data:/data
```

- `image: redis:latest` → Redis公式イメージを利用。
- `ports: "6379:6379"` → ホストからも接続可能。
- `volumes: ./redis/db_data:/data` → データを永続化。


##  Dockerfile

### Dockerfile(nginx)
配置場所：~git/github/menta/docker/div/nginx/Dockerfile

```
FROM nginx:1.25.2-alpine

# Setup UTC+9
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# install packages
RUN apk update && \
    apk upgrade && \
    apk add --update --no-cache \
    bash \
    sudo \
    tzdata \
    vim

## nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/dev-rails.techbull.cloud.conf /etc/nginx/conf.d/dev-rails.techbull.cloud.conf

EXPOSE 80

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
```

### Dockerfile(nginx) 解説

```docker
FROM nginx:1.25.2-alpine

```

- ベースイメージに `nginx:1.25.2-alpine` を指定



```docker
# Setup UTC+9
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*
```

**`RUN`** は「その時点のイメージの中でコマンドを実行して、その結果を新しいレイヤーとして保存する」
**タイムゾーンを日本時間 (UTC+9, Asia/Tokyo) に設定**する処理


```docker
# install packages
RUN apk update && \
    apk upgrade && \
    apk add --update --no-cache \
    bash \
    sudo \
    tzdata \
    vim
```

- 追加で Alpine Linux 上に必要なパッケージをインストール


```docker
## nginx
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/dev-rails.techbull.cloud.conf /etc/nginx/conf.d/dev-rails.techbull.cloud.conf

```

- ローカルの `conf/` ディレクトリにある設定ファイルをコンテナにコピー
    - `nginx.conf` → Nginx のメイン設定ファイル
    - `dev-rails.techbull.cloud.conf` → バーチャルホストの設定ファイル（サーバーブロック）




```docker
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

```

- コンテナ起動時に実行するコマンド
- `daemon off;` を指定することで、Nginx をフォアグラウンドで実行
    
    （コンテナはプロセスが終了すると落ちるので、デーモン化せず動かし続ける）

---
### nginxの設定
配置場所：~git/github/menta/docker/div/nginx/conf/nginx.conf

```
user  root;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
log_format main '[nginx]\t'
                  'time:$time_iso8601\t'
                  'server_addr:$server_addr\t'
                  'host:$remote_addr\t'
                  'method:$request_method\t'
                  'reqsize:$request_length\t'
                  'uri:$request_uri\t'
                  'query:$query_string\t'
                  'status:$status\t'
                  'size:$body_bytes_sent\t'
                  'referer:$http_referer\t'
                  'ua:$http_user_agent\t'
                  'forwardedfor:$http_x_forwarded_for\t'
                  'reqtime:$request_time\t'
                  'apptime:$upstream_response_time\t';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    tcp_nopush     on;
    keepalive_timeout  65;
    gzip  on;
	include /etc/nginx/conf.d/*.conf;
}
```
---

### nginx バーチャルホスト
配置場所：~git/github/menta/docker/div/nginx/conf/dev-rails.techbull.cloud.conf

```# Puma がこのソケットを listen しているから、Rails に届ける
upstream app {
    server unix:/var/run/puma/puma.sock;
}

server {
    listen 80;
    server_name dev-rails.techbull.cloud;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name dev-rails.techbull.cloud;

    root /var/www/app/public;
    ssl_certificate /etc/nginx/certs/dev-rails.techbull.cloud.pem;
    ssl_certificate_key /etc/nginx/certs/dev-rails.techbull.cloud-key.pem;
    access_log /var/log/nginx/dev.access.log;
    error_log  /var/log/nginx/dev.error.log;

location / {
    # 静的ファイルがあれば Nginx が返す
    try_files $uri/index.html $uri @app;
}

location @app {
    # 無ければ Puma にリクエストを渡す
    proxy_pass http://app;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
  client_max_body_size 100m;
  error_page 404             /404.html;
  error_page 505 502 503 504 /500.html;
  keepalive_timeout 5;
}  

```
---
### Dockerfile(app)
配置場所：~git/github/menta/docker/div/app/Dockerfile

```
FROM ruby:3.4.1

# 作業ディレクトリの設定
ENV APP_ROOT = /var/www/app
WORKDIR ${APP_ROOT}

# Pumaソケット用ディレクトリ作成
RUN mkdir -p /var/run/puma /tmp/sockets

# Node.js 18 LTS + Yarn のセットアップ
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# 必要なパッケージをインストール
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        default-libmysqlclient-dev \
        locales \
        vim \
        nodejs \
        yarn \
        redis-tools \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# ロケール設定
RUN localedef -f UTF-8 -i en_US en_US.UTF-8

# タイムゾーンを日本に設定
RUN cp -p /usr/share/zoneinfo/Japan /etc/localtime

# Bundler インストール（バージョン固定）
RUN gem install bundler -v 2.5.23

# Gemfile と package.json を先にコピーして依存関係をインストール
COPY Gemfile Gemfile.lock $APP_ROOT/
RUN bundle install

# yarn install
COPY package.json yarn.lock $APP_ROOT/
RUN yarn install --check-files

# Puma 用ポート（メモ用）
EXPOSE 80

# デフォルトコマンド（Puma 起動）
CMD ["bundle", "exec", "puma", "-C", "config/dev_puma-socket.rb", "-e", "development"]


```
### Dockerfile(app) 解説
```docker
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" \
      | tee /etc/apt/sources.list.d/yarn.list

```



 **Node.js の公式インストール準備**
    

    
- `curl` は「インターネットからファイルを取ってくるコマンド」
- Node.js の公式サイトから「Node.js 18 をインストールするための設定スクリプト」をダウンロードして実行している

**Yarn のカギを登録**
  
- Linux で「外部のソフトをインストールするときに、その配布元が本物かどうか確認する仕組み」が **GPG鍵**
- ここでは Yarn 公式の「鍵」を登録している
 
 **Yarn のリポジトリを登録**   
- Linux の `apt` コマンドが「どこからアプリをダウンロードするか」を教えている
- ここで Yarn の配布場所（リポジトリ）を追加


:::note info
なんで Node.js と Yarn が必要？

Rails は Ruby だけで動くわけじゃなくて、**JavaScript のビルド** も必要になる
- 画面の動きを作る JavaScript
- CSS の変換（Sass など）
- Rails 7 の jsbundling-rails / cssbundling-rails

:::


```docker
RUN gem install bundler -v 2.5.23
```

- Gem の依存管理ツール **Bundler** をインストール


Gemfile のコピーと bundle install

```docker
COPY Gemfile Gemfile.lock $APP_ROOT/
RUN bundle install
```

- Gemfile / Gemfile.lock をコンテナにコピー
・Gemfile：どのライブラリを使用するか宣言
・Gemfile.lock：使用したバージョンを固定
・package.json：どのJSパッケージを使用するか宣言
・yarn.lock：インストールしたパッケージのバージョンを宣言
- bundle install で Rails の依存ライブラリをインストール

 Puma 起動コマンド

```docker
CMD ["bundle", "exec", "puma", "-C", "config/dev_puma-socket.rb", "-e", "development"]
```

- コンテナ起動時に **Puma サーバーを立ち上げる**
- `C` で Puma の設定ファイル（ソケット利用など）を指定
- `e development` で開発環境モードで起動

### Dockerfile(mysql)
配置場所：~git/github/menta/docker/div/mysql/Dockerfile
```
FROM --platform=linux/x86_64 mysql:8.0.27

ENV TZ=Asia/Tokyo
ENV LC_ALL=ja_JP.UTF-8
ENV MYSQL_ALLOW_EMPTY_PASSWORD=yes

# 古い Buster のリポジトリを archive.debian.org に変更
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99disable-check-valid-until

# MySQL リポジトリを削除して GPG エラー回避
RUN rm -f /etc/apt/sources.list.d/mysql.list

# 基本パッケージインストール
RUN apt-get update && apt-get install -y --no-install-recommends \
        gnupg \
        wget \
        ca-certificates \
        lsb-release \
        locales \
        python3 \
        vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 日本語ロケール設定
RUN echo "ja_JP.UTF-8 UTF-8" > /etc/locale.gen && locale-gen ja_JP.UTF-8

# MySQL ログ・データディレクトリ作成
RUN touch /var/log/mysqld.log && chown mysql:adm /var/log/mysqld.log
RUN mkdir -p /var/mysql && chown mysql:adm /var/mysql && rm -rf /etc/mysql/conf.d

# カスタム設定コピー
COPY ./my.cnf /etc/mysql/

```
### Dockerfile(mysql) 解説


```docker
RUN sed -i 's|deb.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    sed -i 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99disable-check-valid-until
```
**古い Debian Buster リポジトリの対応**

- Debian Buster はすでに **公式サポート終了済み** → 標準の deb.debian.org / security.debian.org はもう使えない
- `archive.debian.org` に変更することでパッケージリストが取得可能になった
- `Check-Valid-Until "false"` で古いリリース情報の有効期限切れを無視

## Gemfile,Gemfile.lock
Railsや使用するライブラリ（Gem）の一覧
### Gemfile
```
source "https://rubygems.org"

ruby "3.4.1"

# Rails 本体
gem "rails", "~> 8.0", ">= 8.0.0.1"

# DB を MySQL に変更
gem "mysql2", ">= 0.5"

# Puma (アプリケーションサーバ)
gem "puma", "~> 6.0"

# アセット関連
gem "sprockets-rails"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

# 起動高速化 & タイムゾーン
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ mswin mswin64 mingw x64_mingw jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri mswin mswin64 mingw x64_mingw ]
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

### Gemfile.lock
ファイルを用意するだけでok

:::note info
bundle installが実行されると自動で書き込まれる
:::


## package.json,yarn.lock
JavaScript関連のライブラリ一覧

### package.json
```
{
  // プロジェクト名（任意。Railsでは通常 "sample" など）
  "name": "sample",

  // "true" の場合、npm公開レジストリに誤って公開されないようにする設定
  "private": true,

  // プロジェクトのバージョン（Railsで自動生成されるもの。基本はそのままでOK）
  "version": "0.1.0",

  // 本番・開発どちらでも必要な依存パッケージ（アプリで実際に使うもの）
  "dependencies": {
    // RailsのWebSocket機能を扱うライブラリ（ActionCable）
    "@rails/actioncable": "^7.1.0",

    // 画像やファイルアップロードなどを扱うライブラリ（ActiveStorage）
    "@rails/activestorage": "^7.1.0",

    // Rails 7で使われる高速ナビゲーション機能（Turbo Driveなど）
    "@hotwired/turbo-rails": "^7.1.0",

    // フロントエンドで使う軽量JSフレームワーク（Stimulus）
    "stimulus": "^3.2.1"
  },

  // 開発時にのみ必要なツールやビルド関連のパッケージ
  "devDependencies": {
    // JSやCSSをまとめる高速ビルドツール（Rails 7で標準採用）
    "esbuild": "^0.18.0"
  }
}

```

### yarn.lock.lock
ファイルを用意するだけでok

:::note info
yarn installが実行されると自動で書き込まれる
:::

## .env
DBの接続情報など、パスワードを外部に漏らさないように管理するファイル
以下は設定例です
```
DATABASE_HOST="db"
DATABASE_NAME="app-rails"
DATABASE_USER="root"
DATABASE_PASSWORD=""
DATABASE_SOCKET="/tmp/mysql.sock"
```

## config/dev_puma-socket.rb
:::note warn
このファイルだけはrailsアプリ作成後(実際の構築手順のステップ3.5)、
生成されたファイルに貼り付けます

:::
Rails（Puma）とNginxを連携させる設定ファイル

配置場所：~git/github/menta/rails/Config/dev_puma-socket.rb
```
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

```

# 実際の構築手順

## ステップ1：ファイルの用意
以下のファイルを準備する

- Dockerfile
- docker-compose.yml
- Gemfile / Gemfile.lock
- package.json / yarn.lock
- .env 

ホスト側の作業ディレクトリの作成：~/git/github/menta/rails
この中は最初は空っぽでOKです。

## ステップ2：composeファイルのある場所へ移動

まず、Docker Compose があるディレクトリに移動します。
```
$ cd ~/git/github/menta/docker/docker_rails/dev
```

docker compose コマンドは、現在のディレクトリにある docker-compose.yml を読み込む仕様です。
別の場所にいると「composeファイルが見つからない」というエラーが出るため、最初にここへ移動しておくのが確実です。


## ステップ3：Rails アプリ本体を生成

ターミナルにて以下を実行
```
$ docker-compose run --rm app rails new . --force --database=mysql
```

- rails new：Rails プロジェクトの骨組みを作成（多数のファイルを自動生成）

- .：カレントディレクトリ（/menta/rails）に生成

- force：既存のファイルがあっても上書き

- database=mysql：MySQL を使う設定で初期化

- rm：コマンド実行後、コンテナを自動削除

このコマンドは 一時的に app コンテナを起動し、Rails の初期構成を生成して終了 します。
サーバーはまだ動いていません。

## ステップ3.5：config/dev_puma-socket.rb を配置 ←

Rails アプリ内に作成済みの config/dev_puma-socket.rb に貼り付ける


## ステップ4：Dockerイメージをビルド
```
$ docker-compose build 
```

nginx/, app/, mysql/ の3つの Dockerfile をもとに、
rails-nginx, rails-app, rails-db の各イメージを構築します。



:::note info
Redis は image: redis:latest のため、ビルド不要（自動取得）
:::

## ステップ 5：依存関係をインストール
```
docker compose run --rm app bundle install
docker compose run --rm app yarn install
```


- bundle install → Gemfile に基づいて Ruby ライブラリをインストール

- yarn install → package.json に基づいて JavaScript ライブラリをインストール

- --rm → 実行用コンテナは終了後削除される

:::note info
Gemfile.lock や yarn.lock がホスト側に生成されます。
（Dockerfile 内で既に実行済みでも、ホスト側ファイル反映のため再実行が安全）
:::

## ステップ 6：DB（MySQL）を初期化

まず MySQL コンテナを起動：
```
docker compose up -d db
```

次に Rails コンテナからデータベースを作成：
```
docker compose run --rm app rails db:create
docker compose run --rm app rails db:migrate
```
🔍 解説

- db:create：MySQL 内に Rails 用 DB を新規作成

- db:migrate：スキーマ（テーブル構造）を適用

- .env の設定値と config/database.yml が一致していることを確認

# ステップ 5：Rails サーバーを起動（Puma）

```
docker compose up -d
```
- config/dev_puma-socket.rb で /var/run/puma/puma.sock にソケット作成

- pu- ma-sock ボリュームを通じて Nginx が Rails にリクエストを転送



## ステップ 6：ブラウザで確認

ブラウザでアクセス：
```
https://dev-rails.techbull.cloud/
```

初回アクセスで Rails の Welcome ページ が表示されれば成功！ 
![スクリーンショット 2025-09-29 1.56.05.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/4081358/c3d6718f-5f46-4868-8a47-4e1fce520171.png)

