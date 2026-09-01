#!/usr/bin/env bash
# ============================================================
# super-agent 后端开发启动脚本
#
# 用法:
#   ./run-dev.sh            直接启动后端(自动加载 .env)
#   ./run-dev.sh --build    先 mvn clean install 再启动
#
# 说明:
#   1. 自动把项目根目录 .env 里的变量加载进环境变量并导出,
#      Spring Boot 用 ${VAR} 占位符就能取到值。
#   2. .env 是 CRLF 行尾, 这里会先去掉 \r 再 source, 避免
#      变量值末尾带回车导致连不上数据库。
#   3. 前提: 已装 JDK17 + Maven, 且 docker 基础设施已启动。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- 加载 .env ----------
if [ -f ".env" ]; then
  set -a
  # 用 process substitution 去掉 CRLF 中的 \r 再 source
  # shellcheck disable=SC1090
  . <(tr -d '\r' < .env)
  set +a
  echo "[run-dev] 已加载 .env 环境变量"
else
  echo "[run-dev] 警告: 未找到 .env, 使用系统环境变量继续" >&2
fi

# ---------- 解析参数 ----------
BUILD=false
ARGS=()
for a in "$@"; do
  if [ "$a" = "--build" ]; then
    BUILD=true
  else
    ARGS+=("$a")
  fi
done

if [ "$BUILD" = true ]; then
  echo "[run-dev] 编译所有模块..."
  mvn -q clean install -DskipTests
fi

echo "[run-dev] 启动后端 (端口 9082) ..."
mvn -pl super-agent-business/super-agent-business-chat -am spring-boot:run "${ARGS[@]}"
