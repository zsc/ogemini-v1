(本文档持续用中文更新)

# OGemini - OCaml 重写 Gemini-cli 项目

## 项目目标
我们希望用 OCaml 重写 Gemini-cli，作为后续扩展的基础。
不需要兼容 Gemini-cli。先出一个能运行的 MVP。

**📅 当前状态**: Phase 5.1.1 重大突破 - 修复 OCaml Str 模块全局状态干扰，自主 Agent 现已能正确创建文件和执行多步骤任务。

## 📊 项目进展概览

### ✅ 已完成 Phases
- **Phase 1** ✅: 事件驱动对话引擎 - 基础 API 集成和用户界面
- **Phase 2** ✅: 工具系统 - 文件操作、Shell 执行、构建工具集成
- **Phase 3** ✅: Docker 容器化 - 安全隔离的执行环境
- **Phase 4** ✅: 自主 Agent 认知架构 - 基础自主认知循环
- **Phase 5.1.1** ✅: 计划解析器精度改进 - LLM 驱动解析，鲁棒错误处理
- **Phase 5.1.2** ✅: 智能 dune 文件生成 - 项目类型检测，LLM 生成配置

### 🎯 当前目标
- **Phase 5.1.3** 🔄: 智能项目结构推理 - 基于项目类型生成合适的目录结构
- **Phase 5.2** 🎯: 编译错误自动修复 - 结构化错误解析和自动代码修正

## ✅ 系统健康状态 - 已验证工作正常！

**重要提醒给未来的维护者**：系统目前完全正常工作，包括 Docker 容器化环境。如果遇到问题，请先运行基础回归测试。

### 🐳 Docker 容器化部署状态 - ✅ 生产就绪

**关键配置发现**：
- **代理设置**：Docker 容器内必须使用 `192.168.3.196:7890` 而非 `127.0.0.1:7890`
- **目录映射**：使用 `-v "$(pwd):/ogemini-src"` 映射源码，`--env-file .env` 加载环境
- **构建方式**：使用 `dune exec bin/main.exe` 确保容器内新鲜编译，避免二进制兼容性问题
- **工作模式**：基于 `ogemini-base:latest` 镜像，实时编译运行

### 🧪 完整回归测试套件
每当进行重大代码更改后，**必须**运行这些测试以确保核心功能正常：

#### 🐳 Docker 容器化回归测试（推荐）
```bash
# 完整 Docker 环境回归测试 - 包含构建、Q&A、工具调用
./scripts/test-docker-regression.sh

# 预期输出：
🎉 DOCKER CONTAINER BUILD REGRESSION TEST PASSED
✅ Container build: Working
✅ Basic Q&A: Working  
✅ Tool system: Working
✅ API integration: Working
```

#### 🤖 自主 Agent 测试
```bash
# 交互式自主 Agent 测试 - Docker 环境中的完整自主能力
./scripts/run-autonomous-docker.sh

# 快速自主能力验证
./scripts/test-autonomous-docker.sh

# 综合场景测试 - 多种复杂任务验证
./scripts/test-autonomous-scenarios.sh

# 预期行为：
🤖 自主模式启动 → 🧠 目标规划 → ⚡ 多步执行 → 🔍 结果评估
```

⚠️ **重要：自主 Agent 测试限制**
- **仅在 Docker 中测试自主 Agent** - 本地测试可能产生不可预测的文件操作
- **安全隔离原则** - 自主 Agent 具备文件创建和修改能力，必须在容器环境中运行
- **标准测试流程** - 使用 `./scripts/test-autonomous-docker.sh` 进行验证

⚠️ **重要：代码质量原则**
- **未使用变量警告不可忽略** - unused variable 警告往往反映信息流断裂问题
- **修复根本原因而非消除警告** - 应分析为什么变量未被使用，是否缺少逻辑连接
- **信息流完整性** - 确保提取的数据被正确使用，避免数据丢失

#### 🧮 基础功能测试
```bash
# 基础Q&A测试（无工具）
./scripts/test-basic-docker.sh

# 工具调用测试（智能检测）
./scripts/test-tool-docker.sh
```

### 🔧 智能工具检测功能
- **Phase 3.1 新增**：智能检测何时需要工具调用
- 简单数学、对话：无工具声明，干净请求
- 文件操作、项目任务：自动包含工具声明
- 避免了之前"JSON parse error: Blank input data"问题

## 📋 Phase 5: 实战化自主开发能力

**Phase 5 目标**: 从基础认知架构转向真实项目开发能力，实现端到端的自主开发流程。

