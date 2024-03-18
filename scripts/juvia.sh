#!/bin/bash

set -eo pipefail

# Define colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# ASCII art
cat <<"EOF"
    /$$$$$                      /$$
   |__  $$                     |__/
      | $$ /$$   /$$ /$$    /$$ /$$  /$$$$$$
      | $$| $$  | $$|  $$  /$$/| $$ |____  $$
 /$$  | $$| $$  | $$ \  $$/$$/ | $$  /$$$$$$$
| $$  | $$| $$  | $$  \  $$$/  | $$ /$$__  $$
|  $$$$$$/|  $$$$$$/   \  $/   | $$|  $$$$$$$
 \______/  \______/     \_/    |__/ \_______/

EOF

# Get current working directory
working_directory="$(pwd)"
compose_directory="$working_directory/compose"

environment_file_path="$working_directory/.env"
relative_environment_file_path="${environment_file_path#$working_directory/}" # Calculate relative path

# Array to store services with missing docker-compose.yaml files or non-existing services
invalid_services=()

# Function to check if a directory exists and contains files
check_directory() {
  local directory="$1"
  [[ -e "$directory" && -d "$directory" && "$(find "$directory" -maxdepth 2 -type f -name "docker-compose.yaml")" ]]
}

# Function to execute a Docker command for a specific service
execute_docker_command() {
  local command="$1"
  local service="$2"
  local flags=("${@:3}")

  compose_file_path="$compose_directory/$service/docker-compose.yaml"
  relative_compose_file_path="${compose_file_path#$working_directory/}" # Calculate relative path

  if [[ -f "$compose_file_path" ]]; then
    echo -e "${GREEN}Executing:${NC} docker compose --env-file \"${YELLOW}$relative_environment_file_path${NC}\" -f \"${YELLOW}$relative_compose_file_path${NC}\" ${PURPLE}$command${NC} ${flags[@]}"
    docker compose --env-file $environment_file_path -f $compose_file_path $command ${flags[@]}
    echo -e "${GREEN}Completed:${NC} ${PURPLE}$command${NC} for service '${BLUE}$service${NC}'"
  else
    echo -e "${RED}Error:${NC} Service '${BLUE}$service${NC}' does not exist or is missing docker-compose.yaml!" >&2
    invalid_services+=("$service")
  fi
}

# Function to execute Docker commands for specific services
execute_docker_commands() {
  local command="$1"
  local services=()
  local flags=()

  for arg in "${@:2}"; do
    if [[ "$arg" == -* ]]; then
      flags+=("$arg")
    else
      services+=("$arg")
    fi
  done

  for service in "${services[@]}"; do
    # Skip services that are known to be invalid
    if grep -wFq "$service" <<<"${invalid_services[*]}"; then
      continue
    fi

    execute_docker_command "$command" "$service" "${flags[@]}"
  done
}

# Help function
help() {
  echo -e "
${YELLOW}Usage:${NC}
   $0 [COMMAND] [SERVICES] [FLAGS]

${YELLOW}Commands:${NC}
  ${GREEN}deploy${NC}    - Yes. - Link
  ${GREEN}*${NC}         - Catch all that is passed directly to 'docker compose'.

${YELLOW}Services:${NC}
  Specify one or more service names defined in the compose directory.

${YELLOW}Flags:${NC}
  Any flags supported by the 'docker compose' command can be passed.
"
}

# Main execution starts here

# Check if compose directory exists and contains files
check_directory "$compose_directory" || {
  echo -e "${RED}Error:${NC} Compose folder '${YELLOW}$compose_directory${NC}' does not exist or does not contain any docker-compose.yaml files!" >&2
  exit 1
}

# Check if environment file exists
[[ -f "$environment_file_path" ]] || {
  echo -e "${RED}Error:${NC} Environment file '${YELLOW}$environment_file_path${NC}' does not exist!" >&2
  exit 1
}

# Check if arguments are provided
if [ $# -eq 0 ]; then
  echo -e "${RED}Error:${NC} No arguments provided. Please provide a command and service(s)." >&2
  exit 1
fi

# Extract command
command="$1"
shift

# Execute Docker commands based on the provided command
case "$command" in
help)
  help
  exit 0
  ;;
deploy)
  execute_docker_commands down "$@" &&
    git pull &&
    execute_docker_commands up -d "$@"
  exit 0
  ;;
*)
  execute_docker_commands "$command" "$@"
  exit 0
  ;;
esac
