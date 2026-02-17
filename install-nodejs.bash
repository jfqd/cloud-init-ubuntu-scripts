!/usr/bin/bash

NODE_JS_VERSION="14.21.3"

apt-get -y install gcc g++ build-essential make git npm
npm update -g

npm install -g inherits n
/usr/local/bin/n $NODE_JS_VERSION
