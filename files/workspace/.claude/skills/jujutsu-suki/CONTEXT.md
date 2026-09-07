# jujutsu-suki

一份教 AI agent 用 jj 做版本控制的**纪律型 skill**。它存在的理由是：现有的 jj skill 以 git 命令对照表为骨架，读完之后 agent 仍在用 git 的形状思考，于是在 jj 仓库里持续产出可预测的反模式。

成品（SKILL.md）用**英文**写；设计文档（本文件、ADR）用中文。

## Language

### 文档形态

**危险面**:
`--help` 不会招认的行为集合：哪些命令会在非交互环境挂死，哪些会 exit 0 却什么都没做。纪律型 skill 唯一该缓存的事实。
_Avoid_: 坑、注意事项

**纪律型 skill**:
规定 agent 何时做什么、做完如何验证、出事如何恢复的文档。语法留给环境（`jj help`）。
_Avoid_: 手册、cheatsheet、参考卡

**手册型 skill**:
以命令与语法对照表为骨架的文档。本项目明确拒绝的形态。
_Avoid_: 速查表、mapping 表

**Matt-shape**:
本仓库遵循的打包惯例：紧凑 SKILL.md（≤140 行）+ 同目录平铺兄弟文件（不开子目录）+ `agents/openai.yaml` 三行元数据。
_Avoid_: references/ 子目录

**悬空指针**:
指向不存在文件的 context pointer。agent 按它去读、读失败，于是回退到预训练里的旧知识。
_Avoid_: 死链、broken link

### 反模式

除**游标视野**外，以下都是在真实使用中**观察到**的失败模式，不是推测清单。

**游标视野**:
以为必须"站在"一个节点上才能改它，于是一切操作都围绕当前 working copy 展开。git 的模型（HEAD + 暂存区）正是这个形状，它是下列反模式的共同根因。
_Avoid_: working copy 中心、隧道视野

**git 越界**:
在 colocated 仓库里用 git 命令执行 mutation，绕过 jj 的操作日志。
_Avoid_: 混用 git、git fallback

**快照污染**:
jj 的自动快照把无关改动一起卷进同一个提交。
_Avoid_: 提交不干净、dirty commit

**重做式修复**:
发现改动分错了提交时，用 `restore` 加重写来修，而不是把改动**原地移走**。git 里没有便宜的 split，所以这是 git 形状思维最可靠的指纹。
_Avoid_: reset 重来、推倒重写

**描述错位**:
`describe` 或 `squash` 打在错的 revision 上——典型是内容已经落在 `@-`，却去改 `@`。
_Avoid_: 提交信息写错地方

**谎报落地**:
宣布"已提交"，而实际状态并未达成落地判据。
_Avoid_: 假成功、虚报

**沉默失败**:
命令退出码为 0、agent 报告成功，坏结果要到 push 或下一次 `jj log` 才浮现。上述反模式的共同气质。
_Avoid_: 静默错误

**`@`/`@-` 算术**:
"内容现在在 `@` 还是 `@-`"这一持续追踪负担。游标视野在寻址上的具体表现，也是描述错位的直接来源。
_Avoid_: revision 换算

### jj 原生能力

git 里做不到或很贵、jj 里便宜的事。它们构成本 skill 的正向骨架：agent 意识不到这些能力，就只会退回 git 的招式。

**DAG**:
提交构成的图。jj 真正的操作对象，也是使用 jj 时该想象的东西。
_Avoid_: 提交历史、commit tree

**游标**:
`@`，标记"文件编辑落到哪个节点"的指针。仅此而已，不是操作的中心。
_Avoid_: 当前提交、HEAD、工作副本

**显式寻址**:
用稳定 change ID 指名要操作的节点，而不是用游标相对位置（`@`、`@-`）。前提是先读一次 DAG，所以它顺带把验证变成了刚性步骤。
_Avoid_: 相对寻址

**改动路由**:
把 hunk 送到它该去的节点（`absorb`、`squash --from --into`、`split -r`），而不把游标移过去。
_Avoid_: 搬代码、挪改动

### 工作流

**两态模型**:
本 skill 规定的唯一工作流。**写作态**：写新代码时，游标停在一个已声明意图的节点上（`jj new` → 立刻 `describe -m`）。**修正态**：一切对已有提交的修正走显式寻址，游标不动。判入口是"我在写新东西，还是在修已有的？"
_Avoid_: Style A/B、双风格

**落地判据**:
宣布完成前必须成立的**二值可观测状态**（从 DAG 上读出），而非"跑过某命令"这种动作。
_Avoid_: 验证步骤、check

**自动重建历史**:
重写一个提交后，它的所有后代自动跟着重建（descendant auto-rebase）。使"回去修一个旧提交"成为常规操作而非手术。
_Avoid_: 自动 rebase、auto-rebase

**稳定 change ID**:
change 的字母 ID 跨重写保持不变；commit ID(hex) 每次重写都换。使"先建 bookmark 再干活"和"引用某个提交"安全。
_Avoid_: change 编号、commit hash

**随意切换 working copy**:
跳到任意提交继续工作，不需要 stash，不会有 checkout 冲突。
_Avoid_: 切分支、checkout
