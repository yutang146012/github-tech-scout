---
name: github-tech-scout
description: Use when a task needs a capability that likely already exists — an MCP server, an agent skill, a library, a CLI, or a reference implementation. Search GitHub, read a few READMEs, and return a decision-ready feasibility plan (找现成方案、技术选型、能不能用开源实现) instead of building from scratch.
---

# GitHub 技术侦察

把"这个需求有没有现成的东西"变成一份可决策的方案，而不是一堆链接。

## 何时用

- 需要一种能力，先想知道有没有现成的 MCP server / skill / 库 / CLI。
- 用户在选型：「用哪个开源项目」「这套方案可行吗」「有没有更省事的办法」。
- 要在自建和复用之间做取舍。

不适用：查某个库的 API 用法（直接看官方文档更快）；已经指定了仓库、只需要集成（直接读那个仓库）。

## 四条铁律

1. **只调研，不动手。** 不 clone、不安装、不改配置、不 `npm/pip install`。方案最后给「下一步命令」，等用户点头再执行。
2. **事实分层。** star / 最近提交 / 许可证来自 API，算事实；README 里的功能描述是「作者声称」；报告里要区分。没读到的不要补。
3. **有预算。** 最多 4 条检索式、4 个仓库精读、每个 README 取前 6000 字符。
4. **零命中也要交卷。** 给「自建」路线和换词重搜的建议，不要编造项目。

## 第 0 步：写清能力缺口

一句话：`需要【能力】；运行环境【语言/系统】；约束【离线、许可、成本、权限】；期望形态【MCP / skill / 库 / CLI】`。

约束不明就按最保守假设（可离线、商用许可、能本地跑），并在报告里标注「假设」。

## 第 1 步：生成 3-4 条检索式

一条检索式 = 关键词 + 形态词 + 限定词。不要用自然语言整句去搜。

| 想找 | 检索式写法 |
|---|---|
| MCP server | `<关键词> mcp server`，或 `topic:mcp <关键词>` |
| Agent skill | `<关键词> agent skill`、`<关键词> SKILL.md in:readme` |
| 库 / SDK | `<关键词> language:typescript`（星标门槛后面再加） |
| 参考实现 | `<关键词> pushed:>2026-01-01 archived:false` |

**检索式是 AND 语义，词越多结果越少。** 实测：`pdf table extraction stars:>2000` 只剩 1 条，去掉第三个词、去掉星标门槛才搜得动。所以：

- 先跑 1-2 个**有区分度**的词，看清结果再收紧。
- `in:name,description` 只搜这两个字段（不含 README / topics），收得很狠，命中数掉到个位数就先去掉。
- `stars:>N` 是双刃剑：能滤掉玩具项目，也会滤掉新而专的项目。**第一轮不加**，需要时再加。
- `matches` 是个位数，说明检索式太窄，不是"GitHub 上没有"。

限定词：`archived:false`、`stars:>50`、`language:`、`topic:`、`pushed:>YYYY-MM-DD`、`license:mit`。

## 第 2 步：检索 + 粗筛

```powershell
& "<skill 目录>\scripts\gh.ps1" search '<检索式>' --limit 6
```

`<skill 目录>` 用资源块里给出的基目录拼绝对路径。脚本不可用（无 pwsh / 无网络）时，改用 `web_fetch` 抓
`https://api.github.com/search/repositories?q=<urlencoded>&per_page=5`（不加 `sort`，默认按相关度）。

先看 `matches` 再读结果：个位数就放宽检索式重跑一轮，别拿 1 条结果当"全网只有这个"。

粗筛红线，命中即淘汰（除非用户明确要「考古」）：

- `archived: true`
- 18 个月没有提交
- 没有 LICENSE（商用 / 交付场景）
- 没有 README，或 README 不足 20 行
- 核心功能必须付费托管服务才能跑通

留 3-4 个进精读，其余在报告「备选」里一行带过。

## 第 3 步：精读 README

```powershell
& "<skill 目录>\scripts\gh.ps1" readme owner/repo --max 6000
```

每个仓库只提取 6 件事：

