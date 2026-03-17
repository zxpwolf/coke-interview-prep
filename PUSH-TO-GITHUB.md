# 📤 手动推送到 GitHub 指南

**原因:** 当前网络环境无法直接推送到 GitHub，请手动执行以下步骤。

---

## ✅ 本地 Git 状态

```
✅ Git 仓库已初始化
✅ 所有文件已提交 (3 commits)
✅ 远程仓库已配置：git@github.com:zxpwolf/coka.git
❌ 推送失败：SSH 连接超时
```

---

## 🔧 方式 1: 使用 GitHub Desktop (最简单)

### 步骤

1. **下载 GitHub Desktop**
   - 访问：https://desktop.github.com
   - 下载并安装

2. **添加本地仓库**
   - 打开 GitHub Desktop
   - File → Add Local Repository
   - 选择目录：`/Users/Wolf/.openclaw/workspace/projects/Coka`

3. **推送到 GitHub**
   - 点击 "Publish repository"
   - 仓库名：`coka`
   - 勾选 "Keep this code private" (如果需要)
   - 点击 "Publish"

---

## 🔧 方式 2: 使用命令行 + HTTPS

### 步骤

1. **创建 GitHub 仓库**
   - 访问：https://github.com/new
   - 仓库名：`coka`
   - 描述：Coka 电商平台 - 阿里云架构
   - 设为 Private (可选)
   - **不要** 勾选 "Add a README" 或其他选项
   - 点击 "Create repository"

2. **更新远程仓库 URL**
   ```bash
   cd /Users/Wolf/.openclaw/workspace/projects/Coka
   
   # 删除现有 SSH 远程
   git remote remove origin
   
   # 添加 HTTPS 远程
   git remote add origin https://github.com/zxpwolf/coka.git
   ```

3. **推送代码**
   ```bash
   git push -u origin main
   ```
   
   系统会提示输入：
   - **Username:** 你的 GitHub 用户名
   - **Password:** 使用 **Personal Access Token** (不是密码!)

4. **创建 Personal Access Token (如果没有)**
   - 访问：https://github.com/settings/tokens
   - 点击 "Generate new token (classic)"
   - Note: `Coka Project Push`
   - 选择 scopes:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
   - 点击 "Generate token"
   - **复制并保存 token** (只显示一次!)

---

## 🔧 方式 3: 使用命令行 + SSH

### 步骤

1. **检查 SSH Key**
   ```bash
   # 查看是否有 SSH key
   ls -la ~/.ssh/id_*.pub
   ```

2. **如果没有，生成 SSH Key**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # 一路回车即可
   ```

3. **添加 SSH Key 到 GitHub**
   - 复制公钥：
     ```bash
     cat ~/.ssh/id_ed25519.pub | pbcopy
     ```
   - 访问：https://github.com/settings/keys
   - 点击 "New SSH key"
   - Title: `My Mac`
   - Key: 粘贴公钥
   - 点击 "Add SSH key"

4. **测试 SSH 连接**
   ```bash
   ssh -T git@github.com
   # 应该显示：Hi zxpwolf! You've successfully authenticated...
   ```

5. **推送代码**
   ```bash
   cd /Users/Wolf/.openclaw/workspace/projects/Coka
   git push -u origin main
   ```

---

## 📁 要推送的文件

确保以下文件都被推送：

```
coka/
├── .github/
│   └── workflows/
│       └── deploy.yml           # CI/CD 流水线
├── docs/
│   ├── ARCHITECTURE.md          # 架构设计 (29.8KB)
│   └── MONITORING.md            # 监控设计 (29.3KB)
├── terraform/
│   └── environments/
│       └── prod/
│           └── main.tf          # Terraform 配置 (13.1KB)
├── .gitignore
├── README.md                    # 项目说明 (6.8KB)
├── PROJECT_SUMMARY.md           # 交付总结 (5.2KB)
├── GITHUB_SETUP.md              # 推送指南 (2.5KB)
└── PUSH-TO-GITHUB.md            # 本文档
```

**总计:** 8 个文件，~100KB

---

## ✅ 验证推送成功

推送成功后，访问：
- https://github.com/zxpwolf/coka

应该能看到：
- ✅ 所有文件
- ✅ Commit 历史 (3 commits)
- ✅ README 渲染正常

---

## 🔧 配置 GitHub Secrets (推送后)

推送完成后，配置以下 Secrets 用于 CI/CD:

1. 访问：https://github.com/zxpwolf/coka/settings/secrets/actions
2. 添加以下 secrets:

| Secret Name | Value | 用途 |
|-------------|-------|------|
| `ACR_USERNAME` | 阿里云容器镜像服务用户名 | Docker 镜像推送 |
| `ACR_PASSWORD` | 阿里云容器镜像服务密码 | Docker 镜像推送 |
| `ALIYUN_ACCESS_KEY_ID` | 阿里云 AccessKey ID | Terraform 部署 |
| `ALIYUN_ACCESS_KEY_SECRET` | 阿里云 AccessKey Secret | Terraform 部署 |
| `ACK_DEV_CLUSTER_ID` | ACK 开发集群 ID | 开发环境部署 |
| `DINGTALK_WEBHOOK` | 钉钉机器人 Webhook | 告警通知 |

---

## 🐛 常见问题

### 问题 1: "remote: Repository not found"

**解决:** 先在 GitHub 创建空仓库，然后再推送。

### 问题 2: "Authentication failed"

**解决:**
- HTTPS: 确保使用 Personal Access Token，不是密码
- SSH: 确保 SSH key 已添加到 GitHub

### 问题 3: "failed to push some refs"

**解决:**
```bash
# 强制推送 (小心使用)
git push -f origin main

# 或者先拉取再推送
git pull --rebase origin main
git push -u origin main
```

---

## 📞 需要帮助？

- GitHub Docs: https://docs.github.com
- 阿里云文档：https://help.aliyun.com

---

**准备好了吗？选择一种方式开始推送吧!** 🚀
