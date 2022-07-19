#! /bin/bash
sudo apt update -y
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
sudo apt update
curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
cat /etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/node_14.x focal main
sudo deb https://deb.nodesource.com/node_14.x focal main
sudo apt install deb https://deb.nodesource.com/node_14.x focal main
sudo apt install deb-src https://deb.nodesource.com/node_14.x focal main
sudo apt -y install nodejs
node  -v
sudo apt -y install gcc g++ make
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update && sudo apt install yarn
yarn -V
sudo apt-get update
sudo apt-get install mysql-server -y
sudo systemctl start mysql
sudo systemctl status mysql
sudo yarn create strapi-app my-project --quickstart
sudo yarn build
sudo yarn develop
sudo wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
sudo chmod +x ./install
sudo ./install auto
sudo service codedeploy-agent start
