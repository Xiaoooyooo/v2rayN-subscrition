# =================
# ! 该脚本基于 https://github.com/wulabing/Xray_onekey 中的步骤，请先按照其中内容完成后再执行该脚本
# =================

# 配置文件路径
xray_config="/usr/local/etc/xray/config.json"
nginx_config="/etc/nginx/conf.d"
domain_config="/usr/local/etc/xray/domain"

# 初始化订阅服务器安装路径
if [ -f ./SERVER_PATH ]
then
  SERVER_PATH=$(cat SERVER_PATH)
fi
[ -z $SERVER_PATH ] && SERVER_PATH=$(pwd)
SCRIPT_PATH=$(pwd) # 脚本所在路径，config.json会生成在同目录
echo "服务器目录位于 $SCRIPT_PATH"

update_config() {
  local curr_dir=$(pwd)
  cd $SERVER_PATH
  DOMAIN=$(cat $domain_config)
  UUID=$(cat $xray_config | jq .inbounds[0].settings.clients[0].id | tr -d '"')
  PORT=$(cat "/etc/nginx/conf.d/${DOMAIN}.conf" | grep -m 1 'ssl http2' | awk -F ' ' '{print $2}' )
  FLOW=$(cat $xray_config | jq .inbounds[0].settings.clients[0].flow | tr -d '"')
  WS_PATH=$(cat $xray_config | jq .inbounds[0].streamSettings.wsSettings.path | tr -d '"')

  read -rp "请输入订阅服务器的描述信息（默认：~~~ yooo ~~~）" desc
  [ -z "$desc" ] && desc="~~~ yooo ~~~"

  config=$(cat <<EOF
    {
      "domain": "${DOMAIN}",
      "port": "${PORT}",
      "uuid": "${UUID}",
      "params": {
        "encryption": "none",
        "type": "ws",
        "path": "${WS_PATH}",
        "security": "tls"
      },
      "description": "${desc}"
    }
EOF
)

  echo $config > config.json
  echo "更新配置成功"
  cd $curr_dir
}

check_nodejs() {
  if type node > /dev/null 2>&1
  then
    echo "检测到 Nodejs 已安装"
  else
    echo "未检测到Nodejs"
    read -rp "是否安装Nodejs(16.17.1)？(y/n)" is_install_node
    [ -z "$is_install_node" ] && is_install_node="y"
    c=$(echo $is_install_node | tr -s [:upper:] [:lower:])
    case $is_install_node in
    "yes"|"y")
      install_node
      ;;
    *)
      echo "请手动安装Nodejs后再继续"
      exit 0
      ;;
    esac
  fi
}

install_node() {
  echo "自动安装将会更改环境变量，将nodejs的bin目录添加到系统的PATH，请确保使用的 source 执行该脚本而不是 bash"
  read -rp "是否继续？(y/n)" confirm_install_node
  [ -z "$confirm_install_node" ] && confirm_install_node="y"
  c=$(echo c | tr -s [:upper:] [:lower:])
  if [[ "$confirm_install_node" != "y" && "$confirm_install_node" != "yes" ]]
  then
    echo "取消安装"
    exit 0
  fi
  # https://nodejs.org/dist/v16.17.1/node-v16.17.1-linux-x64.tar.xz
  node_version="node-v16.17.1-linux-x64"
  curl -O "https://nodejs.org/dist/v16.17.1/${node_version}.tar.gz"
  tar -zxf "${node_version}.tar.gz"
  echo "解压 Nodejs 成功"
  PATH=$PATH:$(pwd)/${node_version}/bin
  export PATH=$PATH
  node -v
  if [[ $? == 0 ]]
  then
    echo "Nodejs 安装成功"
  fi
}

