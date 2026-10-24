# Changelog

本文件记录 `github-tech-scout` 的变更，版本遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## 0.1.1 — 2026-10-24

- `description` 改为两句话：先讲触发场景，再讲动作（搜 GitHub → 读 README → 交方案），触发词保持不变。
- LICENSE 署名改为 `yutang146012`。
- CI：修复冒烟步骤的退出码——`gh.ps1` 参数错误时 `exit 1`，pwsh 会把它继承成整个步骤的结果。
- README 补 CI 徽章，clone 地址换成真实仓库。

## 0.1.0 — 2026-10-24

首个可用版本。

- `SKILL.md`：五步工作流（能力缺口 → 检索式 → 粗筛 → 精读 → 方案）、五维评分表、报告模板、DSH 落地形态速查。
- `scripts/gh.ps1`：`search`（检索并压成两行摘要）与 `readme`（走 raw，自动去徽章墙、按字符截断）。
- 基于实测校正检索策略：GitHub 搜索为 AND 语义，限定词过严会把结果压到个位数；匿名仓库 API 配额（60/小时）与搜索配额（10/分钟）分开，因此禁止逐个仓库调用详情接口。
- `scripts/validate_skill.py` + GitHub Actions：校验 frontmatter 与目录结构。
- `examples/pdf-table-extraction.md`：一次真实调研的产出样例。
