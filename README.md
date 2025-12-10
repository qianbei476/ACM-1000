# Redis Sentinel 重启问题修复方案

## 问题描述

您的 Redis 集群中 `redis-sentinel1` 和 `redis-sentinel3` 一直处于重启状态（Restarting）。

## 问题原因

Redis Sentinel 重启的主要原因包括：

### 1. **配置文件权限问题** ⭐ 最常见
Redis Sentinel 需要**写权限**来更新配置文件。当 Sentinel 检测到主从切换或其他拓扑变化时，会自动修改 `sentinel.conf` 文件。如果没有写权限，Sentinel 会启动失败并不断重启。

### 2. **端口配置问题**
所有 Sentinel 实例使用同一个配置文件，但没有指定不同的端口。在 host 网络模式下，这会导致端口冲突。

### 3. **配置文件内容错误或缺失**
配置文件可能缺少必要的配置项或配置不正确。

## 解决方案

### 方案 A：使用自动修复脚本（推荐）

我已经为您创建了一个自动修复脚本。请按以下步骤操作：

```bash
# 1. 下载或复制 fix-sentinel.sh 脚本到服务器
# 2. 赋予执行权限
chmod +x fix-sentinel.sh

# 3. 以 root 权限运行
sudo bash fix-sentinel.sh

# 4. 进入您的 redis-cluster 目录并重启服务
cd [您的redis-cluster目录路径]  # 例如：cd /root/redis-cluster
docker-compose down
docker-compose up -d

# 5. 检查状态
docker-compose ps
```

### 方案 B：手动修复

如果您想手动修复，请按以下步骤操作：

#### 步骤 1：创建正确的 Sentinel 配置文件

为每个 Sentinel 创建**不同端口**的配置文件：

**Sentinel 1 配置** (`/opt/redis-cluster/sentinel1/sentinel.conf`):
```conf
bind 0.0.0.0
port 26379
dir /tmp
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1
protected-mode no
loglevel notice
daemonize no
```

**Sentinel 2 配置** (`/opt/redis-cluster/sentinel2/sentinel.conf`):
```conf
bind 0.0.0.0
port 26380
dir /tmp
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1
protected-mode no
loglevel notice
daemonize no
```

**Sentinel 3 配置** (`/opt/redis-cluster/sentinel3/sentinel.conf`):
```conf
bind 0.0.0.0
port 26381
dir /tmp
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1
protected-mode no
loglevel notice
daemonize no
```

#### 步骤 2：设置正确的权限（关键！）

```bash
# 设置配置文件为可读可写
chmod 666 /opt/redis-cluster/sentinel1/sentinel.conf
chmod 666 /opt/redis-cluster/sentinel2/sentinel.conf
chmod 666 /opt/redis-cluster/sentinel3/sentinel.conf

# 设置目录权限
chmod -R 777 /opt/redis-cluster/sentinel1
chmod -R 777 /opt/redis-cluster/sentinel2
chmod -R 777 /opt/redis-cluster/sentinel3
```

#### 步骤 3：重启服务

```bash
cd [您的redis-cluster目录]
docker-compose down
docker-compose up -d
```

## 验证修复

### 1. 检查容器状态
```bash
docker-compose ps
```

所有容器的 STATUS 应该显示 "Up"，而不是 "Restarting"。

### 2. 查看 Sentinel 日志
```bash
docker logs redis-sentinel1
docker logs redis-sentinel2
docker logs redis-sentinel3
```

正常的日志应该类似：
```
# Sentinel started successfully
+monitor master mymaster 127.0.0.1 6379 quorum 2
+sdown master mymaster 127.0.0.1 6379
```

### 3. 验证 Sentinel 功能
```bash
# 连接到各个 Sentinel 并查看状态
docker exec redis-sentinel1 redis-cli -p 26379 info sentinel
docker exec redis-sentinel2 redis-cli -p 26380 info sentinel
docker exec redis-sentinel3 redis-cli -p 26381 info sentinel
```

您应该看到：
- `sentinel_masters:1`
- `sentinel_running_scripts:0`
- `sentinel_scripts_queue_length:0`

