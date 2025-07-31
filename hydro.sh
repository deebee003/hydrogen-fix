#!/bin/bash
set -e

# Constants
readonly RED=$(tput setaf 1)
readonly GREEN=$(tput setaf 2)
readonly WHITE=$(tput setaf 7)
readonly RESET=$(tput sgr0)
readonly CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
readonly X_MARK="\033[0;31m\xE2\x9C\x98\033[0m"

# Status Codes
readonly EXIT_COMMAND_NOT_FOUND=127
readonly EXIT_VERSION_FETCH_FAILED=3

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

fetch_url() {
  local url=$1
  curl --silent --fail "$url"
}

download_file() {
  local url=$1
  local output_file=$2
  local pre_message=$3
  local success_message=$4
  local error_message=$5

  print_color "$WHITE" "$pre_message"
  curl --location "$url" --output "$output_file" >/dev/null 2>&1 &
  
  local curl_pid=$!

  while kill -0 $curl_pid >/dev/null 2>&1; do
    echo -n "."
    sleep 0.5
  done
  
  wait "$curl_pid"

  overwrite_color "$GREEN" "$CHECK_MARK $success_message\n"
}

unzip_file() {
  local zip_file=$1
  local destination_dir=$2
  local pre_message=$3
  local success_message=$4
  local error_message=$5

  if [ ! -f "$zip_file" ]; then
    print_color "$RED" "$X_MARK $error_message\n"
    exit 1
  fi

  mkdir -p "$destination_dir"

  print_color "$WHITE" "$pre_message"
  unzip -o -q "$zip_file" -d "$destination_dir"
  overwrite_color "$GREEN" "$CHECK_MARK $success_message\n"
}

cleanup() {
  rm -f "$HOME/hydrogen.zip"
  rm -rf "$HOME/hydrogen_unzip"
  rm -rf "$HOME/roblox_unzip"
  rm "$HOME/jq"
  [ -d "Hydrogen.app" ] && rm -rf "Hydrogen.app"
  [ -d "Roblox.app" ] && rm -rf "Roblox.app"
}

