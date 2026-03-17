# Coka 电商平台 - 阿里云架构

[![CI/CD](https://github.com/zxpwolf/coka/actions/workflows/deploy.yml/badge.svg)](https://github.com/zxpwolf/coka/actions/workflows/deploy.yml)
[![License](https://img.shields.io/badge/license-Proprietary-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)

Coka 是一个高可用的 B2C 电商平台，基于阿里云构建，支持弹性伸缩、多可用区容灾、自动化 CI/CD。

---

## 📑 目录

- [架构设计](docs/ARCHITECTURE.md)
- [监控设计](docs/MONITORING.md)
- [Terraform 配置](terraform/)
- [CI/CD 流程](.github/workflows/)

---

## 🏗️ 架构概览

```
                                    ┌─────────────────────────────────────────┐
                                    │            阿里云 (华东 2-上海)            │
                                    │                                         │
┌──────────┐                        │  ┌─────────────────────────────────┐   │
│   用户   │ ──────┐                │  │      CDN + WAF + SLB            │   │
└──────────┘       │                │  └──────────────┬──────────────────┘   │
                   ▼                │                 │                       │
            ┌─────────────┐         │  ┌──────────────┴──────────────────┐   │
            │   CDN       │         │  │      Auto Scaling (ECS)         │   │
            └─────────────┘         │  │  ┌─────┐ ┌─────┐ ┌─────┐        │   │
                   │                │  │  │ ECS │ │ ECS │ │ ECS │ ...   │   │
                   │                │  │  └─────┘ └─────┘ └─────┘        │   │
                   ▼                │  └─────────────────────────────────┘   │
            ┌─────────────┐         │                 │                       │
            │   SLB       │         │  ┌──────────────┴──────────────────┐   │
            └─────────────┘         │  │      RDS MySQL + Redis          │   │
                   │                │  │      (高可用主从)                │   │
                   │                │  └─────────────────────────────────┘   │
                   │                │                                         │
    ┌──────────────┴──────────────┐ │  ┌─────────────────────────────────┐   │
    │              │              │ │  │      OSS + SLS + Monitor        │   │
    ▼              ▼              ▼ │  └─────────────────────────────────┘   │
┌───────┐  ┌───────┐  ┌───────┐   │  └─────────────────────────────────┘   │
│ Redis │  │Rocket │  │   ES  │   │                                         │
│Cluster│  │  MQ   │  │Search │   │                                         │
└───────┘  └───────┘  └───────┘   │                                         │
                                  └─────────────────────────────────────────┘
```

---

## 🚀 快速开始

### 前置条件

- Terraform >= 1.5.0
- Alibaba Cloud CLI >= 3.0
- Docker >= 24.0
- Node.js >= 20.0
- GitHub Account

### 1. 克隆项目

```bash
git clone https://github.com/zxpwolf/coka.git
cd coka
```

### 2. 配置阿里云凭证

```bash
# 方式 1: 阿里云 CLI
aliyun configure

# 方式 2: 环境变量
export ALIBABA_CLOUD_ACCESS_KEY_ID=your_access_key_id
export ALIBABA_CLOUD_ACCESS_KEY_SECRET=your_access_key_secret
```

### 3. 初始化 Terraform

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 4. 部署应用

```bash
# 开发环境 (自动)
git push origin develop

# 生产环境 (手动审批)
gh workflow run deploy.yml --field environment=prod --ref release/v1.0.0
```

---

## 📁 项目结构

```
coka/
├── docs/                      # 文档
│   ├── ARCHITECTURE.md       # 架构设计文档
│   ├── MONITORING.md         # 监控设计文档
│   └── API.md                # API 文档
├── terraform/                 # Terraform 配置
│   ├── modules/              # 可复用模块
│   │   ├── vpc/
│   │   ├── ecs/
│   │   ├── rds/
│   │   ├── redis/
│   │   ├── slb/
│   │   └── ...
│   └── environments/         # 环境配置
│       ├── dev/
│       ├── test/
│       └── prod/
├── .github/                   # GitHub 配置
│   └── workflows/            # CI/CD 流水线
│       ├── ci.yml
│       └── deploy.yml
├── scripts/                   # 脚本
│   ├── init.sh
│   ├── backup.sh
│   └── cleanup.sh
├── src/                       # 应用源码
│   ├── api/
│   ├── web/
│   └── shared/
├── k8s/                       # Kubernetes 配置
│   ├── deployments/
│   ├── services/
│   └── configmaps/
└── tests/                     # 测试
    ├── unit/
    ├── integration/
    └── performance/
```

---

## 🛠️ 技术栈

### 前端

- **框架:** React 18 + TypeScript
- **UI 库:** Ant Design 5.x
- **状态管理:** Redux Toolkit
- **构建工具:** Vite 5.x

### 后端

- **框架:** NestJS 10.x + TypeScript
- **数据库:** MySQL 8.0 (RDS)
- **缓存:** Redis 7.0
- **消息队列:** RocketMQ 5.0
- **搜索:** Elasticsearch 8.0

### 基础设施

- **云平台:** 阿里云 (华东 2-上海)
- **容器:** Docker + ACK (Kubernetes)
- **IaC:** Terraform 1.5+
- **CI/CD:** GitHub Actions + 阿里云效
- **监控:** CloudMonitor + ARMS + SLS

---

## 📊 环境对比

| 特性 | 开发环境 | 测试环境 | 生产环境 |
|------|----------|----------|----------|
| **域名** | dev.coka.com | test.coka.com | www.coka.com |
| **可用区** | 单可用区 | 单可用区 | 多可用区 |
| **ECS** | 2 台 | 4 台 | 6-20 台 (弹性) |
| **RDS** | 2vCPU 4GB | 4vCPU 8GB | 8vCPU 16GB (主备) |
| **Redis** | 1GB 主从 | 2GB 主从 | 8GB 集群 |
| **SLB** | 无 | slb.s1.small | slb.s2.large |
| **部署** | 自动 | 自动 | 手动审批 |

---

## 🔒 安全

### 访问控制

- RAM 角色最小权限原则
- MFA 多因素认证
- Security Group 网络隔离
- WAF Web 应用防火墙

### 数据安全

- 敏感数据加密存储 (AES-256)
- 传输加密 (TLS 1.3)
- 数据库审计日志
- 定期备份与恢复演练

### 合规

- 等保三级认证
- GDPR 合规
- PCI DSS (支付卡行业)

---

## 📈 监控告警

### 监控指标

- **基础设施:** CPU、内存、磁盘、网络
- **应用性能:** QPS、响应时间、错误率
- **业务指标:** 订单量、GMV、支付成功率

### 告警级别

| 级别 | 名称 | 响应时间 | 通知方式 |
|------|------|----------|----------|
| **P0** | 致命 | 5 分钟 | 电话 + 短信 + 钉钉 |
| **P1** | 严重 | 15 分钟 | 短信 + 钉钉 |
| **P2** | 警告 | 1 小时 | 钉钉 |
| **P3** | 提示 | 4 小时 | 钉钉 |

---

## 💰 成本估算

| 资源 | 开发环境 | 测试环境 | 生产环境 |
|------|----------|----------|----------|
| **ECS** | 560 元/月 | 2,240 元/月 | 8,960 元/月 |
| **RDS** | 400 元/月 | 800 元/月 | 2,400 元/月 |
| **Redis** | 200 元/月 | 400 元/月 | 1,200 元/月 |
| **网络** | - | 50 元/月 | 550 元/月 |
| **存储** | - | - | 50 元/月 |
| **安全** | - | - | 990 元/月 |
| **监控** | - | - | 500 元/月 |
| **合计** | **~1,160 元/月** | **~3,490 元/月** | **~14,650 元/月** |

> 💡 使用抢占式实例和预留实例券可节省 30-50% 成本

---

## 🤝 贡献

### 开发流程

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

### 代码规范

- 遵循 [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)
- 所有代码必须通过 ESLint 和 Prettier 检查

---

## 📝 变更日志

详见 [CHANGELOG.md](CHANGELOG.md)

---

## 📄 许可证

 proprietary - 专有软件，未经许可不得复制或分发

---

## 👥 团队

- **架构师:** Infrastructure Team
- **开发:** Engineering Team
- **运维:** SRE Team

---

## 📞 联系

- **项目主页:** https://github.com/zxpwolf/coka
- **问题反馈:** https://github.com/zxpwolf/coka/issues
- **内部文档:** https://confluence.coka.com

---

**最后更新:** 2026-03-17
