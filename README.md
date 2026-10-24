# github-tech-scout

让 agent 自己去找现成方案：给它一个「我想要 XX 能力」的任务，它去 GitHub 检索、读 README、打分排序，回你一份能直接决策的可行性方案。

这是 [DeepSeek Harness](https://github.com/deepseek-ai)（DSH）的一个 skill。

## 它解决什么问题

你有一个需求，但不确定该自建还是复用：

> 「帮我找个能做 PDF 表格提取的开源方案」
> 「有没有现成的 MCP server 能操作浏览器？」
> 「这个需求用开源实现靠谱吗？」

直接让模型「去 GitHub 搜一下」，得到的通常是一堆链接和 star 数。这个 skill 强制走一条有约束的流程，产出可执行、可验收、带放弃条件的方案。

## 工作流

```
0. 能力缺口   需要什么 + 运行环境 + 约束 + 期望形态（MCP/skill/库/CLI）
1. 检索式     3-4 条，关键词 + 形态词 + 限定词
2. 粗筛       归档 / 18 个月无提交 / 无许可证 / 无 README → 直接淘汰
3. 精读       README 只取 6 件事：定位、依赖、接入形态、认证、限制、最小示例
4. 打分       契合 40 + 成熟 25 + 活跃 15 + 集成 10 + 合规 10
5. 出方案     结论 → 对比表 → 首选方案与接入命令 → 风险 → 待确认
```

硬性预算：最多 4 条检索式、4 个仓库精读、每个 README 前 6000 字符。零命中也要给「自建」路线，不许编项目。

## 安装

用户级（所有项目可用）：

```powershell
git clone https://github.com/<you>/github-tech-scout "$env:USERPROFILE\.dsh\skills\github-tech-scout"
```

```bash
git clone https://github.com/<you>/github-tech-scout ~/.dsh/skills/github-tech-scout
```

项目级（只在该项目生效）：clone 到 `<项目>/.dsh/skills/`。目录名保持 `github-tech-scout`，与 frontmatter 里的 `name` 一致。

装好后新开一轮对话，技能列表里出现 `github-tech-scout` 即可。也可以直接点名调用。

## 环境要求

| 项 | 说明 |
|---|---|
| DSH | 从 `$DSH_HOME/skills`（默认 `~/.dsh/skills`）或 `<项目>/.dsh/skills` 加载 |
| PowerShell 7+ | `scripts/gh.ps1` 需要 `pwsh`；Windows 自带，macOS/Linux 需 `brew install powershell` |
| 网络 | 需要能访问 `api.github.com` 与 `raw.githubusercontent.com` |
| GitHub token（可选） | 设 `GITHUB_TOKEN` 可提高配额；不设也能用 |

没有 `pwsh` 或网络受限时，skill 会退回 `web_fetch` 抓搜索 API + GitHub 页面正文，功能会降级但仍然可用。

## 输出长什么样

```markdown
## 结论
推荐 docling：本地跑、MIT、表格结构原生支持，接入约 3 步 / 1-2 小时。

## 候选对比
| 项目 | ★ | 最近提交 | 许可 | 形态 | 契合度 | 结论 |
|---|---|---|---|---|---|---|
| docling | 69.5k | 2026-10-24 | MIT | 库+CLI+MCP | 高 | 首选 |
| camelot | 3.7k | 2023-01-05 | NOASSERTION | 库 | 中 | 淘汰：已归档 |

## 首选：docling
- 怎么接入：pip install docling && docling in.pdf --to md
- 验收标准：5 份合并单元格 PDF 表格还原率 ≥90%；全离线
- 放弃条件：手写体无框线表格 → 改用视觉模型
```

完整示例见 [examples/pdf-table-extraction.md](examples/pdf-table-extraction.md)。

## 仓库结构

```
.
├── SKILL.md                    # 技能本体：流程、评分表、报告模板
├── scripts/
│   ├── gh.ps1                  # search / readme 两个子命令
│   └── validate_skill.py       # 结构校验（本地与 CI 共用）
├── examples/
│   └── pdf-table-extraction.md # 一次真实调研的产出
├── .github/workflows/validate.yml
├── README.md
├── CHANGELOG.md
└── LICENSE
```

## 脚本用法

```powershell
# 检索：默认按相关度，--stars 按 star 排序
.\scripts\gh.ps1 search 'pdf table extraction' --limit 6
.\scripts\gh.ps1 search 'mcp server browser' --limit 6 --stars

# 读 README：可一次多个，--max 控制截断
.\scripts\gh.ps1 readme docling-project/docling microsoft/markitdown --max 6000
```

`search` 输出每个仓库两行（名称、star、最近提交、许可证、语言、摘要），比原始 JSON 省一个数量级；`readme` 走 `raw.githubusercontent.com`，不占 API 配额，并会自动去掉徽章墙。

## 设计取舍

| 决定 | 原因 |
|---|---|
| 只调研、不动手 | 安装、改配置都是不可逆的外部动作，留到最后一步由用户点头 |
| 检索式先宽后窄 | GitHub 搜索是 AND 语义，堆限定词会把结果压到个位数（实测 `pdf table extraction stars:>2000` 只剩 1 条） |
| 禁止逐个调 `/repos/...` | 匿名仓库 API 只有 60 次/小时，且常被同机其他工具用光；搜索是独立配额（10 次/分钟） |
| README 走 raw | 不占配额，正文干净 |
| CLI/skill 优先于 MCP | 常驻的工具定义会挤占上下文，CLI 调用更省 token；需要长连接或状态时才上 MCP |
| 事实与声称分开 | star/提交时间来自 API 是事实，README 的功能描述是作者声称，混淆就会给出错误的推荐 |

## 迭代

- 版本号见 [CHANGELOG.md](CHANGELOG.md)，遵循语义化版本。
- 改 `SKILL.md` 的规则时，同步更新 README 的「设计取舍」，否则下一个人（或下一轮的你）不知道原因。
- 提交前跑校验：`python3 scripts/validate_skill.py`；CI 也会跑。
- 待做：`--json` 输出、多仓库 README 并行抓取、调研结果自动落盘成 `docs/scout-<date>.md`。

## License

MIT
