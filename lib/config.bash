_ec2_config_file_basename="config.conf"
#scripts_dir supposed to be set externally
#shellcheck disable=2154
_ec2_config_file="$_ec2_scripts_root/$_ec2_config_file_basename"

#stdin input expected
function __ec2_config_pick {
  if [[ ! -r "$_ec2_config_file" ]]; then
    echo "ec2 $_ec2_config_file_basename file is missing or unreadable" >&2
    return 1
  fi

  if [[ ! "${1-}" =~ [[:alnum:]_-] ]]; then
    echo "At least one string key expected" >&2
    return 1
  fi

  awk 'BEGIN {
    for (i=1; i<ARGC; i++) {
      key=ARGV[i];
      key_order[i-1] = key
      map[key] = "";
    }
    ARGC=1;
  }
  #Not a comment
  !/^#/ {
    key = $1;
    if(key in map) {
      map[key] = $2;
    }
  }
  END {
    for(i in key_order) {
      print map[key_order[i]];
    }
  }' "$@" < "$_ec2_config_file"
}

function __ec2_config_read {
  read -r -d '' "$@" < <(echo -ne "$(__ec2_config_pick "$@")"'\0')
}
