#!/usr/bin/env bash
set -e

# ASK Helper
ask() {
  # http://djm.me/ask
  while true; do

    if [ "${2:-}" = "Y" ]; then
      prompt="Y/n"
      default=Y
    elif [ "${2:-}" = "N" ]; then
      prompt="y/N"
      default=N
    else
      prompt="y/n"
      default=
    fi

    # Ask the question
    read -p "$(echo -e "$1 [$prompt] ")" REPLY

    # Default?
    if [ -z "$REPLY" ]; then
       REPLY=$default
    fi

    # Check if the reply is valid
    case "$REPLY" in
      Y*|y*) return 0 ;;
      N*|n*) return 1 ;;
    esac

  done
}

# Color helpers
txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White
bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White
undblk='\e[4;30m' # Black - Underline
undred='\e[4;31m' # Red
undgrn='\e[4;32m' # Green
undylw='\e[4;33m' # Yellow
undblu='\e[4;34m' # Blue
undpur='\e[4;35m' # Purple
undcyn='\e[4;36m' # Cyan
undwht='\e[4;37m' # White
bakblk='\e[40m'   # Black - Background
bakred='\e[41m'   # Red
bakgrn='\e[42m'   # Green
bakylw='\e[43m'   # Yellow
bakblu='\e[44m'   # Blue
bakpur='\e[45m'   # Purple
bakcyn='\e[46m'   # Cyan
bakwht='\e[47m'   # White
txtrst='\e[0m'    # Text Reset

# Check for GNU Stow
if ! hash stow 2>/dev/null; then
    echo -e "${txtred}ERORR: GNU Stow is required!${txtrst}\nPlease install it in order to continue."
    exit 1;
fi

# Install packages (pacman, AUR, npm etc)
ask "${undylw}Install packages?${txtrst}" Y && echo -e "${undwht}Will${txtrst} ${txtwht}install them sometime in the future${txtrst} ${txtylw}:)${txtrst}";

mkdir -p ~/dotfile_conflicts
echo -e "${undylw}Backing up conflicts to ~/dotfile_conflicts..${txtrst}"
IFS=$'\n'

for file in $(stow -n $(ls */ -d) 2>&1 | grep -oE ":.+" | cut -c3-); do
    if [ -f ~/$file ]; then
        mkdir -p ~/dotfile_conflicts/$(dirname $file)
        mv ~/$file ~/dotfile_conflicts/$file
        echo $file
    fi
done

echo -e "${txtylw}Linking dotfiles to home dir...${txtrst}"
stow $(ls */ -d)

echo -e "{$txtgrn}DONE!{$txtrst}"
