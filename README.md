# initialsetup
A fast setup environment for Ubuntu initial configuration.

Inspired by fast.ai, fastsetup.

- Set up environment variables and do basic configuration.
- Installing apt-fast, a shell script wrapper for apt-get.
- Installing the required build-tools.
- Configuring time sync (ntp).
- Enabling Firewall (ufw).
- Adding a user with sudoers privileges, and access to Git over SSH.

Prerequisites:

Creating a VM from offical ISO boot image Ubuntu 18 (Bionic Beaver):

1. Basic Ubuntu installation from offical ISO boot image 18.04.6 LTS (x64 Platform).
2. Configure network connections.
3. Hard-Disk sizing and partitionning (LVM) with 50 GB minimum disk space.
4. Profile setup by adding a user root (ubuntu) and server name (fqdn).
5. Set password root.
6. Wired connected to external network (ping 8.8.8.8 done with success).

> Setup all the things

First, do basic ubuntu configuration, such as updating packages and installing required build-tools:

Edit the script before running if you need to set up your own [public ntp time servers](https://www.ntppool.org/).

```
sudo apt update && sudo apt -y install git
git clone https://github.com/hthevenaz/initialsetup.git
cd initialsetup && chmod +x *.sh
sudo ./ubuntu-initial.sh
# wait a couple of minutes for reboot, then ssh back in.
```

Add a new user with sudoers privileges, and access to Git over SSH:

For example:
```
sudo ./add-user.sh -u USERNAME --git-name 'John Doe' --git-email john.doe@xxx.com --git-host github.com
```

[Copy-Paste the public key to your account on Git](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

Open a new terminal and login as USERNAME.

Test ssh connection to Git by typing the command: 

```
ssh -T git@github.com
# Hi jDoe! You've successfully authenticated, but GitHub does not provide shell access.
```

Clone your personal repo and change the current working directory to your local project:

```
git clone git@github.com:USERNAME/REPONAME.git
```
