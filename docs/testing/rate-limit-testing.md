# Rate Limit Testing Guide

## 测试前准备

1. 确保使用 OpenRouter NVIDIA 免费层配置
2. 准备测试照片集：
   - 小批量：5-10 张照片
   - 大批量：50+ 张照片
3. 启用日志记录（Settings > Enable Logging）

## 测试步骤

### 1. 小批量测试（5-10张照片）

**目的**: 验证速率限制逻辑生效

**步骤**:
1. 在 Lightroom 中选择 5-10 张照片
2. 运行 AI Selects > Score Photos
3. 检查日志文件（`~/Desktop/Selects Logs/` 或 `%USERPROFILE%\Desktop\Selects Logs\`）
4. 验证每次 API 调用时间戳间隔 ≥ 1.5秒

**预期结果**:
- 日志显示每次批次调用间隔约 1.5秒
- 无 429 错误
- Lightroom 控制台无错误

### 2. 大批量测试（50+张照片）

**目的**: 验证连续调用不会触发 40 RPM 限制

**步骤**:
1. 在 Lightroom 中选择 50+ 张照片
2. 运行 AI Selects > Score Photos
3. 记录开始时间和结束时间
4. 检查 OpenRouter 控制台的使用统计

**预期结果**:
- 总执行时间 ≈ 原时间 + (批次数 × 1.5秒)
- OpenRouter 控制台无 429 错误
- 请求分布均匀

### 3. 其他提供商测试

**目的**: 确认其他提供商不受影响

**步骤**:
1. 切换到其他提供商（ollama/claude/openai/gemini）
2. 运行相同照片的评分
3. 对比执行时间

**预期结果**:
- 执行时间与修改前相同
- 无额外等待时间

## 验证方法

### 日志分析

检查日志文件中的时间戳：
```
[Batch 1] 10:00:00.000  Starting
[Batch 1] 10:00:05.234  Done
[Batch 2] 10:00:06.734  Starting  <- 等待 1.5秒
[Batch 2] 10:00:12.456  Done
[Batch 3] 10:00:13.956  Starting  <- 等待 1.5秒
```

### OpenRouter 监控

1. 登录 OpenRouter 控制台
2. 查看使用统计
3. 确认无 429 状态码
4. 验证请求分布均匀

## 回滚策略

如果出现问题：
1. 移除 `BatchStrategy.lua` 中的 `requestDelay` 字段
2. 移除 `AIEngine.lua` 中的 sleep 逻辑
3. 重启 Lightroom
