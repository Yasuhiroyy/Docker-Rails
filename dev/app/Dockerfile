FROM ruby:3.4.1

# 作業ディレクトリの設定
ENV APP_ROOT=/var/www/app
WORKDIR $APP_ROOT

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

# Bundler インストール（バージョン固定
RUN gem install bundler -v 2.5.23

# Gemfile と package.json を先にコピーして依存関係をインストール
COPY Gemfile Gemfile.lock $APP_ROOT/
# gem をコンテナの bundle-gems にインストール
RUN bundle config set path /usr/local/bundle && bundle install

# yarn install
COPY package.json yarn.lock $APP_ROOT/
RUN yarn install --check-files

# アプリ全体をコピー
COPY . $APP_ROOT

# Puma 用ポート
EXPOSE 80

# Pumaの起動コマンド
CMD ["bundle", "exec", "puma", "-C", "config/dev_puma-socket.rb", "-e", "development"]