### 🎯 核心理念调整
基于对 gemini-cli 深入分析，Phase 5 从"预定义结构化组件"转向"LLM 驱动的智能决策"：
- ❌ **避免**: 预定义模板、固定解析器、硬编码策略
- ✅ **采用**: LLM 智能分析、上下文理解、动态决策
- 📋 **借鉴**: gemini-cli 的 editCorrector、NextSpeakerChecker、递归执行循环

### 🎯 Phase 5 分阶段实施计划

#### Phase 5.1: 项目文件生成稳定化 (🔧 核心基础)
**目标**: 稳定可靠地生成 OCaml 项目结构和 dune 配置文件

**当前痛点分析**:
- ⚠️ **计划解析精度不足**: 从 LLM 响应中提取的文件名和内容经常有误（如 `hello.ml` 变成 `\`hello.ml\``）
- ⚠️ **dune 文件生成缺失**: 当前 Agent 不会自动创建正确的 dune-project 和 bin/dune 配置
- ⚠️ **项目结构推理简单**: 无法根据项目需求智能生成合适的目录和模块结构

**实施步骤**:
- **5.1.1** ✅: 改进 plan parser 精度 - 准确提取文件名、路径、内容参数
- **5.1.2** ✅: 增强 dune 文件生成 - 正确的依赖关系和模块配置
- **5.1.3**: 智能项目结构推理 - 基于项目类型生成合适的目录结构
- **5.1.4**: 文件内容模板化 - 预设常用 OCaml 代码模板和最佳实践

**Phase 5.1.1 重大突破总结** ✅:
- ✅ **OCaml Str 模块修复**: 发现并修复 `Str` 全局状态干扰导致工具名解析错误 (`write_file` → `TOOL_CAL`)
- ✅ **即时捕获模式**: 实现正则表达式匹配后立即捕获结果，避免后续 `Str` 操作污染全局状态
- ✅ **文件创建功能**: 自主 Agent 现在能实际创建文件 (`hello.ml`, `dune`) 而非仅执行 `list_files`
- ✅ **智能 dune 生成**: LLM 驱动的项目配置生成正常工作，自动检测项目类型
- ✅ **端到端验证**: 完整自主工作流程从规划到文件创建全部正常，为 Phase 5.2 构建错误修复奠定基础
- 📋 **详细文档**: 完整技术分析记录在 `/docs/phase5-1-1-breakthrough.md`

**Phase 5.1.2 实现总结** ✅:
- ✅ **项目类型检测**: 实现 `/lib/dune_generator.ml` - 自动检测 SimpleExecutable、Library、GameProject 等类型
- ✅ **LLM 智能生成**: 基于项目类型和描述，使用 LLM 生成合适的 dune-project 和 dune 配置
- ✅ **智能增强**: 在 `write_file` 操作中自动检测 dune 文件并增强为智能生成的配置
- ✅ **依赖推理**: 根据项目类型自动推荐合适的 OCaml 库依赖（如游戏项目使用 graphics、Web 项目使用 lwt）

#### Phase 5.2: 编译错误智能修复 (🚀 核心能力)  
**目标**: 根据 dune build 错误输出自主诊断和修复 OCaml 代码

**核心挑战**:
- 🔍 **错误解析**: 结构化理解 dune/ocamlc 的复杂错误输出
- 🧠 **智能诊断**: 区分语法错误、类型错误、模块错误、依赖错误
- 🔧 **自动修复**: 生成正确的代码修正并验证
- 🔄 **迭代优化**: build→analyze→fix→rebuild 自主循环直到成功

**实施步骤**:
- **5.2.1**: 编译错误解析器 - 结构化解析 dune/ocamlc 错误信息
- **5.2.2**: 错误分类和诊断 - 识别语法、类型、模块、依赖等不同错误类型
- **5.2.3**: 自动修复策略 - 针对常见错误的自动代码修正
- **5.2.4**: 迭代构建循环 - build→analyze→fix→rebuild 自主循环

#### Phase 5.3: OCaml 2048 端到端实现 (🎯 实战验证)
**目标**: 完整从 Python 到 OCaml 的项目翻译，验证自主开发能力

**验证场景**: 基于 `toy_projects/ocaml_2048/game.py` 的完整翻译项目
- 📋 **需求明确**: GEMINI.md 中已定义"Translate game.py to OCaml with bit-level agreement"
- 🎮 **复杂度适中**: 2048 游戏逻辑完整但不过于复杂，适合验证自主能力
- 🔬 **可测试性强**: 可以通过运行游戏验证翻译正确性

