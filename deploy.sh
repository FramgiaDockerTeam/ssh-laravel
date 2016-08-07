#!/bin/bash

set -e

SERVER_NAME="localhost"
DIR_ROOT="/var/web/laravel"
REPOSITORY="git@github.com:FramgiaDockerTeam/laravel-ssh-source.git"
ENV_FILE="./.env"
SHARE_ITEMS=( ".env" "storage" )
NGINX_CONF_NAME="application"

NOW=$(date +"%Y%m%d%H%M%S")
DIR_CURRENT="$DIR_ROOT/current"
DIR_SHARED="$DIR_ROOT/shared"
DIR_RELEASES="$DIR_ROOT/releases"
DIR_TAG="$DIR_RELEASES/$NOW"
DIR_EXEC="$PWD"

start_service()
{
    handlers "mysql" "start"
    handlers "php5.6-fpm" "start"
    handlers "nginx" "start"
}

make_dir()
{
    mkdir -pv $DIR_ROOT
    mkdir -pv $DIR_SHARED
    mkdir -pv $DIR_RELEASES
}

generate_public_key()
{
    if [ -f ~/.ssh/id_rsa ]; then
        chmod 0600 ~/.ssh/id_rsa
        ssh-keygen -f ~/.ssh/id_rsa -y > ~/.ssh/id_rsa.pub
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_rsa
    fi
}

clone_source()
{
    echo $DIR_TAG
    mkdir $DIR_TAG
    git clone $REPOSITORY $DIR_TAG
}

common_tasks()
{
    # Composer install
    cd $DIR_TAG && composer install
    # NPM install
    cd $DIR_TAG && npm install
    # Compile assets
    cd $DIR_TAG && export DISABLE_NOTIFIER=true && gulp
    # Back to deploy.sh exec directory
    cd $DIR_EXEC
    # Generate env file if it does not exist
    if [ ! -f "$DIR_SHARED/.env" ]; then
        cp $ENV_FILE "$DIR_TAG/.env"
        # Generate artisan key
        cd $DIR_TAG && php artisan key:generate
    fi
}

share_items()
{
    for i in "${SHARE_ITEMS[@]}"
    do
        if [ ! -f "$DIR_SHARED/$i" ]; then
            if [ -f "$DIR_TAG/$i" ]; then
                cp "$DIR_TAG/$i" "$DIR_SHARED/"
            fi
        fi
        if [ ! -d "$DIR_SHARED/$i" ]; then
            if [ -d "$DIR_TAG/$i" ]; then
                cp -r "$DIR_TAG/$i" "$DIR_SHARED/"
            fi
        fi
        rm -rf "$DIR_TAG/$i"
        ln -s "$DIR_SHARED/$i" "$DIR_TAG/$i"
    done
    ln -snf "$DIR_TAG" "$DIR_CURRENT"
}

chmod_dir()
{
    # Change mode bootstrap and storage directory
    if [ -d "$DIR_TAG/storage/" ]; then
        cd $DIR_TAG && chmod -R 777 storage/
    fi
    if [ -d "$DIR_TAG/bootstrap/cache/" ]; then
        cd $DIR_TAG && chmod -R 777 bootstrap/cache/
    fi
}

db_migration()
{
    # DB migration
    cd $DIR_TAG && php artisan migrate --force
}

handlers()
{
    # Service start/stop/restart/reload
    service $1 $2
}

create_config()
{
    cd $DIR_EXEC
    site_available="/etc/nginx/sites-available/${NGINX_CONF_NAME}.conf"
    sites_enabled="/etc/nginx/sites-enabled/${NGINX_CONF_NAME}.conf"
    if [ ! -f $sites_enabled ] ; then
        sed -E -e "s@%server_name%@$SERVER_NAME@g" -e "s@%directory_current%@$DIR_CURRENT@g" < nginx.conf > ${site_available}
        ln -snf $site_available $sites_enabled
        handlers "nginx" "reload"
    fi
}

start_service
make_dir
generate_public_key
clone_source
common_tasks
share_items
db_migration
chmod_dir
create_config