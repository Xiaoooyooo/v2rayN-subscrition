这是一个基于[V2Ray 基于 Nginx 的 vmess+ws+tls 一键安装脚本](https://github.com/wulabing/V2Ray_ws-tls_bash_onekey)的订阅服务器设置脚本
首先按照上面链接中的说明进行操作
之后再运行该脚本

```bash
wget -N --no-check-certificate -q -O sub.sh "https://raw.githubusercontent.com/Xiaoooyooo/v2rayN-subscrition/master/sub.sh" && chmod +x sub.sh && bash sub.sh
```

订阅接口的地址为`/sub/`

**注意事项（2021.08.15）**

+ 如果没有在系统中安装Nodejs，而要在此脚本中同步安装Nodejs（版本v14.17.5），可使用`source sub.sh`运行该脚本，这会在安装Nodejs的同时将其自动注入到环境变量，**可能会覆盖原来的环境变量，请谨慎操作**

  Nodejs会被解压至：`/usr/node/node-v14.17.5-linux-x64`

  新的环境变量如下：

  ```bash
  PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/usr/node/node-v14.17.5-linux-x64/bin
  ```

+ 自用为主