**实施步骤**:
- **5.3.1**: Python 代码分析 - 理解游戏逻辑、数据结构、算法
- **5.3.2**: OCaml 架构设计 - 函数式编程模式的重新设计
- **5.3.3**: 分模块实现 - 逐步实现游戏核心、I/O、主循环
- **5.3.4**: 测试和优化 - 自主测试、性能优化、bug 修复

### 🎯 Phase 5 成功标准

**端到端自主开发测试**:
```bash
# 启动自主模式
./scripts/run-autonomous-docker.sh

# 输入高级需求
> "Translate the Python 2048 game in toy_projects/ocaml_2048/game.py to OCaml, maintaining the bit-level logic"

# 期望自主行为序列
🤖 分析 Python 代码 → 📋 设计 OCaml 架构 → 🏗️ 创建项目文件 → 
🔧 实现核心逻辑 → ⚠️ 修复编译错误 → ✅ 构建成功 → 🎮 功能验证
```

**量化成功指标**:
- ✅ **项目创建**: 自动生成正确的 dune-project、bin/dune、lib/dune 配置
- ✅ **代码翻译**: Python 核心逻辑正确转换为 OCaml 函数式风格
- ✅ **编译成功**: 自主修复所有编译错误，最终 `dune build` 通过
- ✅ **功能验证**: 翻译后的 OCaml 游戏可以正常运行

**实施优先级**: 5.1 → 5.2 → 5.3 (线性依赖，每个阶段为下一阶段提供基础能力)

### Phase 5.1: LLM 驱动的智能项目理解 (🔧 核心基础)
**目标**: 对标 gemini-cli 的智能分析能力，通过 LLM 理解项目结构而非预定义模板
- **5.1.1**: 改进 plan parser 精度 - 准确提取文件名、路径、内容参数（对标 gemini-cli 的 editCorrector）
- **5.1.2**: 增强 LLM 驱动的项目结构推理 - 分析现有项目约定而非预定义模板
- **5.1.3**: 完善系统提示词设计 - 指导 LLM 理解 OCaml 最佳实践和 dune 约定
- **5.1.4**: 智能构建命令推理 - 通过 LLM 分析项目类型并推断正确的构建命令

### Phase 5.2: LLM 驱动的编译错误修复 (🚀 核心能力)  
**目标**: 对标 gemini-cli 的智能错误处理，通过 LLM 分析而非预定义解析器
- **5.2.1**: 基于 shell 工具的构建错误分析 - 使用 LLM 智能分析而非预定义解析器
- **5.2.2**: 迭代错误修复循环 - 通过 LLM 判断而非预定义策略实现 build→analyze→fix
- **5.2.3**: 增强错误上下文理解 - LLM 能够结合编译输出和代码内容提供精准修复
- **5.2.4**: 优化递归执行控制 - 借鉴 gemini-cli 的 NextSpeakerChecker 智能判断何时继续

### Phase 5.3: OCaml 2048 端到端实现 (🎯 实战验证)
**目标**: 完整从 Python 到 OCaml 的项目翻译，验证 LLM 驱动的自主开发能力
- **5.3.1**: Python 到 OCaml 智能翻译 - 多轮分析游戏逻辑、数据结构、算法
- **5.3.2**: 函数式编程模式重构 - LLM 驱动的架构重新设计而非机械翻译
- **5.3.3**: 端到端项目实现验证 - 完整的自主开发流程测试
- **5.3.4**: 自主测试和验证能力 - LLM 判断功能正确性而非预定义测试套件

### 🎯 成功标准
```bash
# 启动自主模式
./scripts/run-autonomous-docker.sh

# 输入高级需求
> "Translate the Python 2048 game in toy_projects/ocaml_2048/game.py to OCaml, maintaining the bit-level logic"

# 期望自主行为
🤖 分析 Python 代码 → 📋 设计 OCaml 架构 → 🏗️ 创建项目文件 → 
🔧 实现核心逻辑 → ⚠️ 修复编译错误 → ✅ 构建成功 → 🎮 功能验证
```

**实施优先级**: 5.1 → 5.2 → 5.3 (线性依赖，每个阶段为下一阶段提供基础能力)

## 🤖 Phase 4: 自主 Agent 认知架构 - ✅ 基础实现完成

### 实现总结
Phase 4 成功实现了完整的自主认知架构，从受控工具执行模式转变为具备基础自主能力的智能体。

### 已实现功能
- ✅ **认知状态机**：Planning→Executing→Evaluating→Adjusting 循环
- ✅ **目标分解**：LLM 驱动的高级目标到具体步骤的规划
- ✅ **工具编排**：多步骤自主执行，支持顺序/并行策略
- ✅ **错误恢复**：失败诊断和自适应重试机制
- ✅ **对话管理**：智能检测何时进入自主模式
- ✅ **Debug 信息**：完整的执行状态跟踪和反馈