1. **定位**——它到底解决什么，边界在哪
2. **安装与依赖**——`npx` / `uvx` / `pip` / `docker` / 二进制，要不要特定 Node 或 Python 版本
3. **接入形态**——stdio MCP / HTTP MCP / 库 / CLI / 可直接复制的 skill 目录
4. **认证**——要不要 API key、要不要登录、密钥怎么传
5. **已知限制**——README 里 Requirements / Limitations / Known issues 段落
6. **最小可跑示例**——README 有没有能直接粘的命令

README 没写的（并发、性能、企业支持、SLA）标「未验证」，不要脑补。

## 第 4 步：评分

| 维度 | 权重 | 判据 |
|---|---|---|
| 需求契合 | 40 | 覆盖能力缺口的比例；主场景能否直接跑通 |
| 成熟度 | 25 | star 与项目年龄相称；有 release；issue 有人回；有测试/CI |
| 活跃度 | 15 | 90 天内有提交 = 15；一年内 = 8；更久 = 0 |
| 集成成本 | 10 | 能按 DSH 现有形态直接接 = 10；要写适配层 = 4；要改上游 = 0 |
| 合规 | 10 | MIT/Apache/BSD = 10；AGPL 或商用限制 = 4；无许可 = 0 |

star 只是成熟度的弱信号，单独拿出来不构成推荐理由。

**形态取舍**：能做成 CLI / skill 的，优先于 MCP——常驻的工具定义会挤占上下文，CLI 调用更省 token（`microsoft/playwright-mcp` 的 README 自己就建议 coding agent 优先用它的 CLI+skills）。需要长连接、资源订阅、跨会话状态时才选 MCP。

## 第 5 步：输出方案

先结论后论证，按这个结构给：

```markdown
## 结论
推荐 <X>：<一句话理由>。接入约 <N> 步 / <T> 小时，主要风险是 <R>。

## 能力缺口
<一句话：需要什么、约束是什么>

## 候选对比
| 项目 | ★ | 最近提交 | 许可 | 形态 | 契合度 | 结论 |
|---|---|---|---|---|---|---|

## 首选：<X>
- 它是什么：
- 为什么是它：
- 怎么接入：（可直接粘的命令 / 配置片段）
- 验收标准：<2-3 条可验证的结果>

## 风险与备选
| 风险 | 影响 | 缓解 |
|---|---|---|

## 下一步（待确认）
1. …
```

工作量给「步数 + 小时」的区间，不要假的精确值。方案里写清**放弃条件**：什么情况下这条路不值得走。

## DSH 落地形态速查

| 形态 | 怎么落到 DSH |
|---|---|
| skill | 目录放到 `<dshHome>/skills/<name>/`（`<dshHome>` = `$DSH_HOME` 或 `~/.dsh`），项目内放 `<project>/.dsh/skills/`；必须有 SKILL.md，名字是 kebab-case |
| MCP | `mcpServers` 条目：stdio 用 `command`（绝对路径）+ `args` + `env`；远程用 `type: http` + `url` + `headers` |
| 库 / CLI | 加依赖或全局安装，直接跑 |

## 配额与失败处理

- **搜索 API**：匿名 10 次/分钟。`--limit` 别开大，一次 6 条够用。
- **仓库详情 API**（`/repos/...`、`/readme`、`/releases`）：匿名 60 次/小时，而且常被同一台机器上的其他工具用光。**不要逐个仓库去调**——搜索返回的字段已经够评分。
- **README**：走 `raw.githubusercontent.com`，不占 API 配额。
- `403 / rate limited`：等 60 秒；或请用户设置 `GITHUB_TOKEN` 提高额度；或退到 `web_search`，用 `site:github.com <关键词>`。
- raw 抓不到：改抓 `https://github.com/<owner>/<repo>` 页面正文。
- 完全没网：直说，给一份可直接粘的检索式清单，不要虚构项目。

## 反模式

- 甩一堆 star 数就下结论。
- 把 README 的营销语当成评测结论。
- 一次读 8 个 README，把自己的上下文撑爆。
- 顺手 clone / 安装 / 改配置。
- 忽略许可证、最近提交时间、归档状态。
- 只搜一条检索式就收工。
