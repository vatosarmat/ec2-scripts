#shellcheck disable=2154
#lib/config sourced
#.staging/data was just created and we are in scripts root

__ec2_config_read domain_name bucket_name \
  app_name app_port app_docker_image app_docker_run_env

_image_config_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

#Copy nginx config. Remove comments, substitute parameters
cp -r "$_image_config_dir/nginx" '.staging/data/nginx'
sed -i "\
/^#/d;\
s/__DOMAIN__/${domain_name}/g;\
s/__APP_NAME__/${app_name}/g;\
s/__APP_PORT__/${app_port}/g;" \
  '.staging/data/nginx/conf.d/default.conf'

#Copy systemd unit, substitute parameters
cp "$_image_config_dir/docker.app.service" ".staging/data/docker.$app_name.service"
sed -i "\
/^#/d;\
s/__DOMAIN__/${domain_name}/g;\
s/__APP_NAME__/${app_name}/g;\
s/__APP_DOCKER_IMAGE__/${app_docker_image//\//\\/}/g;\
s/__APP_DOCKER_RUN_ENV__/${app_docker_run_env//\//\\/}/g;\
s/__APP_PORT__/${app_port}/g;" \
  ".staging/data/docker.$app_name.service"

#Copy setup script. Add variable assignment right after shebang
cp "$_image_config_dir/setup" '.staging/setup'
sed -i "1a\\
bucket_name=\'${bucket_name}\'\n\
app_name=\'${app_name}\'\n\
" '.staging/setup'