### 测试结果
- ✅ **架构可用**：成功创建 OCaml hello world 项目（5步自主执行）
- ⚠️ **解析精度**：plan parser 需要改进，文件名和内容提取有误
- ⚠️ **实际效果**：基础自主能力已具备，但距离真正可用还需优化

### 当前限制
- 📋 **计划解析**：从 LLM 响应提取准确工具调用参数仍需改进
- 📋 **上下文理解**：需要更好地利用对话历史和项目上下文
- 📋 **复杂任务**：多步骤复杂工作流的鲁棒性有待验证
- 📋 **错误处理**：需要更智能的失败恢复和策略调整

### Phase 4 核心组件

#### 🧠 认知引擎 (lib/cognitive_engine.ml)
- **认知状态机**：完整的 Planning→Executing→Evaluating→Adjusting 循环
- **目标分解**：LLM 驱动的高级目标到执行步骤的规划
- **计划解析**：从自然语言响应提取可执行的工具调用
- **上下文管理**：利用对话历史增强规划能力

#### 🔧 工具编排器 (lib/tool_orchestrator.ml)  
- **执行策略**：支持顺序、并行、条件执行模式
- **自适应重试**：智能失败恢复和替代策略
- **进度监控**：实时执行状态跟踪和反馈
- **策略选择**：基于任务类型自动选择最优执行策略

#### 💬 对话管理器 (lib/conversation_manager.ml)
- **模式检测**：自动识别何时进入自主模式 (UserDriven vs AgentDriven)
- **中断处理**：优雅处理用户中断和模式切换
- **状态通信**：实时状态更新和用户反馈

#### 🔄 自主主循环 (bin/main_autonomous.exe)
- **双模式支持**：传统响应模式 + 自主执行模式
- **智能切换**：基于用户输入自动判断执行模式
- **Docker 集成**：在安全容器环境中运行

## 🏗️ 技术架构

### 核心数据结构 (lib/types.ml)
```ocaml
(* 认知状态机 *)
type cognitive_state = 
  | Planning of { goal: string; context: string list; }
  | Executing of { plan: action list; current_step: int; results: simple_tool_result list; }
  | Evaluating of { results: simple_tool_result list; success: bool; failures: failure_mode list; }
  | Adjusting of { failures: failure_mode list; new_plan: action list; }
  | Completed of { summary: string; final_results: simple_tool_result list; }

(* 工具调用动作 *)
type action = 
  | ToolCall of { name: string; args: (string * string) list; rationale: string }
  | Wait of { reason: string; duration: float }
  | UserInteraction of { prompt: string; expected_response: string }

(* 执行策略 *)
type execution_strategy = 
  | Sequential of action list
  | Parallel of action list  
  | Conditional of { condition: tool_result -> bool; if_true: action list; if_false: action list }
```

### 工具系统 (lib/tools/)
- **file_tools.ml**: 文件读写和目录列表
- **shell_tools.ml**: 安全的命令执行（白名单机制）
- **build_tools.ml**: dune build/test/clean 集成

### Event 驱动架构 (lib/event_parser.ml)
```ocaml
type event_type = 
  | Content of string                
  | Thought of thought_summary       
  | ToolCallRequest of tool_call_info 
  | ToolCallResponse of tool_result   
  | LoopDetected of string           
  | Error of string                  
```

