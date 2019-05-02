#!/usr/bin/env bash

echo ">>> Updating apt-get"
sudo apt-get update --fix-missing

echo ">>> Installing Dependencies"
sudo apt-get -y install \
curl \
tree \
git \
sendmail \
socat \
vim \
libcurl4-openssl-dev \
sudo \
unzip \
redis-server

echo ">>> Installing init script for litabot"
sudo cp /vagrant/scripts/lita-hockeybot.conf /etc/init/

echo ">>> Installing Ruby RVM"
command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -L get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install ruby-2.0.0-p648
rvm use 2.0.0 --default
gem install bundler

echo ">>> Bundling litabot gem"
cd /vagrant/workspace
bundle install --path vendor/ --binstubs bin

echo ">>> Starting litabot"
sudo service lita-hockeybot start