main() {
  trap cleanup EXIT

  if [ "$(id -u)" -eq 0 ]; then
    print_color "$RED" "$X_MARK Please do not run as root!\n" >&2
    exit 1
  fi

  mkdir -p "/tmp/hydro_exec/"

  ensure_command_exists "curl" "Curl could not be found! This should never happen. Open a ticket."
  ensure_command_exists "unzip" "Unzip could not be found! This should never happen. Open a ticket."

  pkill -9 Roblox || true
  pkill -9 Hydrogen || true

  # Adjust these paths to your actual user folder:
  local applications_dir="/Users/a/Applications"
  rm -rf "$applications_dir/Roblox.app"
  rm -rf "$applications_dir/Hydrogen.app"

  local jq_link="https://cdn.discordapp.com/attachments/1043972790266626179/1138954421204684990/jq"
  download_file "$jq_link" "$HOME/jq" "Downloading jq..." "jq has been downloaded!" "Failed to download the latest jq version. Please check your internet connection and try again."
  chmod +x "$HOME/jq"

  local latest_version_json=$(fetch_url "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer")
  local current_version=$(echo "$latest_version_json" | "$HOME/jq" ".clientVersionUpload" | tr -d '"')

  print_color "$GREEN" "$CHECK_MARK Got latest version of Roblox! $current_version\n"

  local download_url="http://setup.rbxcdn.com/mac/$current_version-RobloxPlayer.zip"
  local output_file="$HOME/$current_version-RobloxPlayer.zip"

  download_file "$download_url" "$output_file" "Downloading Roblox (this might take awhile)..." "Roblox has been downloaded!" "Failed to download the latest Roblox version. Please check your internet connection and try again."

  unzip_file "$output_file" "$HOME/roblox_unzip" "Unzipping Roblox..." "Unzipped Roblox!" "Failed to unzip Roblox."

  rm "$output_file"

  #############################################################################################################################
  local current_hydrogen_exec="https://cdn.discordapp.com/attachments/1043972790266626179/1169770258614210570/Hydrogen.app.zip"
  #############################################################################################################################

  download_file "$current_hydrogen_exec" "$HOME/hydrogen.zip" "Downloading Hydrogen..." "Hydrogen has been downloaded!" "Failed to download the latest Hydrogen version. Please check your internet connection and try again."

  unzip_file "$HOME/hydrogen.zip" "$HOME/hydrogen_unzip" "Unzipping Hydrogen..." "Unzipped Hydrogen!" "Failed to unzip Hydrogen."

  local hydrogen_app_path="$applications_dir/Hydrogen.app"
  local roblox_app_path="$applications_dir/Roblox.app"

  [ -d "$hydrogen_app_path" ] && rm -rf "$hydrogen_app_path"
  [ -d "$roblox_app_path" ] && rm -rf "$roblox_app_path"
  
  mv "$HOME/roblox_unzip/RobloxPlayer.app" "$roblox_app_path"

  local channel="live"
  local version_json=$(fetch_url "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer/channel/$channel")

  echo -e "$CHECK_MARK You are on the production channel: $version_json"

  local spoofed_version=$(echo "$version_json" | "$HOME/jq" ".version")
  local spoofed_bootstrap=$(echo "$version_json" | "$HOME/jq" ".bootstrapperVersion")

  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $spoofed_version" "$roblox_app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $spoofed_bootstrap" "$roblox_app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $spoofed_version" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $spoofed_bootstrap" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/Info.plist"

  echo -e "$CHECK_MARK Disabled remote channel updates"

  chmod -R 777 "$roblox_app_path"

  rm -rf "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/_CodeSignature"
  xattr -cr "$roblox_app_path/Contents/MacOS/Roblox.app"
  rm -f "$HOME/Library/Preferences/com.Roblox.Roblox.plist"
  rm -f "$HOME/Library/Preferences/com.roblox.RobloxPlayerChannel.plist"
  killall cfprefsd || true

  echo -e "$CHECK_MARK Installing Roblox..."

  cp "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/libHydrogenLoader.dylib" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/libHydrogenLoader.dylib"
  "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/insert_dylib" --strip-codesig --all-yes "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/libHydrogenLoader.dylib" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/Roblox" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/Roblox" >/dev/null 2>&1

  rm -rf "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/_CodeSignature"
  xattr -cr "$roblox_app_path/Contents/MacOS/Roblox.app"
  rm -rf "$roblox_app_path/Contents/_CodeSignature"
  xattr -cr "$roblox_app_path"

  rm -f "$HOME/Library/Preferences/com.Roblox.Roblox.plist"
  rm -f "$HOME/Library/Preferences/com.roblox.RobloxPlayerChannel.plist"
  killall cfprefsd || true

  cp "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/libHydrogen.dylib" "$roblox_app_path/Contents/MacOS/libHydrogen.dylib"
  cp "$roblox_app_path/Contents/MacOS/RobloxPlayer" "$roblox_app_path/Contents/MacOS/.RobloxPlayer"

  "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/insert_dylib" --strip-codesig --all-yes "$roblox_app_path/Contents/MacOS/libHydrogen.dylib" "$roblox_app_path/Contents/MacOS/.RobloxPlayer" "$roblox_app_path/Contents/MacOS/RobloxPlayer" >/dev/null 2>&1
  
  cp "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/libHydrogenLoader.dylib" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/libHydrogenLoader.dylib"
  "$HOME/hydrogen_unzip/Hydrogen.app/Contents/Resources/insert_dylib" --strip-codesig --all-yes "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/libHydrogenLoader.dylib" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/Roblox" "$roblox_app_path/Contents/MacOS/Roblox.app/Contents/MacOS/Roblox" >/dev/null 2>&1

  mv "$HOME/hydrogen_unzip/Hydrogen.app" "$hydrogen_app_path"
  chmod -R 777 "$hydrogen_app_path"

  mkdir -p "$HOME/Hydrogen/autoexec" "$HOME/Hydrogen/workspace" "$HOME/Hydrogen/ui/themes"
  chmod -R 777 "$HOME/Hydrogen"

  print_color "$GREEN" "Hydrogen has been installed! Enjoy!\n"
}

main "$@"
