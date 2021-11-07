#!/bin/bash

read -rd '' instance_fields_selection <<- 'FIELDS'
  id: InstanceId,
  name: Tags[?Key=='Name'] | [0].Value,
  state: State.Name,
  dns: PublicDnsName
FIELDS

function strip {
  cut -d'"' -f2
}

function terminate {
  #'describe-instance-status' gives only running instances
  #Assume there is only one running instance to terminate so take only the first item
  #shellcheck disable=2155
  local id="$(
    aws ec2 describe-instance-status --query 'InstanceStatuses[0].InstanceId' |
      strip
  )"
  if [[ "$id" = "null" ]]; then
    echo 'No running instance to terminate!' >&2
    return 1
  else
    aws ec2 terminate-instances --instance-ids "$id"
  fi
}

function launch {
  local name="${1:-Unnamed}"
  #Allow only one running instance
  if [[ ! "$(aws ec2 describe-instance-status \
    --query 'length(InstanceStatuses)')" = "0" ]]; then
    echo 'Instance already launched!' >&2
    return 1
  fi
  #shellcheck disable=2155
  local key_name="$(aws ec2 describe-key-pairs --query 'KeyPairs[0].KeyName' | strip)"
  #Use default security group and VPC id for launcching instance
  #t2.micro, ubuntu 20
  aws ec2 run-instances --instance-type t2.micro \
    --count 1 \
    --image-id ami-0f8b8babb98cc66d0 \
    --key-name "$key_name" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" \
    --query "Instances[0].{$instance_fields_selection}"
}

function list {
  aws ec2 describe-instances \
    --query "Reservations[*].Instances[].{$instance_fields_selection}[*].*" |
    jq -r '.[] | join("\t")'
}

cmd="${1:-list}"

case "$cmd" in
  launch)
    launch "$2"
    ;;
  terminate)
    terminate
    ;;
  list)
    list
    ;;
  *)
    echo "Invalild cmd: $cmd" >&2
    exit 1
    ;;
esac
