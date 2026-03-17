# Coka 电商平台 - 监控设计文档

**版本:** 1.0.0  
**创建日期:** 2026-03-17  
**状态:** Draft

---

## 📑 目录

1. [监控架构](#1-监控架构)
2. [监控指标](#2-监控指标)
3. [日志采集](#3-日志采集)
4. [告警规则](#4-告警规则)
5. [监控大盘](#5-监控大盘)
6. [告警通知](#6-告警通知)
7. [应急预案](#7-应急预案)

---

## 1. 监控架构

### 1.1 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        监控数据源                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   ECS    │  │   RDS    │  │  Redis   │  │   SLB    │       │
│  │  (Node)  │  │ (MySQL)  │  │ Cluster  │  │          │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │             │             │              │
│       └─────────────┴─────────────┴─────────────┘              │
│                         │                                       │
│                         ▼                                       │
│              ┌─────────────────────┐                           │
│              │   CloudMonitor      │                           │
│              │   (基础监控指标)     │                           │
│              └──────────┬──────────┘                           │
│                         │                                       │
└─────────────────────────┼───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        数据处理层                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │   SLS 日志服务   │         │     ARMS         │             │
│  │  (日志采集分析)  │         │  (应用性能监控)  │             │
│  └────────┬─────────┘         └────────┬─────────┘             │
│           │                            │                       │
│           └──────────────┬─────────────┘                       │
│                          │                                     │
│                          ▼                                     │
│              ┌─────────────────────┐                          │
│              │   统一告警中心      │                          │
│              │   (Alert Center)    │                          │
│              └──────────┬──────────┘                          │
│                         │                                      │
└─────────────────────────┼───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        通知渠道                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   短信   │  │   电话   │  │  钉钉群  │  │   邮件   │       │
│  │  (P0/P1) │  │  (P0)    │  │ (P2/P3)  │  │  (日报)  │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 监控层级

| 层级 | 监控工具 | 采集频率 | 保留时间 |
|------|----------|----------|----------|
| **基础设施** | CloudMonitor | 1 分钟 | 31 天 |
| **应用性能** | ARMS | 1 分钟 | 7 天 |
| **日志** | SLS | 实时 | 30-90 天 |
| **业务** | 自定义监控 | 1-5 分钟 | 90 天 |
| **前端** | ARMS Browser | 实时 | 7 天 |

---

## 2. 监控指标

### 2.1 基础设施监控

#### ECS 云服务器

| 指标名称 | 指标代码 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|----------|
| CPU 使用率 | `CPUUtilization` | 1 分钟 | > 80% (5 分钟) | P2 |
| 内存使用率 | `MemoryUtilization` | 1 分钟 | > 85% (5 分钟) | P2 |
| 磁盘使用率 | `DiskUtilization` | 5 分钟 | > 85% | P2 |
| 磁盘读 BPS | `DiskReadBPS` | 1 分钟 | > 80% | P3 |
| 磁盘写 BPS | `DiskWriteBPS` | 1 分钟 | > 80% | P3 |
| 网络流入带宽 | `InternetInRate` | 1 分钟 | > 80% | P3 |
| 网络流出带宽 | `InternetOutRate` | 1 分钟 | > 80% | P3 |
| TCP 连接数 | `TCPConnection` | 1 分钟 | > 10000 | P3 |
| 进程数 | `ProcessCount` | 5 分钟 | > 500 | P3 |
| 系统负载 | `LoadAverage` | 1 分钟 | > CPU 核数*2 | P2 |

#### RDS MySQL

| 指标名称 | 指标代码 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|----------|
| CPU 使用率 | `CpuUsage` | 1 分钟 | > 80% (5 分钟) | P2 |
| 内存使用率 | `MemoryUsage` | 1 分钟 | > 85% (5 分钟) | P2 |
| 磁盘使用率 | `DiskUsage` | 5 分钟 | > 85% | P1 |
| IOPS 使用率 | `IOPSUsage` | 1 分钟 | > 80% | P2 |
| 连接数使用率 | `ConnectionUsage` | 1 分钟 | > 80% | P2 |
| 主从延迟 | `ReplicationLag` | 1 分钟 | > 60 秒 | P1 |
| 慢查询数 | `SlowQueries` | 5 分钟 | > 100/分钟 | P3 |
| 活跃会话数 | `ActiveSessions` | 1 分钟 | > 100 | P2 |
| 缓冲池命中率 | `BufferPoolHitRate` | 5 分钟 | < 90% | P3 |
| 每秒 SQL 执行数 | `SQLServerQPS` | 1 分钟 | > 5000 | P2 |

#### Redis 集群

| 指标名称 | 指标代码 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|----------|
| CPU 使用率 | `CpuUsage` | 1 分钟 | > 80% | P2 |
| 内存使用率 | `MemoryUsage` | 1 分钟 | > 80% | P2 |
| 连接数使用率 | `ConnectionUsage` | 1 分钟 | > 80% | P2 |
| 缓存命中率 | `CacheHitRate` | 5 分钟 | < 80% | P2 |
| 每秒请求数 | `QPS` | 1 分钟 | > 10000 | P2 |
|  eviction 键数 | `EvictedKeys` | 1 分钟 | > 100/分钟 | P2 |
| 过期键数 | `ExpiredKeys` | 5 分钟 | > 1000/分钟 | P3 |
| 网络流入带宽 | `InternetInRate` | 1 分钟 | > 80% | P3 |
| 网络流出带宽 | `InternetOutRate` | 1 分钟 | > 80% | P3 |

#### SLB 负载均衡

| 指标名称 | 指标代码 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|----------|
| 活跃连接数 | `ActiveConnection` | 1 分钟 | > 50000 | P2 |
| 新建连接数 | `NewConnection` | 1 分钟 | > 5000/秒 | P2 |
| 非活跃连接数 | `InactiveConnection` | 1 分钟 | > 100000 | P3 |
| 流入带宽 | `InternetInRate` | 1 分钟 | > 80% | P3 |
| 流出带宽 | `InternetOutRate` | 1 分钟 | > 80% | P3 |
| 每秒请求数 | `QPS` | 1 分钟 | > 10000 | P2 |
| 后端健康主机数 | `HealthyHostCount` | 1 分钟 | < 最小实例数 | P1 |
| 后端异常主机数 | `UnhealthyHostCount` | 1 分钟 | > 0 | P2 |

---

### 2.2 应用性能监控 (ARMS)

#### JVM 监控

| 指标名称 | 告警阈值 | 告警级别 |
|----------|----------|----------|
| 堆内存使用率 | > 85% | P2 |
| 非堆内存使用率 | > 85% | P2 |
| Full GC 次数 | > 10 次/分钟 | P2 |
| Full GC 时间 | > 500ms | P2 |
| Young GC 次数 | > 100 次/分钟 | P3 |
| Young GC 时间 | > 100ms | P3 |
| 线程数 | > 500 | P2 |
| 死锁线程数 | > 0 | P1 |

#### HTTP 请求监控

| 指标名称 | 告警阈值 | 告警级别 |
|----------|----------|----------|
| QPS | > 5000 | P2 |
| 响应时间 (P50) | > 200ms | P3 |
| 响应时间 (P90) | > 400ms | P2 |
| 响应时间 (P99) | > 500ms | P2 |
| 错误率 (5xx) | > 1% | P1 |
| 错误率 (4xx) | > 5% | P3 |
| 慢请求数 | > 100/分钟 | P3 |

#### 数据库调用监控

| 指标名称 | 告警阈值 | 告警级别 |
|----------|----------|----------|
| SQL 执行时间 (P99) | > 1000ms | P2 |
| 慢 SQL 数 | > 50/分钟 | P2 |
| 连接池使用率 | > 80% | P2 |
| 连接等待时间 | > 500ms | P2 |
| 事务回滚率 | > 5% | P2 |

#### 缓存调用监控

| 指标名称 | 告警阈值 | 告警级别 |
|----------|----------|----------|
| Redis 响应时间 (P99) | > 50ms | P2 |
| 缓存命中率 | < 80% | P2 |
| 缓存穿透数 | > 1000/分钟 | P2 |
| 缓存雪崩数 | > 100/分钟 | P1 |

---

### 2.3 业务监控

#### 订单相关

| 指标名称 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|
| 订单创建量 | 5 分钟 | 同比下跌 > 50% | P1 |
| 订单支付量 | 5 分钟 | 同比下跌 > 50% | P1 |
| 支付成功率 | 5 分钟 | < 95% | P1 |
| 平均支付时长 | 5 分钟 | > 5 分钟 | P2 |
| 订单取消率 | 5 分钟 | > 10% | P2 |
| 退款申请量 | 5 分钟 | 同比上涨 > 100% | P2 |

#### 用户相关

| 指标名称 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|
| 新增用户数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 活跃用户数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 用户登录数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 登录失败率 | 5 分钟 | > 10% | P2 |
| 短信验证码发送量 | 5 分钟 | 同比上涨 > 200% | P2 |

#### 商品相关

| 指标名称 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|
| 商品搜索次数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 商品搜索失败率 | 5 分钟 | > 5% | P2 |
| 商品详情页 PV | 5 分钟 | 同比下跌 > 30% | P2 |
| 加入购物车次数 | 5 分钟 | 同比下跌 > 30% | P2 |
| 库存扣减失败数 | 实时 | > 10 次/分钟 | P1 |

#### 促销相关

| 指标名称 | 采集频率 | 告警阈值 | 告警级别 |
|----------|----------|----------|----------|
| 秒杀开始 QPS | 实时 | > 10000 | P1 |
| 秒杀库存剩余 | 实时 | = 0 | P3 |
| 优惠券领取量 | 5 分钟 | > 总量 90% | P2 |
| 优惠券使用率 | 活动结束后 | < 30% | P3 |

---

## 3. 日志采集

### 3.1 日志分类

| 日志类型 | 采集方式 | 保留时间 | 说明 |
|----------|----------|----------|------|
| 应用访问日志 | Logtail | 30 天 | Nginx/应用访问日志 |
| 应用错误日志 | Logtail | 90 天 | 应用异常堆栈 |
| 慢查询日志 | RDS 审计 | 90 天 | 慢 SQL 日志 |
| 系统日志 | Logtail | 30 天 | /var/log/messages |
| 安全日志 | Logtail | 180 天 | 登录/操作审计 |
| 业务日志 | SDK | 90 天 | 订单/支付等业务日志 |

### 3.2 日志格式规范

#### 应用访问日志

```json
{
  "timestamp": "2026-03-17T10:15:30.123Z",
  "level": "INFO",
  "service": "coka-api",
  "trace_id": "0a1b2c3d4e5f6789",
  "span_id": "1234567890abcdef",
  "method": "GET",
  "path": "/api/v1/products/12345",
  "status": 200,
  "duration_ms": 45,
  "client_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "user_id": "u_123456",
  "request_id": "req_abcdef123456"
}
```

#### 应用错误日志

```json
{
  "timestamp": "2026-03-17T10:15:30.123Z",
  "level": "ERROR",
  "service": "coka-api",
  "trace_id": "0a1b2c3d4e5f6789",
  "error_code": "ORDER_CREATE_FAILED",
  "error_message": "库存不足",
  "error_stack": "Error: 库存不足\n  at OrderService.create...",
  "user_id": "u_123456",
  "request_params": {
    "product_id": "12345",
    "quantity": 10
  }
}
```

#### 业务日志

```json
{
  "timestamp": "2026-03-17T10:15:30.123Z",
  "event_type": "ORDER_CREATED",
  "order_id": "ORD20260317101530",
  "user_id": "u_123456",
  "amount": 299.00,
  "items": [
    {"product_id": "12345", "quantity": 2, "price": 149.50}
  ],
  "payment_method": "alipay",
  "status": "PENDING_PAYMENT"
}
```

### 3.3 日志分析查询

#### Top 10 慢接口

```sql
* | SELECT path, COUNT(*) as count, 
         AVG(duration_ms) as avg_duration,
         MAX(duration_ms) as max_duration
  WHERE status >= 200 
  GROUP BY path 
  ORDER BY avg_duration DESC 
  LIMIT 10
```

#### 错误率趋势

```sql
* | SELECT DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i') as time,
         COUNT(*) as total,
         SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) as errors,
         ROUND(SUM(CASE WHEN status >= 500 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as error_rate
  GROUP BY time
  ORDER BY time
  LIMIT 100
```

#### 用户行为分析

```sql
* | SELECT user_id, COUNT(*) as pv, 
         COUNT(DISTINCT path) as uv,
         AVG(duration_ms) as avg_duration
  WHERE user_id IS NOT NULL
  GROUP BY user_id
  ORDER BY pv DESC
  LIMIT 100
```

---

## 4. 告警规则

### 4.1 告警级别定义

| 级别 | 名称 | 响应时间 | 通知方式 | 升级策略 | 示例 |
|------|------|----------|----------|----------|------|
| **P0** | 致命 | 5 分钟 | 电话 + 短信 + 钉钉 | 15 分钟未响应→CTO | 全站不可用、数据丢失 |
| **P1** | 严重 | 15 分钟 | 短信 + 钉钉 | 30 分钟未响应→技术总监 | 核心功能故障、支付失败 |
| **P2** | 警告 | 1 小时 | 钉钉 | 2 小时未响应→团队 Leader | 性能下降、非核心功能故障 |
| **P3** | 提示 | 4 小时 | 钉钉 | 24 小时未处理→自动关闭 | 非关键告警、优化建议 |

### 4.2 核心告警规则

#### 基础设施告警

```yaml
alerts:
  - name: ecs-cpu-high
    metric: CPUUtilization
    threshold: 80
    comparison: GreaterThan
    period: 300  # 5 minutes
    evaluation_count: 3  # 3 consecutive times
    level: P2
    notification:
      - dingtalk
      - sms
    
  - name: rds-replication-lag
    metric: ReplicationLag
    threshold: 60  # seconds
    comparison: GreaterThan
    period: 60
    evaluation_count: 2
    level: P1
    notification:
      - dingtalk
      - sms
      - phone
    
  - name: redis-memory-high
    metric: MemoryUsage
    threshold: 80
    comparison: GreaterThan
    period: 300
    evaluation_count: 3
    level: P2
    notification:
      - dingtalk
```

#### 应用告警

```yaml
alerts:
  - name: http-error-rate-high
    metric: HttpCode5xx
    threshold: 1  # percent
    comparison: GreaterThan
    period: 300
    evaluation_count: 2
    level: P1
    notification:
      - dingtalk
      - sms
  
  - name: api-slow-response
    metric: ResponseTimeP99
    threshold: 500  # ms
    comparison: GreaterThan
    period: 300
    evaluation_count: 3
    level: P2
    notification:
      - dingtalk
  
  - name: jvm-full-gc-frequent
    metric: JvmFullGcCount
    threshold: 10  # times per minute
    comparison: GreaterThan
    period: 60
    evaluation_count: 2
    level: P2
    notification:
      - dingtalk
```

#### 业务告警

```yaml
alerts:
  - name: order-drop
    metric: OrderCreatedCount
    threshold: 50  # percent drop
    comparison: LessThan
    comparison_base:同比
    period: 300
    evaluation_count: 2
    level: P1
    notification:
      - dingtalk
      - sms
  
  - name: payment-failure-rate
    metric: PaymentFailureRate
    threshold: 5  # percent
    comparison: GreaterThan
    period: 300
    evaluation_count: 2
    level: P1
    notification:
      - dingtalk
      - sms
  
  - name: inventory-deduction-failure
    metric: InventoryDeductionFailureCount
    threshold: 10  # times per minute
    comparison: GreaterThan
    period: 60
    evaluation_count: 1
    level: P1
    notification:
      - dingtalk
      - sms
      - phone
```

### 4.3 告警静默与抑制

```yaml
silence_rules:
  - name: maintenance-window
    matchers:
      - alertname=~".*"
    starts_at: "2026-03-20T02:00:00+08:00"
    ends_at: "2026-03-20T04:00:00+08:00"
    comment: "凌晨维护窗口"

inhibit_rules:
  - source_match:
      alertname: "ecs-down"
    target_match:
      alertname: "api-slow-response"
    comment: "ECS 宕机时抑制 API 慢响应告警"
  
  - source_match:
      alertname: "rds-down"
    target_match:
      alertname: "order-drop"
    comment: "数据库宕机时抑制订单下降告警"
```

---

## 5. 监控大盘

### 5.1 基础设施大盘

```
┌─────────────────────────────────────────────────────────────────┐
│                    基础设施监控大盘                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  ECS 总览    │  │  RDS 总览    │  │ Redis 总览   │             │
│  │             │  │             │  │             │             │
│  │ CPU: 45%    │  │ CPU: 32%    │  │ CPU: 28%    │             │
│  │ MEM: 62%    │  │ MEM: 54%    │  │ MEM: 45%    │             │
│  │ DISK: 35%   │  │ DISK: 42%   │  │ CONN: 1234  │             │
│  │ INST: 8/20  │  │ CONN: 234   │  │ QPS: 5678   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CPU 使用率趋势 (24h)                        │   │
│  │  ─ ECS 平均  ─ RDS  ─ Redis                             │   │
│  │  ╭─╮  ╭─╮                                                │   │
│  │ ╱   ╲╱   ╲╭─╮                                             │   │
│  │╱     ╲   ╱╰╯ ╲╭─╮                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              网络带宽趋势 (24h)                          │   │
│  │  ─ 流入  ─ 流出                                          │   │
│  │  ╭──╮  ╭──╮                                             │   │
│  │ ╱  ╲╱  ╲╱  ╲╭──╮                                         │   │
│  │╱    ╲  ╱    ╲╰╯ ╲                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 应用性能大盘

```
┌─────────────────────────────────────────────────────────────────┐
│                    应用性能监控大盘                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    QPS      │  │  响应时间   │  │   错误率    │             │
│  │             │  │             │  │             │             │
│  │ 当前：2345  │  │ P50: 45ms   │  │ 5xx: 0.12%  │             │
│  │ 峰值：5678  │  │ P90: 123ms  │  │ 4xx: 2.34%  │             │
│  │ 平均：1890  │  │ P99: 234ms  │  │ 总计：123   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Top 10 慢接口 (P99)                         │   │
│  │                                                         │   │
│  │  1. POST /api/v1/orders          456ms  ▲ 12%           │   │
│  │  2. GET  /api/v1/products        234ms  ▼ 5%            │   │
│  │  3. GET  /api/v1/cart            189ms  ▲ 3%            │   │
│  │  4. POST /api/v1/payments        167ms  ▼ 8%            │   │
│  │  5. GET  /api/v1/user/orders     145ms  ▲ 7%            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              JVM 监控                                    │   │
│  │                                                         │   │
│  │  堆内存：4.2GB / 8GB (52%)                              │   │
│  │  非堆内存：256MB / 512MB (50%)                          │   │
│  │  GC: Young 123 次/min, Full 2 次/min                    │   │
│  │  线程：234 活跃 / 500 最大                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 业务监控大盘

```
┌─────────────────────────────────────────────────────────────────┐
│                    业务监控大盘                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  今日订单   │  │  今日 GMV   │  │  支付成功率 │             │
│  │             │  │             │  │             │             │
│  │ 12,345 单   │  │ ¥1,234,567  │  │   98.5%     │             │
│  │ ▲ 12% 同比  │  │ ▲ 15% 同比  │  │ ▼ 0.3% 环比 │             │
│  │ 目标：10000 │  │ 目标：100 万 │  │ 目标：98%   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              订单量趋势 (24h)                            │   │
│  │  ─ 实际  ─ 目标  ─ 昨日同期                             │   │
│  │      ╭───╮╭───╮                                          │   │
│  │  ╭───╯   ╰╯   ╰───╮                                     │   │
│  │ ╱                  ╲╭───╮                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              商品销量 Top 10                             │   │
│  │                                                         │   │
│  │  1. iPhone 15 Pro Max          234 件  ¥2,345,678       │   │
│  │  2. MacBook Pro 14\"           189 件  ¥1,890,234       │   │
│  │  3. AirPods Pro 2              456 件  ¥890,123         │   │
│  │  4. iPad Air 5                 123 件  ¥567,890         │   │
│  │  5. Apple Watch Ultra          234 件  ¥456,789         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. 告警通知

### 6.1 通知渠道配置

| 渠道 | 适用级别 | 响应时间 | 配置方式 |
|------|----------|----------|----------|
| **电话** | P0 | 即时 | 云监控电话告警 |
| **短信** | P0/P1 | < 1 分钟 | 云监控短信告警 |
| **钉钉** | P1/P2/P3 | < 5 分钟 | 钉钉机器人 Webhook |
| **邮件** | P2/P3/日报 | < 15 分钟 | SMTP 邮件服务器 |
| **企业微信** | P2/P3 | < 5 分钟 | 企业微信机器人 |

### 6.2 钉钉通知模板

#### P0 告警

```markdown
## 🔴 【P0 致命告警】Coka 生产环境

**告警名称:** {{ alertName }}
**告警时间:** {{ alarmTimestamp }}
**告警级别:** P0 - 致命
**影响范围:** {{ scope }}

**告警内容:**
{{ alarmDescription }}

**当前值:** {{ currentValue }}
**阈值:** {{ threshold }}

**处理建议:**
{{ suggestion }}

**相关链接:**
- [监控大盘](https://arms.console.aliyun.com/dashboard)
- [日志查询](https://sls.console.aliyun.com)
- [告警历史](https://cms.console.aliyun.com/alarm)

**值班人员:** {{ onCallPerson }}
**升级策略:** 15 分钟未响应 → CTO

@所有人 请立即处理！
```

#### P1 告警

```markdown
## 🟠 【P1 严重告警】Coka 生产环境

**告警名称:** {{ alertName }}
**告警时间:** {{ alarmTimestamp }}
**告警级别:** P1 - 严重

**告警内容:**
{{ alarmDescription }}

**当前值:** {{ currentValue }}
**阈值:** {{ threshold }}

**处理建议:**
{{ suggestion }}

**相关链接:**
- [监控大盘](https://arms.console.aliyun.com/dashboard)
- [日志查询](https://sls.console.aliyun.com)

**值班人员:** {{ onCallPerson }}
**升级策略:** 30 分钟未响应 → 技术总监

@相关同事 请尽快处理！
```

### 6.3 值班排班

```yaml
oncall_schedule:
  timezone: Asia/Shanghai
  
  rotations:
    - name: 一线值班
      type: weekly
      start_date: 2026-03-17
      handover_time: "09:00"
      members:
        - user1@coka.com
        - user2@coka.com
        - user3@coka.com
        - user4@coka.com
    
    - name: 二线支持
      type: weekly
      start_date: 2026-03-17
      handover_time: "09:00"
      members:
        - tech_lead1@coka.com
        - tech_lead2@coka.com
    
    - name: 管理升级
      type: weekly
      members:
        - cto@coka.com
        - vp_engineering@coka.com
```

---

## 7. 应急预案

### 7.1 故障分级

| 级别 | 名称 | 影响范围 | 响应团队 | 通报频率 |
|------|------|----------|----------|----------|
| **P0** | 重大故障 | 全站不可用 > 5 分钟 | 全员 + 管理层 | 每 15 分钟 |
| **P1** | 严重故障 | 核心功能不可用 | 技术团队 + Leader | 每 30 分钟 |
| **P2** | 一般故障 | 非核心功能不可用 | 值班团队 | 每小时 |
| **P3** | 轻微故障 | 性能下降/部分用户 | 值班人员 | 每 4 小时 |

### 7.2 应急响应流程

```
┌─────────────────────────────────────────────────────────────────┐
│                      应急响应流程                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 故障发现                                                    │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 监控告警/用户反馈 │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  2. 初步评估 (5 分钟内)                                          │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 确定故障级别     │                                           │
│  │ 通知相关人员     │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  3. 紧急止损 (15 分钟内)                                         │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 回滚/降级/熔断   │                                           │
│  │ 优先恢复服务     │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  4. 问题定位 (30 分钟内)                                         │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 日志分析        │                                           │
│  │ 链路追踪        │                                           │
│  │ 指标对比        │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  5. 故障修复                                                    │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 修复方案评审     │                                           │
│  │ 灰度验证        │                                           │
│  │ 全量发布        │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  6. 复盘总结 (24 小时内)                                         │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────┐                                           │
│  │ 故障报告        │                                           │
│  │ 改进措施        │                                           │
│  │ 跟进落实        │                                           │
│  └─────────────────┘                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 常见故障处理预案

#### 预案 1: ECS 批量宕机

```markdown
## 故障场景：ECS 批量宕机

**可能原因:**
- 宿主机故障
- 网络故障
- 系统内核崩溃

**处理步骤:**

1. **确认故障范围** (2 分钟)
   ```bash
   aliyun ecs DescribeInstances --InstanceIds "i-xxx,i-yyy,i-zzz"
   ```

2. **尝试重启实例** (3 分钟)
   ```bash
   aliyun ecs RebootInstances --InstanceId.1 i-xxx --InstanceId.2 i-yyy
   ```

3. **如果重启失败，更换宿主机** (5 分钟)
   ```bash
   aliyun ecs ReplaceSystemDisk --InstanceId i-xxx
   ```

4. **弹性伸缩自动补充** (自动)
   - ASG 会自动创建新实例

5. **验证服务恢复** (2 分钟)
   ```bash
   curl https://www.coka.com/health
   ```

**回滚方案:**
- 如果新实例异常，回滚到快照

**后续改进:**
- 增加跨可用区部署
- 优化健康检查频率
```

#### 预案 2: RDS 主从切换

```markdown
## 故障场景：RDS 主库故障

**可能原因:**
- 硬件故障
- 主从同步中断
- 连接数耗尽

**处理步骤:**

1. **确认主从状态** (1 分钟)
   ```bash
   aliyun rds DescribeDBInstanceReplica --DBInstanceId rds-xxx
   ```

2. **如果自动切换未触发，手动切换** (2 分钟)
   ```bash
   aliyun rds SwitchDBInstanceHA --DBInstanceId rds-xxx
   ```

3. **验证新主库** (2 分钟)
   ```bash
   mysql -h rds-xxx-new-master.mysql.rds.aliyuncs.com -u root -p
   ```

4. **通知应用层更新连接字符串** (1 分钟)
   - 通过配置中心推送新连接串

5. **验证业务恢复** (2 分钟)
   ```bash
   curl https://www.coka.com/api/v1/products
   ```

**回滚方案:**
- 如果新主库异常，切换回原主库

**后续改进:**
- 优化主从同步监控
- 增加只读实例分担压力
```

#### 预案 3: Redis 雪崩

```markdown
## 故障场景：Redis 缓存雪崩

**可能原因:**
- 大量 key 同时过期
- Redis 实例宕机
- 网络分区

**处理步骤:**

1. **确认 Redis 状态** (1 分钟)
   ```bash
   aliyun redis DescribeInstanceAttribute --InstanceId r-xxx
   ```

2. **如果 Redis 不可用，启用本地缓存降级** (2 分钟)
   - 应用层自动切换到本地缓存 (Caffeine)

3. **如果是个别节点故障，隔离故障节点** (3 分钟)
   ```bash
   aliyun redis ReleaseInstancePublicKey --InstanceId r-xxx
   ```

4. **逐步恢复缓存** (5 分钟)
   - 分批重建热点数据缓存
   - 设置随机过期时间避免再次雪崩

5. **验证服务恢复** (2 分钟)
   ```bash
   curl https://www.coka.com/api/v1/products/12345
   ```

**回滚方案:**
- 如果缓存重建失败，保持降级状态

**后续改进:**
- 优化缓存过期策略 (添加随机值)
- 增加缓存预热机制
```

---

## 8. 附录

### 8.1 Terraform 监控配置

```hcl
# CloudMonitor 告警规则
resource "alicloud_cms_alarm" "cpu_high" {
  name                = "ecs-cpu-high"
  project             = "acs_ecs_dashboard"
  metric              = "CPUUtilization"
  period              = 300
  evaluation_count    = 3
  comparison_operator = "GreaterThan"
  threshold           = 80
  level               = "CRITICAL"
  
  notification_list = [
    alicloud_cms_alarm_contact_group.infra_team.arn
  ]
}

# SLS 告警
resource "alicloud_log_alert" "error_rate_high" {
  name        = "app-error-rate-high"
  description = "应用错误率过高"
  
  display     = "错误率告警"
  
  configuration {
    condition     = "count > 100"
    dashboard     = "app-monitoring"
    logstore      = "app-error-log"
    power         = 1
    role_arn      = alicloud_ram_role.sls_alert.arn
    template_id   = ""
    
    group_by      = "service"
    join_configurations {
      type = "no_join"
    }
    
    notification {
      type      = "Webhook-DingTalk"
      content   = "应用错误率过高，请立即处理！"
      email_list = ["admin@coka.com"]
      phone_list = ["+86-13800000000"]
      service_uri = "https://oapi.dingtalk.com/robot/send?access_token=xxx"
    }
  }
}
```

### 8.2 监控 SDK 集成

```typescript
// 应用层监控上报 (TypeScript)
import { ARMS } from '@ali/arms-sdk';

// 初始化 ARMS
ARMS.init({
  pid: 'coka-prod',
  uid: 'coka',
  enableLinkTrace: true,
  api: '/api/v1/arms/report',
  release: '1.0.0',
  env: 'prod',
  sample: 1, // 100% 采样
});

// 自定义业务监控
ARMS.biz('ORDER_CREATED', {
  orderId: 'ORD123456',
  amount: 299.00,
  userId: 'u_123456',
});

// 错误上报
try {
  await orderService.create(order);
} catch (error) {
  ARMS.error(error, {
    extra: { orderId: 'ORD123456' },
  });
  throw error;
}
```

---

**文档版本历史:**

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0.0 | 2026-03-17 | Infrastructure Team | 初始版本 |
