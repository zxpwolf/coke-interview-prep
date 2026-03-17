# Coka 电商平台 - 阿里云架构设计文档

**版本:** 1.0.0  
**创建日期:** 2026-03-17  
**作者:** Infrastructure Team  
**状态:** Draft

---

## 📑 目录

1. [概述](#1-概述)
2. [架构设计](#2-架构设计)
3. [网络规划](#3-网络规划)
4. [环境设计](#4-环境设计)
5. [计算资源](#5-计算资源)
6. [存储设计](#6-存储设计)
7. [数据库设计](#7-数据库设计)
8. [安全设计](#8-安全设计)
9. [监控设计](#9-监控设计)
10. [CI/CD 方案](#10-cicd-方案)
11. [成本估算](#11-成本估算)
12. [附录](#12-附录)

---

## 1. 概述

### 1.1 项目背景

Coka 是一个高可用的 B2C 电商平台，需要支持：
- **日均 PV:** 100 万+
- **峰值 QPS:** 5000+
- **用户数:** 50 万+
- **商品数:** 10 万+
- **订单处理:** 10 万单/天

### 1.2 设计目标

| 目标 | 指标 |
|------|------|
| **可用性** | 99.95% (年停机 < 4.5 小时) |
| **性能** | 页面加载 < 2 秒，API 响应 < 200ms |
| **扩展性** | 支持 10 倍流量弹性伸缩 |
| **安全性** | 等保三级，数据加密存储 |
| **成本** | 月度云资源成本 < 15,000 元 |

### 1.3 技术选型

| 层级 | 技术栈 |
|------|--------|
| **前端** | React 18 + TypeScript + Ant Design |
| **后端** | Node.js 20 + NestJS + TypeScript |
| **数据库** | MySQL 8.0 (RDS) + Redis 7.0 |
| **缓存** | Redis Cluster + CDN |
| **消息队列** | RocketMQ 5.0 |
| **搜索** | Elasticsearch 8.0 |
| **容器** | Docker + ACK (Kubernetes) |
| **CI/CD** | 阿里云效 + GitHub Actions |

---

## 2. 架构设计

### 2.1 整体架构图

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                    阿里云 (华东 2-上海)                  │
                                    │                                                         │
┌──────────┐                        │   ┌─────────────────────────────────────────────────┐   │
│   用户   │ ──────┐                │   │              Alibaba Cloud CDN                  │   │
└──────────┘       │                │   │              (全球 2800+ 节点)                     │   │
                   ▼                │   └─────────────────────┬───────────────────────────┘   │
            ┌─────────────┐         │                         │                               │
            │   WAF       │         │   ┌─────────────────────┴───────────────────────────┐   │
            │  防火墙     │         │   │           Server Load Balancer (SLB)            │   │
            └─────────────┘         │   │              多可用区 + HTTPS 卸载                 │   │
                   │                │   └─────────────────────┬───────────────────────────┘   │
                   │                │                         │                               │
                   ▼                │   ┌─────────────────────┴───────────────────────────┐   │
            ┌─────────────┐         │   │          Auto Scaling Group (ECS)               │   │
            │  API Gateway│         │   │   ┌─────────────┬─────────────┬─────────────┐   │   │
            └─────────────┘         │   │   │  Zone A     │  Zone B     │  Zone A     │   │   │
                   │                │   │   │  ECS-1      │  ECS-2      │  ECS-3      │   │   │
                   │                │   │   │  (Node.js)  │  (Node.js)  │  (Node.js)  │   │   │
                   │                │   │   └─────────────┴─────────────┴─────────────┘   │   │
                   │                │   └─────────────────────────────────────────────────┘   │
                   │                │                                                         │
    ┌────────────┼────────────┐     │   ┌─────────────────────────────────────────────────┐   │
    │            │            │     │   │              ApsaraDB RDS MySQL                 │   │
    ▼            ▼            ▼     │   │              高可用版 (一主一备一只读)             │   │
┌───────┐  ┌───────┐  ┌───────┐    │   │  ┌─────────┐         ┌─────────┐                │   │
│ Redis │  │Rocket │  │   ES  │    │   │  │ Primary │◄───────►│  Standby │                │   │
│Cluster│  │  MQ   │  │Search │    │   │  │  (ZoneA)│  同步   │ (Zone B)│                │   │
└───────┘  └───────┘  └───────┘    │   │  └─────────┘         └─────────┘                │   │
                                    │   └─────────────────────────────────────────────────┘   │
                                    │                                                         │
                                    │   ┌─────────────────────────────────────────────────┐   │
                                    │   │              Object Storage (OSS)               │   │
                                    │   │              商品图片/静态资源/备份               │   │
                                    │   └─────────────────────────────────────────────────┘   │
                                    │                                                         │
                                    │   ┌─────────────────────────────────────────────────┐   │
                                    │   │              CloudMonitor + SLS                 │   │
                                    │   │              监控 + 日志 + 告警                    │   │
                                    │   └─────────────────────────────────────────────────┘   │
                                    └─────────────────────────────────────────────────────────┘
```

### 2.2 服务分层

| 层级 | 服务 | 说明 |
|------|------|------|
| **接入层** | CDN + WAF + SLB | 流量接入、安全防护、负载均衡 |
| **应用层** | ECS + ACK | 无状态应用，弹性伸缩 |
| **缓存层** | Redis Cluster | 会话、热点数据缓存 |
| **数据层** | RDS + OSS | 持久化存储 |
| **消息层** | RocketMQ | 异步解耦、流量削峰 |
| **搜索层** | Elasticsearch | 商品搜索、日志分析 |

---

## 3. 网络规划

### 3.1 VPC 设计

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VPC: 172.16.0.0/16                                  │
│                        Region: cn-shanghai (华东 2)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  vSwitch-DEV (172.16.1.0/24) - Zone A                               │   │
│  │  - Dev ECS: 172.16.1.10-50                                          │   │
│  │  - Dev RDS: 172.16.1.100                                            │   │
│  │  - Dev Redis: 172.16.1.101                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  vSwitch-TEST (172.16.2.0/24) - Zone B                              │   │
│  │  - Test ECS: 172.16.2.10-50                                         │   │
│  │  - Test RDS: 172.16.2.100                                           │   │
│  │  - Test Redis: 172.16.2.101                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  vSwitch-PROD-A (172.16.10.0/24) - Zone A                           │   │
│  │  - Prod ECS: 172.16.10.10-100                                       │   │
│  │  - Prod RDS Master: 172.16.10.100                                   │   │
│  │  - Prod Redis Master: 172.16.10.101                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  vSwitch-PROD-B (172.16.11.0/24) - Zone B                           │   │
│  │  - Prod ECS: 172.16.11.10-100                                       │   │
│  │  - Prod RDS Standby: 172.16.11.100                                  │   │
│  │  - Prod Redis Standby: 172.16.11.101                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  vSwitch-DB (172.16.20.0/24) - Zone A + B                           │   │
│  │  - RDS Private Zone                                                 │   │
│  │  - Redis Private Zone                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 IP 地址规划

| 环境 | VSwitch | 网段 | 可用区 | 用途 |
|------|---------|------|--------|------|
| **DEV** | vsw-dev | 172.16.1.0/24 | 可用区 A | 开发环境 |
| **TEST** | vsw-test | 172.16.2.0/24 | 可用区 B | 测试环境 |
| **PROD-A** | vsw-prod-a | 172.16.10.0/24 | 可用区 A | 生产环境主 |
| **PROD-B** | vsw-prod-b | 172.16.11.0/24 | 可用区 B | 生产环境备 |
| **DB** | vsw-db | 172.16.20.0/24 | 可用区 A+B | 数据库专区 |

### 3.3 安全组设计

| 安全组 | 名称 | 入站规则 | 出站规则 |
|--------|------|----------|----------|
| **sg-web** | Web 服务器 | 80,443 (0.0.0.0/0) | 全部允许 |
| **sg-app** | 应用服务器 | 3000 (sg-web) | 全部允许 |
| **sg-db** | 数据库 | 3306 (sg-app) | 全部允许 |
| **sg-redis** | 缓存 | 6379 (sg-app) | 全部允许 |
| **sg-mq** | 消息队列 | 9876 (sg-app) | 全部允许 |

### 3.4 路由表设计

```
主路由表 (rtb-main):
├── 172.16.0.0/16 → Local (VPC 内通信)
├── 0.0.0.0/0 → Internet Gateway (公网访问)
└── 10.0.0.0/8 → VPN Gateway (办公网互通)
```

---

## 4. 环境设计

### 4.1 环境对比

| 特性 | 开发环境 (DEV) | 测试环境 (TEST) | 生产环境 (PROD) |
|------|---------------|----------------|----------------|
| **目的** | 日常开发、调试 | 集成测试、压测 | 线上服务 |
| **可用区** | 单可用区 (Zone A) | 单可用区 (Zone B) | 多可用区 (A+B) |
| **ECS 数量** | 2 台 | 4 台 | 6-20 台 (弹性) |
| **RDS 规格** | 2vCPU 4GB | 4vCPU 8GB | 8vCPU 16GB (主备) |
| **Redis 规格** | 1GB 主从 | 2GB 主从 | 8GB 集群版 |
| **SLB** | 无 | slb.s1.small | slb.s2.large |
| **监控级别** | 基础监控 | 标准监控 | 企业级监控 |
| **备份策略** | 不备份 | 每日备份 (保留 3 天) | 每日备份 (保留 30 天) |
| **域名** | dev.coka.com | test.coka.com | www.coka.com |

### 4.2 环境隔离

```
┌─────────────────────────────────────────────────────────────────┐
│                         账号隔离策略                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  DEV 账号   │  │ TEST 账号   │  │ PROD 账号   │             │
│  │  (开发)     │  │  (测试)     │  │  (生产)     │             │
│  │             │  │             │  │             │             │
│  │  VPC-DEV    │  │  VPC-TEST   │  │  VPC-PROD   │             │
│  │  172.16.1.0 │  │  172.16.2.0 │  │  172.16.10.0│             │
│  │             │  │             │  │             │             │
│  │  资源组：   │  │  资源组：   │  │  资源组：   │             │
│  │  - 2 ECS    │  │  - 4 ECS    │  │  - 6-20 ECS │             │
│  │  - 1 RDS    │  │  - 1 RDS    │  │  - 2 RDS    │             │
│  │  - 1 Redis  │  │  - 1 Redis  │  │  - 1 Redis  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│         └────────────────┴────────────────┘                     │
│                          │                                      │
│                  ┌───────┴───────┐                              │
│                  │   RAM 角色    │                              │
│                  │  跨账号访问   │                              │
│                  └───────────────┘                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. 计算资源

### 5.1 ECS 配置

| 环境 | 实例规格 | vCPU | 内存 | 系统盘 | 数量 | 单价 (元/月) |
|------|----------|------|------|--------|------|--------------|
| **DEV** | ecs.g7.large | 2 | 8GB | 100GB ESSD | 2 | 280 |
| **TEST** | ecs.g7.xlarge | 4 | 16GB | 100GB ESSD | 4 | 560 |
| **PROD** | ecs.g7.2xlarge | 8 | 32GB | 200GB ESSD | 6-20 | 1120 |

### 5.2 弹性伸缩配置

```json
{
  "scalingGroup": {
    "name": "coka-prod-asg",
    "minSize": 6,
    "maxSize": 20,
    "desiredCapacity": 8,
    "defaultCooldown": 300,
    "vswitchIds": ["vsw-prod-a", "vsw-prod-b"],
    "loadBalancerIds": ["slb-prod-001"]
  },
  "scalingRules": [
    {
      "name": "cpu-scale-up",
      "type": "TargetTracking",
      "targetValue": 60,
      "metricName": "CPUUtilization",
      "adjustmentType": "ChangeInCapacity",
      "adjustmentValue": 2
    },
    {
      "name": "cpu-scale-down",
      "type": "TargetTracking",
      "targetValue": 30,
      "metricName": "CPUUtilization",
      "adjustmentType": "ChangeInCapacity",
      "adjustmentValue": -1
    }
  ]
}
```

---

## 6. 存储设计

### 6.1 OSS 配置

| 配置项 | 值 |
|--------|-----|
| **Bucket 名称** | coka-prod-shanghai |
| **存储类型** | 标准存储 (Standard) |
| **区域** | cn-shanghai |
| **读写权限** | 私有 (通过 CDN 访问) |
| **版本控制** | 启用 |
| **生命周期** | 30 天转低频，365 天转归档 |
| **跨区域复制** | 华北 2 (北京) 容灾 |

### 6.2 CDN 配置

| 配置项 | 值 |
|--------|-----|
| **加速域名** | static.coka.com |
| **源站** | coka-prod-shanghai.oss-cn-shanghai.aliyuncs.com |
| **缓存策略** | 图片 30 天，CSS/JS 7 天，HTML 不缓存 |
| **HTTPS** | 启用 (免费 DV 证书) |
| **智能压缩** | 启用 (Gzip/Brotli) |
| **边缘脚本** | 启用 (鉴权访问) |

---

## 7. 数据库设计

### 7.1 RDS MySQL 配置

| 环境 | 规格 | 存储 | 架构 | 单价 (元/月) |
|------|------|------|------|--------------|
| **DEV** | mysql.n2.small.2c (2vCPU 4GB) | 100GB ESSD | 基础版 | 400 |
| **TEST** | mysql.n2.medium.2c (4vCPU 8GB) | 200GB ESSD | 高可用版 | 800 |
| **PROD** | mysql.n2.large.4c (8vCPU 16GB) | 500GB ESSD | 高可用版 + 只读 | 2400 |

### 7.2 数据库表结构

```sql
-- 用户表
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    avatar_url VARCHAR(255),
    status TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 商品表
CREATE TABLE products (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category_id BIGINT,
    brand_id BIGINT,
    price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2),
    stock INT DEFAULT 0,
    images JSON,
    status TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category_id),
    INDEX idx_status (status),
    FULLTEXT idx_name_desc (name, description)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 订单表
CREATE TABLE orders (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_no VARCHAR(50) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    pay_amount DECIMAL(10,2),
    status TINYINT DEFAULT 0,
    payment_method TINYINT,
    payment_time TIMESTAMP,
    delivery_address JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 订单明细表
CREATE TABLE order_items (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    product_name VARCHAR(200),
    product_image VARCHAR(255),
    price DECIMAL(10,2) NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 7.3 Redis 配置

| 环境 | 规格 | 架构 | 用途 | 单价 (元/月) |
|------|------|------|------|--------------|
| **DEV** | 1GB | 主从版 | 缓存/会话 | 200 |
| **TEST** | 2GB | 主从版 | 缓存/会话 | 400 |
| **PROD** | 8GB | 集群版 (3 节点) | 缓存/会话/队列 | 1200 |

**Key 设计规范:**
```
user:session:{userId}          # 用户会话 (TTL: 7d)
product:detail:{productId}     # 商品详情 (TTL: 1h)
product:stock:{productId}      # 商品库存 (TTL: -)
cart:{userId}                  # 购物车 (TTL: 30d)
order:no:{orderNo}             # 订单号生成 (自增)
seckill:stock:{productId}      # 秒杀库存 (TTL: 活动结束)
```

---

## 8. 安全设计

### 8.1 安全架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        安全防护体系                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  网络层安全                                              │   │
│  │  - DDoS 基础防护 (5Gbps)                                  │   │
│  │  - Web 应用防火墙 (WAF)                                   │   │
│  │  - 安全组 (最小权限原则)                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  应用层安全                                              │   │
│  │  - HTTPS 强制 (TLS 1.3)                                  │   │
│  │  - JWT 鉴权                                             │   │
│  │  - API 限流 (SLB + 应用层)                               │   │
│  │  - SQL 注入防护 (参数化查询)                             │   │
│  │  - XSS 防护 (内容过滤)                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  数据安全                                                │   │
│  │  - 敏感数据加密存储 (AES-256)                            │   │
│  │  - 传输加密 (TLS)                                        │   │
│  │  - 数据库审计 (RDS 审计日志)                              │   │
│  │  - 数据脱敏 (日志/测试环境)                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  访问控制                                                │   │
│  │  - RAM 角色 (最小权限)                                   │   │
│  │  - MFA 多因素认证                                        │   │
│  │  - 操作审计 (ActionTrail)                                │   │
│  │  - 堡垒机 (运维审计)                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 WAF 规则

| 规则类型 | 动作 | 说明 |
|----------|------|------|
| SQL 注入 | 拦截 | 检测常见 SQL 注入 payload |
| XSS 攻击 | 拦截 | 检测脚本注入 |
| Webshell | 拦截 | 检测上传后门 |
| CC 攻击 | 限流 | 单 IP 100 次/分钟 |
| 恶意爬虫 | 拦截 | 检测常见爬虫 UA |
| 敏感路径 | 拦截 | 阻止访问/.git/.env 等 |

---

## 9. 监控设计

### 9.1 监控架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        监控告警体系                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ CloudMonitor│  │     SLS     │  │     ARMS    │             │
│  │  基础监控   │  │   日志服务  │  │  应用监控   │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┴────────────────┘                     │
│                          │                                      │
│                  ┌───────┴───────┐                              │
│                  │  统一告警中心  │                              │
│                  │  (Alert Center)│                             │
│                  └───────┬───────┘                              │
│                          │                                      │
│         ┌────────────────┼────────────────┐                     │
│         │                │                │                     │
│         ▼                ▼                ▼                     │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                │
│   │ 短信/电话 │    │  钉钉群  │    │  邮件    │                │
│   │  (P0/P1) │    │  (P2/P3) │    │  (日报)  │                │
│   └──────────┘    └──────────┘    └──────────┘                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 监控指标

#### 基础设施监控

| 指标 | 采集频率 | 告警阈值 | 告警级别 |
|------|----------|----------|----------|
| CPU 使用率 | 1 分钟 | > 80% 持续 5 分钟 | P2 |
| 内存使用率 | 1 分钟 | > 85% 持续 5 分钟 | P2 |
| 磁盘使用率 | 5 分钟 | > 85% | P2 |
| 磁盘 IO | 1 分钟 | > 80% 持续 10 分钟 | P3 |
| 网络流入带宽 | 1 分钟 | > 80% 峰值 | P3 |
| 网络流出带宽 | 1 分钟 | > 80% 峰值 | P3 |
| TCP 连接数 | 1 分钟 | > 10000 | P3 |

#### 应用监控

| 指标 | 采集频率 | 告警阈值 | 告警级别 |
|------|----------|----------|----------|
| HTTP QPS | 1 分钟 | > 5000 | P2 |
| HTTP 响应时间 | 1 分钟 | P99 > 500ms | P2 |
| HTTP 错误率 | 1 分钟 | > 1% | P1 |
| JVM 堆内存 | 1 分钟 | > 85% | P2 |
| GC 时间 | 1 分钟 | > 200ms | P3 |
| 线程池活跃数 | 1 分钟 | > 80% | P2 |

#### 数据库监控

| 指标 | 采集频率 | 告警阈值 | 告警级别 |
|------|----------|----------|----------|
| CPU 使用率 | 1 分钟 | > 80% | P2 |
| 连接数使用率 | 1 分钟 | > 80% | P2 |
| IOPS 使用率 | 1 分钟 | > 80% | P2 |
| 主从延迟 | 1 分钟 | > 60 秒 | P1 |
| 慢查询数 | 5 分钟 | > 100/分钟 | P3 |
| 磁盘使用率 | 5 分钟 | > 85% | P1 |

#### 业务监控

| 指标 | 采集频率 | 告警阈值 | 告警级别 |
|------|----------|----------|----------|
| 订单创建量 | 5 分钟 | 同比下跌 > 50% | P1 |
| 支付成功率 | 5 分钟 | < 95% | P1 |
| 用户登录数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 商品搜索失败率 | 5 分钟 | > 5% | P2 |
| 库存扣减失败 | 实时 | > 10 次/分钟 | P1 |

### 9.3 告警级别定义

| 级别 | 名称 | 响应时间 | 通知方式 | 示例 |
|------|------|----------|----------|------|
| **P0** | 致命 | 5 分钟 | 电话 + 短信 + 钉钉 | 全站不可用 |
| **P1** | 严重 | 15 分钟 | 短信 + 钉钉 | 核心功能故障 |
| **P2** | 警告 | 1 小时 | 钉钉 | 性能下降 |
| **P3** | 提示 | 4 小时 | 钉钉 | 非关键告警 |

### 9.4 日志采集

```yaml
# SLS 采集配置
logstore:
  - name: app-access-log
    type: access_log
    retention: 30d
    index: enabled
    
  - name: app-error-log
    type: error_log
    retention: 90d
    index: enabled
    
  - name: app-slow-query
    type: slow_query
    retention: 90d
    index: enabled

dashboard:
  - name: 应用监控大盘
    charts:
      - QPS 趋势
      - 响应时间分布
      - 错误率趋势
      - Top 10 慢接口
      
  - name: 业务监控大盘
    charts:
      - 订单量趋势
      - 支付成功率
      - 用户活跃趋势
      - 商品销量排行
```

---

## 10. CI/CD 方案

### 10.1 流水线设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      CI/CD 流水线                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  开发分支 (feature/*)                                           │
│  │                                                              │
│  ▼                                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  GitHub Actions                                          │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐         │  │
│  │  │  Code  │  │  Unit  │  │  Build │  │ Docker │         │  │
│  │  │ Lint   │─▶│  Test  │─▶│  App   │─▶│  Image │         │  │
│  │  └────────┘  └────────┘  └────────┘  └────────┘         │  │
│  └──────────────────────────────────────────────────────────┘  │
│  │                                                              │
│  ▼ (PR Merge)                                                   │
│  开发分支 (develop)                                             │
│  │                                                              │
│  ▼ (自动部署)                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  阿里云效 - DEV 环境                                         │  │
│  │  - 更新 ECS 容器                                           │  │
│  │  - 执行数据库迁移                                          │  │
│  │  - 健康检查                                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  │                                                              │
│  ▼ (Release Tag)                                                │
│  发布分支 (release/*)                                           │
│  │                                                              │
│  ▼ (手动审批)                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  阿里云效 - TEST 环境                                        │  │
│  │  - 集成测试                                                │  │
│  │  - 性能测试                                                │  │
│  │  - 安全扫描                                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  │                                                              │
│  ▼ (手动审批)                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  阿里云效 - PROD 环境 (蓝绿部署)                            │  │
│  │  - 部署到绿色环境                                          │  │
│  │  - 流量切换 (10% → 50% → 100%)                            │  │
│  │  - 监控验证                                                │  │
│  │  - 回滚预案                                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 GitHub Actions 配置

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [feature/*, develop, release/*]
  pull_request:
    branches: [develop, main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test
      - uses: codecov/codecov-action@v3

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: registry.cn-shanghai.aliyuncs.com
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: registry.cn-shanghai.aliyuncs.com/coka/app:${{ github.sha }}

  deploy-dev:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v4
      - uses: aliyun/aliyun-cli-github-action@master
        with:
          configure: |
            ${{ secrets.ALIYUN_ACCESS_KEY_ID }}
            ${{ secrets.ALIYUN_ACCESS_KEY_SECRET }}
            cn-shanghai
      - run: |
          aliyun cs POST clusters/${{ secrets.ACK_DEV_CLUSTER_ID }}/apps \
            --header Content-Type=application/json \
            --body "{\"name\":\"coka-app\",\"template_id\":\"${{ github.sha }}\"}"
```

### 10.3 部署策略

| 环境 | 部署策略 | 回滚策略 | 审批 |
|------|----------|----------|------|
| **DEV** | 滚动更新 | 自动回滚 | 自动 |
| **TEST** | 滚动更新 | 手动回滚 | 自动 |
| **PROD** | 蓝绿部署 | 一键回滚 | 手动 (2 人) |

---

## 11. 成本估算

### 11.1 月度成本明细

| 资源 | 规格 | 数量 | 单价 (元/月) | 小计 (元/月) |
|------|------|------|--------------|--------------|
| **计算资源** | | | | |
| ECS (DEV) | ecs.g7.large | 2 | 280 | 560 |
| ECS (TEST) | ecs.g7.xlarge | 4 | 560 | 2,240 |
| ECS (PROD) | ecs.g7.2xlarge | 8 (平均) | 1,120 | 8,960 |
| **数据库** | | | | |
| RDS (DEV) | mysql.n2.small.2c | 1 | 400 | 400 |
| RDS (TEST) | mysql.n2.medium.2c | 1 | 800 | 800 |
| RDS (PROD) | mysql.n2.large.4c | 2 (主 + 备) | 1,200 | 2,400 |
| **缓存** | | | | |
| Redis (DEV) | 1GB 主从 | 1 | 200 | 200 |
| Redis (TEST) | 2GB 主从 | 1 | 400 | 400 |
| Redis (PROD) | 8GB 集群 | 1 | 1,200 | 1,200 |
| **网络** | | | | |
| SLB (TEST) | slb.s1.small | 1 | 50 | 50 |
| SLB (PROD) | slb.s2.large | 1 | 300 | 300 |
| CDN | 1TB 流量 | - | 150 | 150 |
| EIP | 按量付费 | 2 | 50 | 100 |
| **存储** | | | | |
| OSS | 100GB 标准 | - | 20 | 20 |
| 快照备份 | 200GB | - | 30 | 30 |
| **安全** | | | | |
| WAF | 标准版 | 1 | 990 | 990 |
| SSL 证书 | 免费 DV | 1 | 0 | 0 |
| **监控** | | | | |
| CloudMonitor | 企业版 | - | 200 | 200 |
| SLS | 10GB/天 | - | 300 | 300 |
| **合计** | | | | **19,300** |

### 11.2 成本优化建议

1. **使用抢占式实例:** ECS 成本可降低 50-70% (适合无状态应用)
2. **预留实例券:** 1 年期预付可节省 30-40%
3. **OSS 生命周期:** 30 天转低频存储，节省 50%
4. **CDN 流量包:** 预付费流量包比按量节省 20%
5. **弹性伸缩:** 夜间自动缩容，节省 30% 计算成本

**优化后预估:** 12,000-14,000 元/月

---

## 12. 附录

### 12.1 Terraform 模块清单

```
terraform/
├── modules/
│   ├── vpc/           # VPC 网络模块
│   ├── ecs/           # ECS 计算模块
│   ├── rds/           # RDS 数据库模块
│   ├── redis/         # Redis 缓存模块
│   ├── slb/           # 负载均衡模块
│   ├── oss/           # 对象存储模块
│   ├── cdn/           # CDN 加速模块
│   ├── waf/           # Web 防火墙模块
│   └── monitor/       # 监控告警模块
├── environments/
│   ├── dev/           # 开发环境配置
│   ├── test/          # 测试环境配置
│   └── prod/          # 生产环境配置
└── scripts/
    ├── init.sh        # 初始化脚本
    └── cleanup.sh     # 清理脚本
```

### 12.2 参考文档

- [阿里云最佳实践](https://help.aliyun.com/best-practices/)
- [Terraform 阿里云 Provider](https://registry.terraform.io/providers/aliyun/aliyun/latest/docs)
- [Kubernetes 阿里云 ACK](https://www.alibabacloud.com/help/cs)
- [阿里云效 CI/CD](https://www.aliyun.com/product/flow)

---

**文档版本历史:**

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0.0 | 2026-03-17 | Infrastructure Team | 初始版本 |
