#!/bin/bash
# Redis Sentinel 修复脚本

set -e

echo "========================================"
echo "Redis Sentinel 修复脚本"
echo "========================================"
echo ""

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "错误：请使用 root 权限运行此脚本"
    echo "使用命令：sudo bash fix-sentinel.sh"
    exit 1
fi

# 创建必要的目录
echo "步骤 1: 创建目录结构..."
mkdir -p /opt/redis-cluster/sentinel1
mkdir -p /opt/redis-cluster/sentinel2
mkdir -p /opt/redis-cluster/sentinel3
mkdir -p /opt/redis-cluster/master/data
mkdir -p /opt/redis-cluster/slave1/data
mkdir -p /opt/redis-cluster/slave2/data

# 创建 sentinel1 配置
echo "步骤 2: 创建 Sentinel 配置文件..."
cat > /opt/redis-cluster/sentinel1/sentinel.conf << 'EOF'
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
EOF

# 创建 sentinel2 配置
cat > /opt/redis-cluster/sentinel2/sentinel.conf << 'EOF'
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
EOF

# 创建 sentinel3 配置
cat > /opt/redis-cluster/sentinel3/sentinel.conf << 'EOF'
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
EOF

# 设置正确的权限（这是关键！）
echo "步骤 3: 设置文件权限..."
chmod 666 /opt/redis-cluster/sentinel1/sentinel.conf
chmod 666 /opt/redis-cluster/sentinel2/sentinel.conf
chmod 666 /opt/redis-cluster/sentinel3/sentinel.conf

# 设置目录权限
chmod -R 777 /opt/redis-cluster/sentinel1
chmod -R 777 /opt/redis-cluster/sentinel2
chmod -R 777 /opt/redis-cluster/sentinel3

echo "步骤 4: 停止并删除有问题的容器..."
docker stop redis-sentinel1 redis-sentinel3 2>/dev/null || true
docker rm redis-sentinel1 redis-sentinel3 2>/dev/null || true

echo ""
echo "========================================"
echo "修复完成！"
echo "========================================"
echo ""
echo "现在请按以下步骤操作："
echo ""
echo "1. 进入您的 redis-cluster 目录："
echo "   cd /root/redis-cluster  # 或您实际的目录"
echo ""
echo "2. 重启 Redis 集群："
echo "   docker-compose down"
echo "   docker-compose up -d"
echo ""
echo "3. 等待几秒钟后检查状态："
echo "   docker-compose ps"
echo ""
echo "4. 查看 Sentinel 日志（如果还有问题）："
echo "   docker logs redis-sentinel1"
echo "   docker logs redis-sentinel3"
echo ""
echo "5. 验证 Sentinel 是否正常工作："
echo "   docker exec redis-sentinel1 redis-cli -p 26379 info sentinel"
echo "   docker exec redis-sentinel2 redis-cli -p 26380 info sentinel"
echo "   docker exec redis-sentinel3 redis-cli -p 26381 info sentinel"
echo ""
