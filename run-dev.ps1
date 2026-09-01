<#
.SYNOPSIS
  super-agent 后端启动脚本 (PowerShell 版)

.DESCRIPTION
  自动加载项目根目录 .env 里的变量，然后用与 IDEA 一致的 Maven 配置启动后端。

  用法:
    .\run-dev.ps1              直接启动后端
    .\run-dev.ps1 --build      先 mvn clean install 再启动

.NOTES
  前提: mvn 在 PATH 里; Docker 基础设施已启动; 本机 MySQL 已建好库表。
#>

# ---------- 可配置项: 和 IDEA 里用的 Maven 设置保持一致 ----------
$MVN_SETTINGS = "D:\tools_app\apache-maven-3.9.11-bin\apache-maven-3.9.11\conf\settings-study.xml"
$MVN_REPO     = "D:\tools_app\apache-maven-3.9.11-bin\apache-maven-3.9.11\repo-study"

# 切换到脚本所在目录(项目根目录)
Set-Location $PSScriptRoot

# ---------- 加载 .env ----------
if (Test-Path .env) {
  Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#=][^=]*)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
  Write-Host "[run-dev] 已加载 .env 环境变量" -ForegroundColor Green
} else {
  Write-Warning "[run-dev] 未找到 .env, 使用系统环境变量继续"
}

# ---------- 解析参数 ----------
$build = $false
foreach ($arg in $args) {
  if ($arg -eq '--build') { $build = $true }
}

$commonMvnArgs = @("-s", $MVN_SETTINGS, "-Dmaven.repo.local=$MVN_REPO")
$chatPom       = "super-agent-business/super-agent-business-chat/pom.xml"

# ---------- 1. 先把所有模块装进本地仓库 ----------
# 保证 chat 依赖的兄弟模块 (common-web / id-generator / lease-framework) 都在，
# 避免 "Could not resolve dependencies"。没变化时是增量编译，几秒就过。
Write-Host "[run-dev] 安装依赖模块..." -ForegroundColor Cyan
if ($build) {
  & mvn @commonMvnArgs -q clean install -DskipTests -f pom.xml
} else {
  & mvn @commonMvnArgs -q install -DskipTests -f pom.xml
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ---------- 2. 启动后端 ----------
# 必须用 -f 指向 chat 模块的 pom 再跑 spring-boot:run：
# 如果在根 pom 上跑，Maven 解析 "spring-boot" 这个插件前缀时，
# 根 pom 没声明该插件、settings-study.xml 的 pluginGroups 也没有
# org.springframework.boot，就会报 No plugin found for prefix 'spring-boot'。
Write-Host "[run-dev] 启动后端 (端口 9082) ..." -ForegroundColor Cyan
& mvn @commonMvnArgs -f $chatPom spring-boot:run
exit $LASTEXITCODE
