_ec2_scripts_root="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$_ec2_scripts_root/lib/config.bash"
_ec2_user='ubuntu'

_ec2_raw_dns_cache="$_ec2_scripts_root/.ec2-raw-dns.cache.txt"

function __ec2_read_dns_from_cache {
  #shellcheck disable=2155
  local dns=
  [[ -r "$_ec2_raw_dns_cache" ]] && read -r dns < "$_ec2_raw_dns_cache"

  if [[ "$dns" ]]; then
    echo "$dns"
  else
    return 1
  fi
}

function __ec2_query_dns {
  local dns=
  dns="$(aws ec2 describe-instances \
    --query "Reservations[*].Instances[] | [?State.Name == 'running'] | [0].PublicDnsName" |
    cut -d'"' -f2)"

  if [[ "$dns" ]] && [[ "$dns" != "null" ]]; then
    tee "$_ec2_raw_dns_cache" <<< "$dns"
  else
    echo "No running instance to log in!" >&2
    rm -f "$_ec2_raw_dns_cache"
    return 1
  fi
}

function ec2ssh {
  local ssh_cmd=('ssh' '-o' 'ConnectTimeout=3' '-o' 'ConnectionAttempts=1' '-X')
  local dns=

  { dns="$(__ec2_read_dns_from_cache)" && "${ssh_cmd[@]}" "$_ec2_user@$dns"; } ||
    { dns="$(__ec2_query_dns)" && "${ssh_cmd[@]}" "$_ec2_user@$dns"; }
}

function ec2cp {
  local scp_cmd=('scp' '-o' 'ConnectTimeout=3' '-o' 'ConnectionAttempts=1')
  local stuff="$1"

  if [[ ! -r "$stuff" ]]; then
    echo 'Argument - readable file or dir is required' >&2
    return 1
  fi

  if [[ -d "$stuff" ]]; then
    scp_cmd+=('-r' "$stuff")
  else
    scp_cmd+=("$stuff")
  fi

  local dns=
  { dns="$(__ec2_read_dns_from_cache)" &&
    "${scp_cmd[@]}" "$_ec2_user@$dns:/home/$_ec2_user/scp_inbox/$(basename "$stuff")"; } ||
    { dns="$(__ec2_query_dns)" &&
      "${scp_cmd[@]}" "$_ec2_user@$dns:/home/$_ec2_user/scp_inbox/$(basename "$stuff")"; }
}

function ec2_domain_update {
  local raw_dns=
  if raw_dns="$(__ec2_query_dns)"; then
    #form conf file get them
    local domain_name=
    local hosted_zone=
    __ec2_config_read domain_name hosted_zone

    local change_batch=
    read -rd '' change_batch <<- BATCH
  Changes=[{
    Action=UPSERT,
    ResourceRecordSet={
      Name=$domain_name,
      Type=A,
      ResourceRecords=[{
        Value='$(sed -E \
      's/ec2-([[:digit:]]{1,3})-([[:digit:]]{1,3})-([[:digit:]]{1,3})-([[:digit:]]{1,3})\..*/\1.\2.\3.\4/' \
      <<< "$raw_dns")'}],TTL=300}}]
BATCH
    aws route53 change-resource-record-sets \
      --hosted-zone-id "$hosted_zone" \
      --change-batch "$change_batch"
  else
    echo 'quer_dns failed' >&2
    return 1
  fi
}

complete -fd ec2cp
