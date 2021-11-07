function ec2ssh {
  local -r user='ubuntu'
  local ssh_cmd=('ssh' '-o' 'ConnectTimeout=3' '-o' 'ConnectionAttempts=1' '-X')
  #shellcheck disable=2155
  local dns_file="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.ec2-dns"
  local dns
  if [[ -r "$dns_file" ]]; then
    read -r dns < "$dns_file"
  fi

  if [[ "$dns" ]] && "${ssh_cmd[@]}" "$user@$dns"; then
    # Valid dns read from file
    return
  fi

  #no file, nd dns in it, or dns is bad
  dns="$(aws ec2 describe-instances \
    --query "Reservations[*].Instances[] | [?State.Name == 'running'] | [0].PublicDnsName" |
    cut -d'"' -f2)"

  if [[ ! "$dns" ]] || [[ "$dns" = "null" ]]; then
    echo "No running instance to log in!" >&2
    rm -f "$dns_file"
    return 1
  fi

  echo "$dns" > "$dns_file"
  "${ssh_cmd[@]}" "$user@$dns"
}
