#!/bin/bash
#
# This script is designed to work on ubuntu 18 LTS (Bionic Beaver). 
#
# Add a new user with sudoers privileges, and access to Git over SSH.
#
# Run:
#
# sudo ./add-user.sh -u <username> --git-name <fullname> --git-email <email> --git-host <fqdn>
#
# Open a new terminal, login as <username>. 
# Add the public key to your account on Git.
#
# Post-installation:
#
# Check git configuration by typing the command: 
#
# git config --list
#
# If you need to renewal the SSH key to use for authentication:
#
# ssh-keygen -q -t rsa -N '' -b 4096 -f ~/.ssh/id_rsa
#
# Ressources:
#
# https://docs.github.com/en/get-started/quickstart/set-up-git
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
#
# Versioning:
#
# Version 1.0 - 30.05.2022 -- Creation date.
#
# Author : Herve Thevenaz.

set -e
fail () { echo $1 >&2; exit 1; }
[[ $(id -u) = 0 ]] || fail "Please run as root."

# ------------------------------------------------------------------------
# Declare bash script local variables
# ------------------------------------------------------------------------

SCRIPTNAME=$0
SUDO_USER=
GIT_NAME=
GIT_EMAIL=
GIT_HOSTNAME=

# ------------------------------------------------------------------------
# Manage bash script args
# ------------------------------------------------------------------------

#Declare the number of mandatory args
MARGS=1

# Common functions - BEGIN
function example {
    echo -e 'example: sudo '$SCRIPTNAME' -u <username> --git-name "<fullname>" --git-email <email> --git-host <fqdn>'
}

function help {
    echo -e "Bash script version in "$VERSION
    echo -e "OPTION:"
    echo -e "  -u,  --username              Identification with access to the machine"
    echo -e "  --git-name                   Set a name associate commits with an identity for git configuration (eg: 'John Doe')" 
    echo -e "  --git-email                  set a email for git configuration (eg: john.doe@xxx.com)"
    echo -e "  --git-host                   set a hostname for git configuration (eg: github.com)"    
    echo -e "  -h,  --help                  Prints this help\n"
  example
}

# Ensures that the number of passed args are at least equals
# to the declared number of mandatory args.
# It also handles the special case of the -h or --help arg.
function margs_precheck {
        if [ $2 ] && [ $1 -lt $MARGS ]; then
                if [ $2 == "--help" ] || [ $2 == "-h" ]; then
                        help
                        exit
                else
                        example
                        exit 1 # error
                fi
        fi
}

# Ensures that all the mandatory args are not empty
function margs_check {
        if [ $# -lt $MARGS ]; then
                example
                exit 1 # error
        fi
}
# Common functions - END

# Main
margs_precheck $# $1

# Args while-loop
while [ "$1" != "" ];
do
   case $1 in
   -u  | --username  )             shift
                                   SUDO_USER=$1
                                   ;;
   --git-name  )                   shift
                                   GIT_NAME=$1
                                   ;;
   --git-email  )                  shift
                                   GIT_EMAIL=$1
                                   ;;
   --git-host  )                   shift
                                   GIT_HOSTNAME=$1
                                   ;;
   -h   | --help )                 help
                                   exit
                                   ;;
   *)
              echo "$script: illegal option $1"
              example
              exit 1 # error
              ;;
    esac
    shift
done

# Pass here your mandatory args for check
margs_check $SUDO_USER $GIT_NAME $GIT_EMAIL $GIT_HOSTNAME

# ------------------------------------------------------------------------
# Add user with sudoers privileges
# ------------------------------------------------------------------------

adduser --home /home/$SUDO_USER --shell /bin/bash --quiet --gecos '' $SUDO_USER
usermod -aG sudo $SUDO_USER
HOME=/home/$SUDO_USER
echo "$SUDO_USER  ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
chown -R $SUDO_USER:$SUDO_USER ~/

# ------------------------------------------------------------------------
# Set up common rules for sudoers
# ------------------------------------------------------------------------

perl -ni.bak -e 'print unless /^\s*(Defaults)/' /etc/sudoers
tee -a /etc/sudoers << EOF > /dev/null
Defaults        timestamp_timeout=3600
EOF

# ------------------------------------------------------------------------
# Configure SSH
# ------------------------------------------------------------------------

mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate an SSH public/private keypair 
ssh-keygen -q -t rsa -N '' -b 4096 -f ~/.ssh/id_rsa

cat > ~/.ssh/config << EOF
Host *
  ServerAliveInterval 60
  StrictHostKeyChecking no

Host $GIT_HOSTNAME
  User git
  Port 22
  Hostname $GIT_HOSTNAME
  TCPKeepAlive yes
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/id_rsa
EOF
chmod 600 ~/.ssh/config
chown -R $SUDO_USER:$SUDO_USER ~/.ssh

# ------------------------------------------------------------------------
# Configure Git
# ------------------------------------------------------------------------

cat > ~/.gitconfig << EOF
[user]
        name = $GIT_NAME
        email = $GIT_EMAIL
        
[push]
        default = simple
        
[credential]
        helper = cache --timeout=7200
        
[filter "lfs"]
        clean = git-lfs clean -- %f
        smudge = git-lfs smudge -- %f
        process = git-lfs filter-process        
        required = true
        
[pull]
        rebase = true
        
[rebase]
        autoStash = true
        
[submodule]
        recurse = true
        
[diff]
        submodule = log
        
[status]
        submodulesummary = 1
        
[branch]
        autosetuprebase = always
        
[core]
        filemode = false
EOF
chown -R $SUDO_USER:$SUDO_USER ~/.gitconfig

# ------------------------------------------------------------------------
# Add aliases for Git
# ------------------------------------------------------------------------

cat >> ~/.bash_aliases << EOF

# Add aliases for git
# Example 1: commit 'my comment here ...'
# Example 2: fixes comment
commit () { git commit -am "\${1}" && git push; }
fixes () { git commit -am "fixes #\${1}" && git push; }
EOF

# ------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------

echo
echo 'Open a new terminal and login as '$SUDO_USER 
echo 'Copy-Paste the public key to your account on '$GIT_HOSTNAME
echo
cat ~/.ssh/id_rsa.pub
echo
