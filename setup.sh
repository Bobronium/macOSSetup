#!/bin/bash

# shellcheck disable=SC2153
verbose=$VERBOSE
while getopts "v" OPTION
do
  case $OPTION in
    v) verbose=true
       ;;
  esac
done

if [ "$verbose" ]; then
  log() { printf "$@\n"; }
else
  log() { :; }
fi

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[93m"
MAGENTA="\e[95m"
ENDCOLOR="\e[0m"

already_installed() { log "${MAGENTA}Already installed:${ENDCOLOR} $TARGET"; }
installing() { log "${YELLOW}Installing:${ENDCOLOR} $TARGET"; }
install_status() {
  if [[ $? == 0 ]]; then
    log "${GREEN}Installed:${ENDCOLOR} $TARGET"
  else
    log "${RED}Failed to install:${ENDCOLOR} $TARGET"
  fi;
  }

already_configured() { log "${MAGENTA}Already configured:${ENDCOLOR} $TARGET"; }
configuring() { log "${YELLOW}Configuring:${ENDCOLOR} $TARGET"; }
config_status() {
  if [[ $? == 0 ]]; then
    log "${GREEN}Configured:${ENDCOLOR} $TARGET"
  else
    log "${RED}Failed to configure:${ENDCOLOR} $TARGET"
  fi;
  }

TARGET="sudo access with Touch ID"
sudo_file="/etc/pam.d/sudo"
touch_id_auth_option="auth       sufficient     pam_tid.so"
awk_command=$"NR==2{print \"$touch_id_auth_option\"}1"
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


TARGET="pyenv"
if pyenv --version > /dev/null 2>&1; then
  already_installed
else
  installing
  brew install pyenv
install_status
fi

TARGET="Python3.10"
if pyenv versions | grep 3.10 > /dev/null 2>&1; then
  already_installed
else
  installing
  pyenv install 3.10:latest
  version=$(pyenv versions | grep -oE "3.10.\d{1,}")
  pyenv global | xargs pyenv global "$version"
install_status
fi

TARGET="pipx"
if pipx --version > /dev/null 2>&1; then
  already_installed
else
  installing
  $(pyenv which python3.10) -m pip install pipx-in-pipx
install_status
fi

TARGET="npm"
if npm --version > /dev/null 2>&1; then
  already_installed
else
  installing
  brew install npm
install_status
fi


echo "All done! ✨ 🍰 ✨"

