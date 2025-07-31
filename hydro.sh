#!/bin/bash
set -e

# Colors and symbols
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
X_MARK="\033[0;31m\xE2\x9C\x98\033[0m"

# Exit codes
EXIT_COMMAND_NOT_FOUND=127

print_color() {
  local color=$1
  local message=$2
  echo -ne "${color}${message}${RESET}"
}

overwrite_color() {
  local color=$1
  local message=$2
  tput cr
  tput el
  echo -e "${color}${message}${RESET}"
}

ensure_command_exists() {
  local command=$1
  local error_message=$2

  if ! command -v "$command" &>/dev/null; then
    print_color "$RED" "$X_MARK $error_message\n"
    exit $EXIT_COMMAND_NOT_FOUND
  fi
}

download_file() {
  local url=$1
  local output_file=$2
  local pre_message=$3
  local success_message=$4

  print_color "$WHITE" "$pre_message"
  curl --location --progress-bar "$url" --output "$output_file"
  overwrite_color "$GREEN" "$CHECK_MARK $success_message"
}

unzip_file() {
  local zip_file=$1
  local destination_dir=$2
  local pre_message=$3
  local success_message=$4

  print_color "$WHITE" "$pre_message"
  unzip -o -q "$zip_file" -d "$destination_dir"
  overwrite_color "$GREEN" "$CHECK_MARK $success_message"
}

cleanup() {
  rm -f "$HOME/hydrogen.zip"
  rm -rf "$HOME/hydrogen_unzip"
  rm -rf "$HOME/roblox_unzip"
  [ -d "Hydrogen.app" ] && rm -rf "Hydrogen.app"
  [ -d "Roblox.app" ] && rm -rf "Roblox.app"
}

main() {
  trap cleanup EXIT

  if [ "$(id -u)" -eq 0 ]; then
    print_color "$RED" "$X_MARK Please do not run as root!\n"
    exit 1
  fi

  mkdir -p "/tmp/hydro_exec/"

  # Use system jq only
  ensure_command_exists "jq" "jq could not be found! Please install jq."

  ensure_command_exists "curl" "Curl could not be found! This should never happen."
  ensure_command_exists "unzip" "Unzip could not be found! This should never happen."

  pkill -9 Roblox || true
  pkill -9 Hydrogen || true

  rm -rf "/Users/a/Applications/Roblox.app"
  rm -rf "/Users/a/Applications/Hydrogen.app"

  local latest_version_json
  latest_version_json=$(curl --silent --fail "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer")

  if [ -z "$latest_version_json" ]; then
    print_color "$RED" "$X_MARK Failed to fetch Roblox version info\n"
    exit 3
  fi

  local current_version
  current_version=$(jq -r ".clientVersionUpload" <<< "$latest_version_json")

  if [ -z "$current_version" ] || [ "$current_version" = "null" ]; then
    print_color "$RED" "$X_MARK Could not parse Roblox version\n"
    exit 3
  fi

  print_color "$GREEN" "$CHECK_MARK Got latest version of Roblox! $current_version\n"

  local download_url="http://setup.rbxcdn.com/mac/${current_version}-RobloxPlayer.zip"
  local output_file="$HOME/${current_version}-RobloxPlayer.zip"

  download_file "$download_url" "$output_file" "Downloading Roblox (this might take awhile)... " "Roblox has been downloaded!"

  mkdir -p "$HOME/roblox_unzip"
  unzip_file "$output_file" "$HOME/roblox_unzip" "Unzipping Roblox... " "Unzipped Roblox!"

  rm -f "$output_file"

  # --- Hydrogen download ---

  local current_hydrogen_exec="https://cdn.discordapp.com/attachments/1043972790266626179/1169770258614210570/Hydrogen.app.zip"
  download_file "$current_hydrogen_exec" "$HOME/hydrogen.zip" "Downloading Hydrogen... " "Hydrogen has been downloaded!"

  mkdir -p "$HOME/hydrogen_unzip"
  unzip_file "$HOME/hydrogen.zip" "$HOME/hydrogen_unzip" "Unzipping Hydrogen... " "Unzipped Hydrogen!"

  # Add your post-download install steps here (moving files, patching, permissions, etc.)

  print_color "$GREEN" "Hydrogen and Roblox setup steps completed!\n"
}

main "$@"