### 4. 测试主从切换（可选）
```bash
# 查看当前的 master
docker exec redis-sentinel1 redis-cli -p 26379 sentinel get-master-addr-by-name mymaster

# 手动触发故障转移（测试用）
docker exec redis-sentinel1 redis-cli -p 26379 sentinel failover mymaster
```

## 配置说明

### 关键配置项解释

| 配置项 | 说明 |
|--------|------|
| `port` | **每个 Sentinel 必须使用不同的端口**（26379, 26380, 26381） |
| `sentinel monitor mymaster 127.0.0.1 6379 2` | 监控名为 mymaster 的主节点，quorum 为 2（至少 2 个 sentinel 同意才进行故障转移） |
| `sentinel down-after-milliseconds` | 5秒无响应后认为节点下线 |
| `sentinel failover-timeout` | 故障转移超时时间 10秒 |
| `sentinel parallel-syncs` | 故障转移时最多 1 个从节点同时同步 |
| `protected-mode no` | 关闭保护模式，允许远程连接 |
| `daemonize no` | 不使用后台运行（Docker 需要前台进程） |

### 为什么需要写权限？

Redis Sentinel 在运行时会自动更新配置文件，包括：
- 记录发现的其他 Sentinel 节点
- 记录发现的 Slave 节点
- 更新故障转移后的新 Master 信息

示例（Sentinel 自动添加的内容）：
```conf
# 原始配置
sentinel monitor mymaster 127.0.0.1 6379 2

# Sentinel 运行后自动添加的内容
sentinel config-epoch mymaster 0
sentinel leader-epoch mymaster 0
sentinel known-replica mymaster 127.0.0.1 6380
sentinel known-replica mymaster 127.0.0.1 6381
sentinel known-sentinel mymaster 127.0.0.1 26380 82a7...
sentinel known-sentinel mymaster 127.0.0.1 26381 91b3...
```

## 常见问题排查

### Q1: 修复后还是重启怎么办？

查看具体的错误日志：
```bash
docker logs redis-sentinel1 --tail 50
```

常见错误：
- `Permission denied`: 权限问题，检查文件权限
- `Address already in use`: 端口被占用，检查端口配置
- `Can't open the append-only file`: 数据目录权限问题

### Q2: 如何确认 Sentinel 正常监控？

```bash
# 查看监控状态
docker exec redis-sentinel1 redis-cli -p 26379 sentinel masters

# 查看从节点
docker exec redis-sentinel1 redis-cli -p 26379 sentinel slaves mymaster

# 查看其他 Sentinel
docker exec redis-sentinel1 redis-cli -p 26379 sentinel sentinels mymaster
```

### Q3: 修复后配置文件内容变了？

这是正常的！Sentinel 会自动在配置文件中添加：
- 其他 Sentinel 节点信息
- 从节点信息
- 配置版本号等

不要担心，这些是 Sentinel 正常工作的一部分。

## 架构说明

您的 Redis 集群架构：

```
Redis Master (6379)
    ↓ 复制
├── Redis Slave 1 (6380)
└── Redis Slave 2 (6381)

Sentinel 1 (26379) ─┐
Sentinel 2 (26380) ─┼─ 监控和故障转移
Sentinel 3 (26381) ─┘
```

- **Quorum = 2**: 至少 2 个 Sentinel 同意才能进行故障转移
- **Majority = 2**: 3 个 Sentinel 的大多数是 2

## 生产环境建议

1. **分离部署**: 将 Sentinel 部署在不同的物理机器上
2. **监控告警**: 配置 Sentinel 监控和告警通知
3. **备份策略**: 定期备份 Redis 数据
4. **网络隔离**: 使用防火墙限制 Redis 端口访问
5. **日志收集**: 集中收集和分析 Redis 和 Sentinel 日志

## 文件说明

- `docker-compose.yaml`: Docker Compose 配置文件
- `sentinel.conf.template`: Sentinel 配置文件模板
- `fix-sentinel.sh`: 自动修复脚本
- `README.md`: 本说明文档

## 需要帮助？

如果按照以上步骤操作后仍有问题，请提供以下信息：

1. `docker-compose ps` 的完整输出
2. `docker logs redis-sentinel1` 的最后 50 行日志
3. `ls -la /opt/redis-cluster/sentinel1/` 的输出
4. 您的操作系统版本和 Docker 版本

祝您修复顺利！🚀
