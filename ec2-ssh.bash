_ec2_user='ubuntu'
_ec2_dns_file="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.ec2-dns.txt"

function __ec2_read_dns_from_file {
  #shellcheck disable=2155
  local dns=
  [[ -r "$_ec2_dns_file" ]] && read -r dns < "$_ec2_dns_file"

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
    tee "$_ec2_dns_file" <<< "$dns"
  else
    echo "No running instance to log in!" >&2
    rm -f "$_ec2_dns_file"
    return 1
  fi
}

function ec2ssh {
  local ssh_cmd=('ssh' '-o' 'ConnectTimeout=3' '-o' 'ConnectionAttempts=1' '-X')
  local dns=

  # If valid dns has been read from the file, return
  { dns="$(__ec2_read_dns_from_file)" && "${ssh_cmd[@]}" "$_ec2_user@$dns"; } ||
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
  { dns="$(__ec2_read_dns_from_file)" &&
    "${scp_cmd[@]}" "$_ec2_user@$dns:/home/$_ec2_user/scp_inbox/$(basename "$stuff")"; } ||
    { dns="$(__ec2_query_dns)" &&
      "${scp_cmd[@]}" "$_ec2_user@$dns:/home/$_ec2_user/scp_inbox/$(basename "$stuff")"; }
}
complete -fd ec2cp
