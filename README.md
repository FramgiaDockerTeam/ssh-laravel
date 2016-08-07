### SSH into remote server and deploy Laravel

The configuration file is located at `deploy.sh`

```shell
SERVER_NAME="localhost"
DIR_ROOT="/var/web/laravel"
REPOSITORY="git@github.com:FramgiaDockerTeam/laravel-ssh-source.git"
BRANCH="master"
ENV_FILE="./.env"
SHARE_ITEMS=( ".env" "storage" )
NGINX_CONF_NAME="application"
```

Environment configuration file

`.env`