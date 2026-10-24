# 示例：给 agent 加 PDF 表格提取能力

> 一次真实调研的产出，2026-10-24 执行。数据来自 GitHub 搜索 API，会随时间变化；结构和判断方式才是要复用的部分。

## 能力缺口

需要把 PDF 里的表格转成结构化数据（Markdown 表格或 JSON）；运行在本地 Windows，要求可离线、可商用；期望形态是库或 CLI，agent 能直接调用。

## 检索过程

| 检索式 | 命中 | 说明 |
|---|---|---|
| `pdf table extraction stars:>2000` | 1 | 三个词 AND + 星标门槛，把结果压死了 |
| `pdf table extraction in:name,description stars:>2000` | 1 | 只搜名称和描述，更窄 |
| `docling in:name` | 1694 | 已知候选，直接查元数据 |
| `pdf mcp server in:name,description` | 1453 | 形态维度检索，结果偏杂 |

结论：先跑 1-2 个有区分度的词，别一上来就堆限定词。

## 候选对比

| 项目 | ★ | 最近提交 | 许可 | 形态 | 契合度 | 结论 |
|---|---|---|---|---|---|---|
| [docling-project/docling](https://github.com/docling-project/docling) | 69.5k | 2026-10-24 | MIT | 库 + CLI + MCP | 高 | **首选** |
| [microsoft/markitdown](https://github.com/microsoft/markitdown) | 191.8k | 2026-10-24 | MIT | 库 + CLI | 中高 | 轻量替代 |
| [atlanhq/camelot](https://github.com/atlanhq/camelot) | 3.7k | 2023-01-05 | NOASSERTION | 库 | 中 | 淘汰：已归档 |
| [chrisryugj/kordoc](https://github.com/chrisryugj/kordoc) | 2.7k | 2026-10-21 | MIT | CLI + MCP | 低 | 韩语文档为主，不匹配 |

camelot 是典型的陷阱：3.7k star、名字里直接写着 "PDF Table Extraction for Humans"，但 2023 年初就归档了，许可证字段是 NOASSERTION。只看 star 会选错。

## 首选：docling

- **它是什么**：IBM 起源的文档解析库，把 PDF/DOCX/PPTX/图片等转成统一的 `DoclingDocument`，再导出 Markdown、JSON、HTML。
- **为什么是它**：表格结构、阅读顺序、OCR 都是原生能力；纯本地执行，README 明确写了支持离线/气隙环境；MIT；同时提供 CLI、Python 库、MCP server、HTTP 服务（docling-serve）四种入口。
- **怎么接入**：

  ```powershell
  pip install docling
  docling .\input.pdf --to md --output .\out
  ```

  需要 agent 直接调用时，优先 CLI（省 token）；确实需要长连接或状态再上 MCP。
- **验收标准**：
  1. 5 份含合并单元格的 PDF，表格还原率 ≥ 90%；
  2. 单页 A4 处理在 3 秒内（纯 CPU）；
  3. 断网状态下能完整跑通一次。

## 风险与备选

| 风险 | 影响 | 缓解 |
|---|---|---|
| 扫描件要下载 OCR 权重，首次运行较慢 | 首跑体验差 | 提前预热，把模型缓存进镜像 |
| 复杂跨页表、无框线表仍会错行 | 还原率不达标 | 验收样本里显式放入这类 PDF；不达标就改视觉模型 |
| MCP 常驻工具定义占用上下文 | 长会话成本上升 | 默认走 CLI |

备选：[markitdown](https://github.com/microsoft/markitdown) 更轻，文档转 Markdown 够用，但表格结构信息会丢；要的是「表格」而不是「文本」时不要选它。

## 下一步（待确认）

1. 在干净虚拟环境里 `pip install docling`，跑验收样本；
2. 达标后写一个 `pdf2table` 包装脚本，固定 `--to md` 参数；
3. 不达标则回到评估：改用视觉模型，还是缩小到「只处理有框线表格」。

## 放弃条件

如果目标文档以手写体、无框线、跨页合并为主，且单次量小于 50 页——用视觉模型一次性处理更划算，不值得搭管线。
