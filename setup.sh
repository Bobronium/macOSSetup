#!/bin/bash

# Enable error handling
set -euo pipefail

# Global variables
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[93m"
MAGENTA="\e[95m"
ENDCOLOR="\e[0m"

# Functions

log() {
  # Conditionally logs messages if verbose mode is enabled
  if [ "${verbose:-false}" = true ]; then
    printf "%b\n" "$*"
  fi
}

error() {
  # Prints error messages to stderr
  printf "%b\n" "${RED}Error:${ENDCOLOR} $*" >&2
}

usage() {
  # Prints usage information
  echo "Usage: $0 [-v]"
  exit 1
}

hide_output() {
  # Hides output of the command unless there is an error
  local output
  output=$("$@" 2>&1 >/dev/null)
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    error "Error occurred while running: $*"
    error "$output"
    return $exit_code
  fi
}

print_status() {
  local status="$1"
  local message="$2"
  case $status in
  already_installed) log "${MAGENTA}Already installed:${ENDCOLOR} $message" ;;
  installing) log "${YELLOW}Installing:${ENDCOLOR} $message" ;;
  installed) log "${GREEN}Installed:${ENDCOLOR} $message" ;;
  failed) error "${RED}Failed to install:${ENDCOLOR} $message" ;;
  configuring) log "${YELLOW}Configuring:${ENDCOLOR} $message" ;;
  configured) log "${GREEN}Configured:${ENDCOLOR} $message" ;;
  *) error "Unknown status: $status" ;;
  esac
}

process_options() {
  # Parses command-line options
  while getopts ":v" option; do
    case "${option}" in
    v) verbose=true ;;
    *) usage ;;
    esac
  done
}

configure_touch_id_for_sudo() {
  # Configures sudo to use Touch ID
  local sudo_file="/etc/pam.d/sudo"
  local touch_id_auth_option="auth       sufficient     pam_tid.so"
  local sudo_local_file="/etc/pam.d/sudo_local"
  local sudo_template_file="/etc/pam.d/sudo_local.template"

  if [ ! -f "$sudo_template_file" ]; then
    if ! grep -q "$touch_id_auth_option" "$sudo_file"; then
      print_status configuring "sudo with Touch ID"
      new_sudo_file_content=$(awk "NR==2{print \"$touch_id_auth_option\"}1" "$sudo_file")
      if echo "$new_sudo_file_content" | grep -q "$touch_id_auth_option"; then
        sudo bash -c "printf \"%s\" \"$new_sudo_file_content\" > $sudo_file"
        print_status configured "sudo with Touch ID"
      else
        print_status failed "sudo with Touch ID"
      fi
    else
      print_status already_installed "sudo with Touch ID"
    fi
  else
    if [ ! -f "$sudo_local_file" ]; then
      sudo cp "$sudo_template_file" "$sudo_local_file"
    fi
    if grep -q "^#${touch_id_auth_option}" "$sudo_local_file"; then
      print_status configuring "sudo with Touch ID"
      sudo sed -i '' "s/^#${touch_id_auth_option}/${touch_id_auth_option}/" "$sudo_local_file"
      print_status configured "sudo with Touch ID"
    else
      print_status already_installed "sudo with Touch ID"
    fi
  fi
}

install_or_update_command_line_tools() {
  # Installs or updates Command Line Tools for Xcode
  if xcode-select -p >/dev/null 2>&1; then
    print_status already_installed "Command Line Tools for Xcode"
  else
    print_status installing "Command Line Tools for Xcode"
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    cmd_line_tools=$(softwareupdate -l | grep "\*.*Command Line" | awk -F"*" '{print $2}' | sed -e 's/^ *//' | sed 's/Label: //g' | tr -d '\n')
    softwareupdate -i "$cmd_line_tools"
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    print_status installed "Command Line Tools for Xcode"
  fi
}

install_oh_my_zsh() {
  # Installs Oh My Zsh
  if [ -d "$HOME/.oh-my-zsh" ]; then
    print_status already_installed "Oh My ZSH"
  else
    print_status installing "Oh My ZSH"
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
    print_status installed "Oh My ZSH"
  fi
}