check_dir() {
  read -rp "输入路径(~/sub-server)" path
  [ -z $path ] && path="$HOME/sub-server"
  echo "输入为：${path}"
  local retry=0
  if [ -d $path ]
  then
    echo "目录存在"
    files_count=$(ls $path | wc -l)
    if [[ $files_count != 0 ]]
    then
      read -rp "文件夹不为空，是否继续(y/n)" use_no_empty_dir
      [ -z "$use_no_empty_dir" ] && use_no_empty_dir="y"
      use_no_empty_dir=$(echo $use_no_empty_dir | tr -s [:upper:] [:lower:])
      if [[ $use_no_empty_dir != "y" && $use_no_empty_dir != "yes" ]]
      then
        retry=1
      else
        SERVER_PATH=$path
      fi
    else
      echo "文件夹为空"
      SERVER_PATH=$path
    fi
  else
    read -rp "目录不存在，是否新建目录(y/n)" should_create
    should_create=$(echo $should_create | tr -s [:upper:] [:lower:])
    [ -z "$should_create" ] && should_create="y"
    case $should_create in
    "y"|"yes")
      mkdir -p $path
      SERVER_PATH=$path
      ;;
    *)
      echo "操作中断"
      ;;
    esac
  fi

  if [[ $retry != 0 ]]
  then
    check_dir
  else
    echo $path
  fi
}

setup_server() {
  local curr_dir=$(pwd)
  cd $SERVER_PATH
  npm init -y
  echo "安装依赖 Base64"
  npm i Base64 > /dev/null
  echo "安装依赖 pm2"
  npm i pm2 -D > /dev/null
  echo "写入服务入口文件"
  cat > app.js <<EOF
const http = require("http");
const fs = require("fs");
const base64 = require("Base64");

setup();

function setup() {
  http.createServer((req, res) => {
    const { method, url } = req;
    // console.log(method, url);
    if (method === "GET") {
      res.writeHead(200, {
        "content-type": "text/plain;charset=utf-8",
      });
      let config;
      try {
        config = JSON.parse(fs.readFileSync("config.json", { encoding: "utf8" }));
      } catch (err) {
        config = {};
      }
      if (Object.keys(config).length === 0) {
        return res.end("未检测到配置文件");
      }
      let search;
      if (config.params) {
        search = new URLSearchParams();
        for (key in config.params) {
          search.append(key, config.params[key]);
        }
      }
      const link = \`vless://\${config.uuid}@\${config.domain}:\${config.port}?\${search.toString()}#\${config.description}\`;
      res.end(base64.btoa(link));
    } else {
      res.statusCode = 404;
      res.end();
    }
  }).listen(8888);
}
EOF
  cd $curr_dir
  echo $SERVER_PATH > SERVER_PATH
}

start_server() {
  local curr_dir=$(pwd)
  cd $SERVER_PATH
  echo "正在启动服务器"
  npx pm2 start app.js > /dev/null
  echo "服务器启动成功"
  cd $curr_dir
}

stop_server() {
  local curr_dir=$(pwd)
  cd $SERVER_PATH
  echo "正在关闭服务器"
  npx pm2 stop app.js > /dev/null
  echo "服务器关闭成功"
  cd $curr_dir
}

modify_nginx_config() {
  local domain=$(cat $domain_config)
  local nginx_config_file="${nginx_config}/${domain}.conf"
  cp $nginx_config_file ${nginx_config}.bak # 备份原来的配置文件
  read -rp "请输入订阅路径(/sub/)" sub_path
  [ -z "$sub_path" ] && sub_path="/sub/"
  local new_config="location ${sub_path}\n{\nproxy_pass http://127.0.0.1:8888\$request_uri;\n}"
  echo "修改 nginx 配置"
  sed -i "/location/i ${new_config}" $nginx_config_file
  echo "重启 nginx"
  nginx -s reload
  echo "nginx 重启完成"
}

main() {
  if [[ -f $xray_config ]]
  then
    echo "1.更新配置"
    echo "2.安装订阅服务器"
    echo "3.启动订阅服务器"
    echo "4.停止订阅服务器"
    echo "0.退出脚本"
    read -rp "请选择：" code
    case $code in
    1)
      update_config
      ;;
    2)
      echo "安装订阅服务器"
      check_nodejs
      check_dir
      setup_server
      update_config
      start_server
      modify_nginx_config
      ;;
    3)
      echo "启动订阅服务器"
      start_server
      ;;
    4)
      echo "停止订阅服务器"
      stop_server
      ;;
    0)
      echo "退出"
      exit 0
      ;;
    *)
      echo "请输入正确的数字"
      exit 0
      ;;
    esac
  else
    echo "xray配置文件不存在"
    exit 0
  fi
}
main
