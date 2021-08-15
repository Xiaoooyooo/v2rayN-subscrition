#!/bin/bash
# =================
# ! 首先运行下面这行命令
# wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/master/install.sh" && chmod +x install.sh && bash install.sh
# =================
SERVER_ENTRY="app.js"

v2ray_config='"/usr/local/vmess_qr.json"'
nginx_conf="/etc/nginx/conf/conf.d/v2ray.conf"

GREEN="\e[32m"
END="\e[0m"

# 检查系统是否安装了node
check_node() {
  echo -e "${GREEN}Check if node installed${END}"
  if node -v
  then
    echo -e "${GREEN}系统安装了Node${END}"
  else
    read -rp "系统没有安装Node，是否安装Node(v14.17.5)？（y/n）" s
    [[ -z $s ]] && s="y"
    case $s in
      y)
        install_node
        ;;
      *)
        echo "Cancel"
        echo -e "确保安装了Node并配置了环境变量再试"
        exit 1
        ;;
    esac
  fi
}
# 安装Node
install_node() {
  echo -e "${GREEN}Install Node-v14.17.5${END}"
  wget -O node.tar.xz https://nodejs.org/dist/v14.17.5/node-v14.17.5-linux-x64.tar.xz
  if [[ `cd /usr/node` != 0 ]]
  then
    mkdir /usr/node
  fi
  tar -xJvf node.tar.xz -C /usr/node
  PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/usr/node/node-v14.17.5-linux-x64/bin
  export PATH
  echo "node -v "`node -v`
  echo "npm -v "`npm -v`
  echo "npx -v "`npx -v`
  echo -e "${GREEN}Node installed${END}"
}
# 安装node依赖
install_npm_dependencies() {
  cat >package.json <<EOF
  {
    "name": "v2ray_subscription",
    "version": "1.0.0",
    "description": "",
    "main": "index.js",
    "scripts": {},
    "keywords": [],
    "author": "",
    "license": "ISC",
    "dependencies": {
      "Base64": "^1.1.0",
      "koa": "^2.13.1",
      "pm2": "^5.1.0"
    }
  }
EOF
  echo -e "${GREEN}Install npm dependencies${END}"
  yarn
  if [[ $? != 0 ]]
  then
    echo -e "${GREEN}没有检测到yarn，使用npm install${END}"
    npm install
  fi
  echo "${GREEN}done${END}"
}
# 创建app.js
write_app() {
  cat >app.js <<EOF
  const Koa = require("koa");
  const base64 = require("Base64");
  const config = require(${v2ray_config});
  const app = new Koa();

  app.use(async (ctx) => {
    const a = base64.btoa(JSON.stringify(config));
    const b = base64.btoa(\`vmess://\${a}\`);
    ctx.set("content-type", "text/plain");
    ctx.body = b;
  });

  app.listen(8888, () => {
    console.log("http://127.0.0.1:8888");
  });
EOF
}
# 启动服务器
start_node_app() {
  echo -e "${GREEN}starting server${END}"
  echo -e "${GREEN}first try to stop app${END}"
  npx pm2 stop $SERVER_ENTRY
  echo -e "${GREEN}then try to start app${END}"
  npx pm2 start $SERVER_ENTRY
  echo -e "${GREEN}server started${END}"
}
# 修改nginx配置
modify_nginx() {
  new_config="location /sub/\n{\nproxy_pass http://127.0.0.1:8888\$request_uri;\n}"
  sed -ie "/location/ i ${new_config}" ${nginx_conf}
  service nginx reload
  echo -e "${GREEN}Update Nginx Success${END}"
}
start() {
  mkdir ~/v2ray-subscribtion && cd ~/v2ray-subscribtion
  check_node
  write_app
  install_npm_dependencies
  start_node_app
  modify_nginx
  cd ~
}
start