#!/bin/zsh
#
# Version : 1.2
#
# Source : https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2
# Nécessite argon2 / Need argon2 : brew install argon2      ou / or : brewi argon2


# ~~~~~~~ Some functions definitions ~~~~~~ #

function yes_or_no {
    # Source : https://stackoverflow.com/a/29436423/17694638
    #    and : https://linuxconfig.org/bash-script-yes-no-prompt-example
    #    and : https://9to5answer.com/how-can-i-prompt-for-yes-no-style-confirmation-in-a-zsh-script
    while true; do
        if [[ "${SHELL}" == *"zsh"* ]]; then
            # SHELL = ZSH
            read -q "REPLY?$* [y/n] : "
        elif [[ "${SHELL}" == *"bash"* ]]; then
            # SHELL = BASH
            read -p "$* [y/n]: " REPLY
        fi
        printf "\n"
        case $REPLY in
        [Yy]) return 0 ;;
        [Nn])
            # echo "Aborted"
            return 1
            ;;
        *) printf "Invalid response!" ;;
        esac
    done
}

function print_argon2_output() {
    printf "\t\t* for docker/podman CLI command:\n\n\t\t\t%s\n\n" ${SECURE_ADMIN_TOKEN}
    printf "\t\t* for docker-compose.yml file:\n\n\t\t\t%s\n\n" ${SECURE_ADMIN_TOKEN//\$/\$\$}
    printf "\n"
}
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# ~~~~~~~~~~~~~~ Main script ~~~~~~~~~~~~~~ #

# Check if argon2 is installed
if [ ! "$(command -v argon2)" ]; then
    printf "Command \"argon2\" doesn't exists on this system.\n"
    printf "Please install it before launching again the script...\n"
    if [[ "$OSTYPE" == "darwin"* ]]; then       # See : https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script
        # Mac OSX
        printf "macOS detected !"
        if [ "$(command -v brew)" ]; then
            # Homebrew is installed
            printf " And HomeBrew is installed.\n"
            yes_or_no "Do you want me to install argon2 for you?"
            return_code="$?"
            if (( $return_code == 0 )); then
                printf "Installation of argon2 with homebrew...\n"
                brew update && brew upgrade
                brew install argon2
            else
                printf "argon2 needs to be installed. Install it and relaunch the script.\n"
                exit 1
            fi
        else
            printf " But HomeBrew isn't installed...\n"
            yes_or_no "Do you want me to install homebrew and argon2 for you? (you'll need internet access...)"
            return_code="$?"
            if (( $return_code == 0 )); then
                printf "Installation of homebrew...\n"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                printf "Installation of argon2 with homebrew..."
                brew update && brew upgrade
                brew install argon2
            else
                printf "argon2 needs to be installed. Install it and relaunch the script."
                exit 1
            fi
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "\$OSTYPE" == "cygwin"* ]]; then
        printf "This script may work on linux ($OSTYPE), but it's not tested...\n"
        printf "You may add the linux commands to install argon2 in this 'elif' statement.\nCheck the script. Exiting now.\n"
        exit 1
    else
        printf "This script may work on $OSTYPE, but it's not tested...\n"
        printf "Check the script. Exiting now.\n"
        exit 1

    fi

fi


# On récupère le TOKEN via un copier/coller de l'utilisateur
printf "%s" "Enter (paste) ADMIN_TOKEN: "
read ADMIN_TOKEN

printf "The secure ADMIN_TOKEN is:\n"
# Pour le remplacement de $ par $$ pour le docker-compose, voir : https://unix.stackexchange.com/a/700490

# Using the Bitwarden defaults
SECURE_ADMIN_TOKEN=$(printf "${ADMIN_TOKEN}" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
printf "\t- Using the Bitwarden defaults:\n"
print_argon2_output

# Using the OWASP minimum recommended settings
SECURE_ADMIN_TOKEN=$(printf "${ADMIN_TOKEN}" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
printf "\t- Using the OWASP minimum recommended settings:\n"
print_argon2_output

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #