#!/bin/bash

# shellcheck disable=SC2153
verbose=$VERBOSE
error() { printf "%b\n" "$*" >&2; }

while getopts "v" OPTION
do
  case $OPTION in
    v) verbose=true ;;
    *) error "usage: $0 [-v]"
       exit 1 ;;
  esac
done

if [ "$verbose" ]; then
  log() { printf "%b\n" "$*"; }
else
  log() { :; }
fi

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[93m"
MAGENTA="\e[95m"
ENDCOLOR="\e[0m"

hide_output() {
  local error_output
  error_output=$("$@" 2>&1 > /dev/null)
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    error "${RED}Error occurred while running:${ENDCOLOR} $*"
    error "$error_output"
    return $exit_code
  fi

  return 0  # Return zero exit code to indicate success
}

already_installed() { log "${MAGENTA}Already installed:${ENDCOLOR} $TARGET"; }
installing() { log "${YELLOW}Installing:${ENDCOLOR} $TARGET"; }
install_status() {
  if [[ $? == 0 ]]; then
    log "${GREEN}Installed:${ENDCOLOR} $TARGET"
  else
    error "${RED}Failed to install:${ENDCOLOR} $TARGET"
  fi;
  }

already_configured() { log "${MAGENTA}Already configured:${ENDCOLOR} $TARGET"; }
configuring() { log "${YELLOW}Configuring:${ENDCOLOR} $TARGET"; }
config_status() {
  if [[ $? == 0 ]]; then
    log "${GREEN}Configured:${ENDCOLOR} $TARGET"
  else
    error "${RED}Failed to configure:${ENDCOLOR} $TARGET"
  fi;
  }
updating() { log "${YELLOW}Updating:${ENDCOLOR} $1 -> $2"; }

TARGET="sudo access with Touch ID"
sudo_file="/etc/pam.d/sudo"
touch_id_auth_option="auth       sufficient     pam_tid.so"
awk_command=$"NR==2{print \"$touch_id_auth_option\"}1"
sudo_template_file="/etc/pam.d/sudo_local.template"
sudo_local_file="/etc/pam.d/sudo_local"

if [ ! -f "$sudo_template_file" ]; then
  # before macOS Sonoma
  if ! grep "$touch_id_auth_option" $sudo_file > /dev/null; then
    configuring
    new_sudo_file_content=$(awk "$awk_command" $sudo_file)
    if echo "$new_sudo_file_content" | grep "$touch_id_auth_option" > /dev/null; then
      sudo bash -c $"printf \"%s\" \"$new_sudo_file_content\" > $sudo_file"
    else
      false
    fi
    config_status

  else
    already_configured
  fi
else
  # macOS Sonoma or later
  if [ ! -f "$sudo_local_file" ]; then
    sudo cp "$sudo_template_file" "$sudo_local_file"
  fi
  if grep -q "^#${touch_id_auth_option}" "$sudo_local_file"; then
    configuring
    sudo sed -i '' "s/^#${touch_id_auth_option}/${touch_id_auth_option}/" "$sudo_local_file"
    config_status
  else
    already_configured
  fi
fi


TARGET="Command Line Tools for Xcode"
if xcode-select -p > /dev/null 2>&1; then
  already_installed
else
  installing
  # Basically it does the same as `xcode-select --install`, but without prompt
  # https://github.com/timsutton/osx-vm-templates/blob/master/scripts/xcode-cli-tools.sh
  # https://github.com/timsutton/osx-vm-templates/pull/101/files
  # Create the placeholder file that's checked by CLI updates' .dist code in Apple's SUS catalog
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  # find the CLI Tools update
  cmd_line_tools=$(
    softwareupdate -l |
      grep "\*.*Command Line" |
        head -n 1 |
          awk -F"*" '{print $2}' |
            sed -e 's/^ *//' |
              sed 's/Label: //g' |
                tr -d '\n'
  )
  # install it
  softwareupdate -i "$cmd_line_tools"
  install_status
  rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi

TARGET="Oh My ZSH"
if test -d "$HOME/.oh-my-zsh"; then
  already_installed
else
  installing
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
  install_status
fi

TARGET="Homebrew"
if brew --version > /dev/null 2>&1; then
  already_installed
else
  installing
  sudo true  # get sudo access, as the brew installation script won't request it in NONINTERACTIVE mode
  NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_ENVIRONMENT_VARIABLES=$(/opt/homebrew/bin/brew shellenv)
  printf "\n%s\n" "$BREW_ENVIRONMENT_VARIABLES" >> ~/.zprofile
  bash -c "$BREW_ENVIRONMENT_VARIABLES"
install_status
fi


TARGET="uv"
if uv --version > /dev/null 2>&1; then
  already_installed
else
  installing
  curl -LsSf https://astral.sh/uv/install.sh | sh
  source "$HOME/.cargo/env"
install_status
fi



TARGET="npm"
if npm --version > /dev/null 2>&1; then
  already_installed
else
  installing
  hide_output brew install npm
install_status
fi


python_list_output=$(uv python list)
uv_installed_versions=$(echo "$python_list_output" | grep -E '\.local/share/uv/' | awk '{print $1}' | sed 's/^cpython-//' | cut -d'-' -f1 | cut -d'.' -f1,2 | sort -V | uniq)
uv_installed_full_versions=$(echo "$python_list_output" | grep -E '\.local/share/uv/' | awk '{print $1}' | sed 's/^cpython-//' | cut -d'-' -f1)


make_python_symlinks() {
  if [[ ! -d ~/.local/share/uv/bin ]]; then
    mkdir ~/.local/share/uv/bin
  fi
  ln -sf "$(uv python dir)/$version_info/bin/python" "$HOME/.local/share/uv/bin/python"
  ln -sf "$(uv python dir)/$version_info/bin/python" "$HOME/.local/share/uv/bin/python3"
  ln -sf "$(uv python dir)/$version_info/bin/python" "$HOME/.local/share/uv/bin/python$short_version"
  if ! grep -q ~/.local/share/uv/bin ~/.zprofile; then
    echo "export PATH=\"$HOME/.local/share/uv/bin/:$PATH\"" >> ~/.zprofile
  fi
}

install_or_update_python_versions() {
  # Extract all versions (not just those with <download available>)
  all_versions=$(echo "$python_list_output" | awk '{print $1}' | sort -rV)
  selected_versions=()
  seen_versions=()

  for full_version in $all_versions; do
    short_version=$(echo "$full_version" | cut -d'.' -f1,2)
    for processed_version in "${seen_versions[@]}"; do
      if [[ "$processed_version" == "$short_version" ]]; then
        already_processed=true
        break
      fi
    done
    seen_versions+=("$short_version")
    if [[ $already_processed ]]; then
      unset already_processed
      continue
    fi
    selected_versions+=("$full_version")

  done

  sorted_versions=$(printf "%s\n" "${selected_versions[@]}" | sort -V)
  for version_info in $sorted_versions; do
    # Extract the Python major.minor version
    full_version=$(echo "$version_info" | sed 's/^cpython-//' | cut -d'-' -f1)
    short_version=$(echo "$full_version" | cut -d'.' -f1,2)
    TARGET="Python $short_version"

    if echo "$python_list_output" | grep -q "$version_info.*<download available>"; then
      # short version is already installed, but a newer version is available
      if echo "$uv_installed_versions" | grep -q "^$short_version$"; then
        current_installed=$(echo "$uv_installed_full_versions" | grep "^$short_version" | sort -V | tail -n 1)
        if [ "$current_installed" != "$full_version" ]; then
          updating "$current_installed" "$full_version"
          hide_output uv python install "$full_version"
          make_python_symlinks
          install_status
        else
          already_installed
        fi
      else
        installing
        hide_output uv python install "$version_info"
        make_python_symlinks
        install_status
      fi
    else
      already_installed
    fi
  done
}

install_or_update_python_versions


echo "All done! ✨ 🍰 ✨"

