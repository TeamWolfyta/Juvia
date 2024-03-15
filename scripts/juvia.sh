#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Ensure the script exits if any command in a pipeline fails.
set -o pipefail

pwd=$(pwd)

# Function to transform a single input into a docker-compose file option.
transform_to_docker_option() {
  # Constructs a docker-compose file path with the provided argument.
  echo "-f $pwd/compose/${1}/docker-compose.yaml"
}

# Function to transform all input arguments into docker-compose file options.
transform_to_docker_options() {
  local output=() # Initialize an empty array for the docker options.
  for input in "$@"; do
    # Transform each input argument and add it to the output array.
    output+=("$(transform_to_docker_option "$input")")
  done
  echo "${output[@]}" # Output the array elements as a single string.
}

# Check if any arguments were provided.
if [ $# -eq 0 ]; then
  echo "No arguments provided. Exiting..."
  echo "Usage: $0 <service_name>..."
  exit 1
fi

command="$1"
shift # Shift arguments to process additional options or services.

docker_services=()           # Initialize an empty array to hold docker service names.
docker_additional_options=() # Initialize an empty array for additional docker command options.

# Parse command line arguments for services and additional docker options.
while [[ $# -gt 0 ]]; do
  case "$1" in
  -*)
    docker_additional_options+=("$1") # Add option to additional options array.
    shift
    ;;
  *)
    docker_services+=("$1") # Add service to services array.
    shift
    ;;
  esac
done

# Generate docker options from the services array and define the environment file option for docker commands.
docker_generated_options=""--env-file $pwd/.env" $(transform_to_docker_options "${docker_services[@]}")"

# Deploy command logic.
if [[ $command == "deploy" ]]; then
  # Stop and remove containers, networks, volumes, and images created by `up`.
  docker compose $docker_generated_options down

  # Fetch the newest version of the code from the repository.
  git pull

  # Build, (re)create, start, and attach to containers for a service in detached mode.
  docker compose $docker_generated_options up -d
else
  # Execute docker compose with generated options and the specified command.
  docker compose $docker_generated_options $command ${docker_additional_options[@]}
fi
