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
