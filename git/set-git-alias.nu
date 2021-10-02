# Author: hustcer
# Created: 2021/10/01 23:05:20
# Usage:
#   nu ./git/set-git-alias.nu

# Set up git configs:
git config --global color.ui true;
git config --global alias.st status;
git config --global alias.sh stash;
git config --global alias.br branch;
git config --global alias.ci commit;
git config --global alias.co checkout;
git config --global alias.pl 'pull --rebase';
git config --global alias.mg "merge --no-ff";
git config --global alias.rv "revert --soft HEAD^";
git config --global alias.dis 'reset --hard HEAD^';
git config --global alias.today 'diff --shortstat "@{1 day ago}"';
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";

git config --global push.default matching;
# git config --global user.name $GIT_USER_NAME;
# git config --global user.email $GIT_USER_EMAIL;
