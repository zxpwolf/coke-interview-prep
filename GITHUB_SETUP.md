# GitHub 仓库设置指南

## 📋 前提条件

- GitHub 账号
- SSH Key 或 Personal Access Token
- 阿里云账号

## 🔑 方式 1: 使用 SSH Key

### 1. 生成 SSH Key (如果没有)

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

### 2. 添加 SSH Key 到 GitHub

1. 复制公钥:
   ```bash
   cat ~/.ssh/id_ed25519.pub | pbcopy
   ```

2. 访问: https://github.com/settings/keys
3. 点击 "New SSH key"
4. 粘贴公钥，保存

### 3. 推送到 GitHub

```bash
cd /Users/Wolf/.openclaw/workspace/projects/Coka

# 添加远程仓库
git remote add origin git@github.com:zxpwolf/coka.git

# 推送
git push -u origin main
```

---

## 🔑 方式 2: 使用 Personal Access Token

### 1. 创建 Personal Access Token

1. 访问: https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 选择 scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
4. 生成并复制 token

### 2. 使用 HTTPS 推送

```bash
cd /Users/Wolf/.openclaw/workspace/projects/Coka

# 添加远程仓库 (使用 HTTPS)
git remote add origin https://github.com/zxpwolf/coka.git

# 推送 (会提示输入 token)
git push -u origin main
```

---

## 🛠️ 如果仓库已存在

```bash
cd /Users/Wolf/.openclaw/workspace/projects/Coka

# 如果已有远程仓库，先删除
git remote remove origin

# 重新添加
git remote add origin git@github.com:zxpwolf/coka.git

# 推送
git push -u origin main
```

---

## 🔧 配置 GitHub Secrets

推送代码后，配置以下 Secrets 用于 CI/CD:

1. 访问: https://github.com/zxpwolf/coka/settings/secrets/actions
2. 添加以下 secrets:

| Secret Name | Value | 说明 |
|-------------|-------|------|
| `ACR_USERNAME` | 你的阿里云容器镜像服务用户名 | Docker 镜像推送 |
| `ACR_PASSWORD` | 你的阿里云容器镜像服务密码 | Docker 镜像推送 |
| `ALIYUN_ACCESS_KEY_ID` | 你的阿里云 AccessKey ID | Terraform 部署 |
| `ALIYUN_ACCESS_KEY_SECRET` | 你的阿里云 AccessKey Secret | Terraform 部署 |
| `ACK_DEV_CLUSTER_ID` | ACK 开发集群 ID | 开发环境部署 |
| `DINGTALK_WEBHOOK` | 钉钉机器人 Webhook URL | 告警通知 |

---

## ✅ 验证推送

推送成功后，访问:
- https://github.com/zxpwolf/coka

应该能看到以下文件:
- ✅ README.md
- ✅ docs/ARCHITECTURE.md
- ✅ docs/MONITORING.md
- ✅ terraform/environments/prod/main.tf
- ✅ .github/workflows/deploy.yml
- ✅ PROJECT_SUMMARY.md

---

## 🐛 常见问题

### 问题 1: Permission denied (publickey)

**解决:**
```bash
# 测试 SSH 连接
ssh -T git@github.com

# 如果失败，重新添加 SSH key 到 GitHub
```

### 问题 2: repository not found

**解决:**
```bash
# 先在 GitHub 创建空仓库
# 然后执行:
git remote add origin git@github.com:zxpwolf/coka.git
git push -u origin main
```

### 问题 3: Authentication failed

**解决:**
- 如果使用 HTTPS，确保使用 Personal Access Token 而非密码
- 如果使用 SSH，确保 SSH key 已添加到 GitHub

---

## 📞 需要帮助？

- GitHub Docs: https://docs.github.com
- 阿里云文档：https://help.aliyun.com