install_homebrew() {
  # Installs Homebrew
  if command -v brew >/dev/null 2>&1; then
    print_status already_installed "Homebrew"
  else
    print_status installing "Homebrew"
    sudo true
    NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    printf "\n%s\n" "$(/opt/homebrew/bin/brew shellenv)" >>~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    print_status installed "Homebrew"
  fi
}

install_or_update_uv() {
  # Installs or updates uv
  if command -v uv >/dev/null 2>&1; then
    print_status already_installed "uv"
  else
    print_status installing "uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source "$HOME/.cargo/env"
    print_status installed "uv"
  fi
}

install_npm() {
  # Installs npm
  if command -v npm >/dev/null 2>&1; then
    print_status already_installed "npm"
  else
    print_status installing "npm"
    hide_output brew install npm
    print_status installed "npm"
  fi
}

make_python_symlinks() {
  # Create symlinks for Python binaries installed by `uv`
  local version_info="$1"
  local short_version="$2"

  mkdir -p ~/.local/share/uv/bin
  for bin in "$(uv python dir)/$version_info/bin/"*; do
    ln -sf "$bin" "$HOME/.local/share/uv/bin/$(basename "$bin")"
  done

  local new_path
  # shellcheck disable=SC2016
  new_path='"$HOME/.local/share/uv/bin:$PATH"'
  # shellcheck disable=SC2016
  if ! grep -q '$HOME/.local/share/uv/bin' ~/.zshrc; then
    echo "export PATH=$new_path" >>~/.zshrc
  fi
}

install_or_update_python_versions() {
  local python_list_output
  python_list_output=$(uv python list)

  local uv_installed_versions
  uv_installed_versions=$(echo "$python_list_output" | grep -E '\.local/share/uv/' | awk '{print $1}' | sed 's/^cpython-//' | cut -d'-' -f1 | cut -d'.' -f1,2 | sort -V | uniq)

  local uv_installed_full_versions
  uv_installed_full_versions=$(echo "$python_list_output" | grep -E '\.local/share/uv/' | awk '{print $1}' | sed 's/^cpython-//' | cut -d'-' -f1)

  local all_versions
  all_versions=$(echo "$python_list_output" | awk '{print $1}' | sort -rV)
  local selected_versions=()
  local seen_versions=()

  for full_version in $all_versions; do
    local short_version
    short_version=$(echo "$full_version" | cut -d'.' -f1,2)

    if [[ " ${seen_versions[*]} " =~ " ${short_version} " ]]; then
      continue
    fi

    seen_versions+=("$short_version")
    selected_versions+=("$full_version")
  done

  local sorted_versions
  sorted_versions=$(printf "%s\n" "${selected_versions[@]}" | sort -V)

  for version_info in $sorted_versions; do
    local full_version
    full_version=$(echo "$version_info" | sed 's/^cpython-//' | cut -d'-' -f1)
    local short_version
    short_version=$(echo "$full_version" | cut -d'.' -f1,2)

    if echo "$python_list_output" | grep -q "$version_info.*<download available>"; then
      if echo "$uv_installed_versions" | grep -q "^$short_version$"; then
        local current_installed
        current_installed=$(echo "$uv_installed_full_versions" | grep "^$short_version" | sort -V | tail -n 1)

        if [ "$current_installed" != "$full_version" ]; then
          print_status updating "$current_installed to $full_version"
          hide_output uv python install "$full_version"
          make_python_symlinks "$version_info" "$short_version"
          print_status installed "Python $short_version"
        else
          print_status already_installed "Python $short_version"
        fi
      else
        print_status installing "Python $short_version"
        hide_output uv python install "$version_info"
        make_python_symlinks "$version_info" "$short_version"
        print_status installed "Python $short_version"
      fi
    else
      make_python_symlinks "$version_info" "$short_version"
      print_status already_installed "Python $short_version"
    fi
  done
}

main() {
  process_options "$@"
  configure_touch_id_for_sudo
  install_or_update_command_line_tools
  install_oh_my_zsh
  install_homebrew
  install_or_update_uv
  install_npm
  install_or_update_python_versions
  echo "All done! ✨ 🍰 ✨"
}

main "$@"
