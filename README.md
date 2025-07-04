# 银行管理系统Web应用 - 部署说明

## 项目简介
本项目是一个基于Flask的银行管理系统Web应用，提供用户注册、登录、存款、取款、转账等功能，同时支持管理员查看系统操作日志。

## 功能特点
- 用户注册与登录（注册功能已放在登录前）
- 账户余额查询
- 存款、取款、转账操作
- 交易记录查询
- 管理员日志查看功能
- 响应式界面设计，支持移动端和桌面端

## 系统要求
- Python 3.8+
- MySQL 5.7+
- 现代浏览器（Chrome、Firefox、Edge等）

## 安装步骤

### 1. 准备环境
```bash
# 创建虚拟环境
python -m venv venv

# 激活虚拟环境
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

#单独安装某个模块
pip install 模块名
例如install blinker==1.9.0
pip install blinker==1.9.0
```

### 2. 数据库配置
- 创建MySQL数据库：`groupone`
- 数据库连接配置在`src/main.py`中，默认配置：
  - 用户名：root
  - 密码：password
  - 主机：localhost
  - 端口：3306
  - 数据库名：groupone

如需修改数据库连接信息，可通过环境变量设置：
```bash
export DB_USERNAME=your_username
export DB_PASSWORD=your_password
export DB_HOST=your_host
export DB_PORT=your_port
export DB_NAME=your_dbname

set DB_USERNAME=root
set DB_PASSWORD=123456
set DB_HOST=127.0.0.1
set DB_PORT=3306
set DB_NAME=groupone
```

### 3. 初始化数据库
启动应用后，访问`/init_db`路由初始化数据库表结构和管理员账户。

### 4. 启动应用
```bash
# 确保在虚拟环境中
python -m src.main
```

应用将在`http://localhost:5000`启动。

## 默认账户
系统初始化后会创建一个管理员账户：
- 账号：admin
- 密码：admin123

## 目录结构
```
bank_web_app/
├── venv/                  # 虚拟环境
├── src/                   # 源代码
│   ├── models/            # 数据库模型
│   │   └── models.py      # 数据库表定义
│   ├── routes/            # 路由控制器
│   │   ├── account.py     # 账户相关路由
│   │   ├── admin.py       # 管理员相关路由
│   │   └── auth.py        # 认证相关路由
│   ├── static/            # 静态文件
│   │   ├── index.html     # 登录/注册页面
│   │   ├── dashboard.html # 用户仪表盘
│   │   └── admin_*.html   # 管理员页面
│   └── main.py            # 应用入口
└── requirements.txt       # 依赖列表
```

## 使用说明

### 普通用户
1. 访问首页，选择"注册"标签注册新账户
2. 使用生成的账号和设置的密码登录
3. 在用户仪表盘可进行存款、取款、转账和查看交易记录

### 管理员
1. 使用管理员账号登录（账号：admin，密码：admin123）
2. 在管理员控制台可查看系统概况、操作日志和用户列表
3. 可按账号、操作类型、日期等筛选查看日志

## 注意事项
- 本应用仅用于演示和学习目的
- 生产环境部署时，请使用生产级WSGI服务器（如Gunicorn、uWSGI等）
- 请妥善保管管理员账号密码