## 📂 项目结构和导航
```
🏠 /Users/zsc/Downloads/ogemini/  ← ROOT DIRECTORY (工作目录)
├── 📄 .env                      ← API 密钥配置
├── 📄 CLAUDE.md                 ← 项目文档 (本文件)
├── 📄 dune-project              ← Dune 项目配置
├── 📁 bin/                      
│   ├── dune
│   ├── main.ml                  ← 传统对话模式入口
│   └── main_autonomous.ml       ← 自主 Agent 模式入口
├── 📁 lib/                      ← 核心库
│   ├── types.ml                 ← 数据类型定义
│   ├── config.ml                ← 配置管理
│   ├── event_parser.ml          ← 事件解析
│   ├── api_client.ml            ← API 客户端
│   ├── ui.ml                    ← 用户界面
│   ├── cognitive_engine.ml      ← 认知引擎 (Phase 4)
│   ├── tool_orchestrator.ml     ← 工具编排器 (Phase 4)
│   ├── conversation_manager.ml  ← 对话管理器 (Phase 4)
│   └── tools/                   ← 工具模块
│       ├── file_tools.ml        ← 文件操作工具
│       ├── shell_tools.ml       ← Shell 执行工具
│       └── build_tools.ml       ← 构建工具
├── 📁 scripts/                  ← 测试和运行脚本
│   ├── test-docker-regression.sh        ← 完整回归测试
│   ├── test-basic-docker.sh             ← 基础Q&A测试
│   ├── test-tool-docker.sh              ← 工具调用测试
│   ├── run-autonomous-docker.sh         ← 交互式自主模式
│   ├── test-autonomous-docker.sh        ← 自主能力验证
│   └── test-autonomous-scenarios.sh     ← 综合场景测试
├── 📁 toy_projects/             ← 测试项目
│   └── ocaml_2048/              ← 2048 游戏项目 (Phase 5 目标)
│       ├── GEMINI.md            ← 项目目标
│       └── game.py              ← Python 源码
└── 📁 gemini-cli/               ← 参考实现

🚀 执行命令 (从 ROOT 执行):
- ./scripts/run-autonomous-docker.sh    ← 🤖 启动自主 Agent (推荐)
- ./scripts/docker-simple.sh           ← 🐳 传统对话模式
- dune build                            ← 本地构建 (仅 macOS)
- dune exec ./bin/main.exe              ← 本地运行 (仅 macOS)

🧪 回归测试命令:
- ./scripts/test-docker-regression.sh  ← 🐳 完整回归测试 (推荐)
- ./scripts/test-autonomous-scenarios.sh ← 🤖 自主能力综合测试

🐳 Docker 管理命令:
- ./scripts/docker-simple.sh    ← 构建并运行
- ./scripts/docker-cleanup.sh   ← 清理旧镜像和缓存
```

### ⚠️ 重要配置提醒

**Docker 代理设置 (必须)**:
```bash
-e https_proxy=http://192.168.3.196:7890 \
-e http_proxy=http://192.168.3.196:7890 \
-e all_proxy=socks5://192.168.3.196:7890 \
```

**环境变量 (必须)**:
- `.env` 文件必须存在并包含 `GEMINI_API_KEY`
- 使用 `--env-file .env` 加载环境变量

**路径修正提醒**:
- 所有 bash 命令前缀 `cd /Users/zsc/Downloads/ogemini`
- macOS 使用 `gtimeout` 而非 `timeout`

## 📊 代码统计

**总代码行数**: 2,167 行

**按模块排序**（前5名）：
1. `lib/cognitive_engine.ml` - 345 行 (🧠 认知引擎)
2. `lib/api_client.ml` - 321 行 (🌐 API 客户端)  
3. `lib/tool_orchestrator.ml` - 224 行 (🔧 工具编排器)
4. `lib/conversation_manager.ml` - 224 行 (💬 对话管理器)
5. `bin/main_autonomous.ml` - 204 行 (🤖 自主主程序)

**代码分布**:
- **Phase 4 自主能力**: 1,197 行 (55%)
- **核心基础设施**: 651 行 (30%) 
- **工具系统**: 306 行 (14%)
- **主程序**: 121 行 (6%)

## 📚 参考资源
- `gemini-cli/` - 包含完整的 TypeScript 源代码实现
- 分析文档（位于 `gemini-cli/` 目录下）：
  - `structure.md` - 项目结构文档
  - `coreToolScheduler-analysis.md` - 核心工具调度器分析
  - `turn-analysis.md` - 对话回合分析
  - `findings.md` - 代码分析发现
  - `prompts.md` - 提示词相关分析
  
**注意**：以上分析文档仅供参考，实现时以源代码为准。

## 🔮 后续扩展方向
完成 Phase 5 后，可以逐步添加：
1. **Phase 6**: Mock LLM 录制回放系统 - 确定性测试
2. **Phase 7**: 多模型支持 - Claude、GPT-4 等
3. **Phase 8**: 高级工具生态 - Git、Package Manager 等
4. **Phase 9**: 性能优化 - 并发、缓存、流式处理
5. **Phase 10**: 生产级特性 - 监控、日志、安全

## 🏆 项目成就
- ✅ **2,167 行 OCaml 代码** - 完整的自主 Agent 系统
- ✅ **端到端工作流** - 从对话到自主项目开发
- ✅ **Docker 容器化** - 安全隔离的执行环境
- ✅ **智能工具检测** - 自动判断何时使用工具
- ✅ **认知状态机** - 完整的自主决策循环
- ✅ **健壮测试体系** - 多层次回归测试覆盖

**OGemini 已从简单的聊天机器人演进为具备基础自主开发能力的智能 Agent。**

---

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.