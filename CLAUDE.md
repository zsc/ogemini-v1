(本文档持续用中文更新)

# OGemini - OCaml 重写 Gemini-cli 项目

## 项目目标
我们希望用 OCaml 重写 Gemini-cli，作为后续扩展的基础。
不需要兼容 Gemini-cli。先出一个能运行的 MVP。

## 参考资源
- `gemini-cli/` - 包含完整的 TypeScript 源代码实现
- 分析文档（位于 `gemini-cli/` 目录下）：
  - `structure.md` - 项目结构文档
  - `coreToolScheduler-analysis.md` - 核心工具调度器分析
  - `turn-analysis.md` - 对话回合分析
  - `findings.md` - 代码分析发现
  - `prompts.md` - 提示词相关分析
  
**注意**：以上分析文档仅供参考，实现时以源代码为准。

## MVP 规格说明

### Phase 1: Plan-Act 与基础控制

#### 1. 名词（核心数据结构）
```ocaml
(* 配置 *)
type config = {
  api_key: string;
  api_endpoint: string;
  model: string;
  enable_thinking: bool;  (* 是否启用思考模式 *)
}

(* 思考总结 *)
type thought_summary = {
  subject: string;     (* 思考主题 *)
  description: string; (* 思考描述 *)
}

(* 事件类型 - 对应 gemini-cli 的事件系统 *)
type event_type = 
  | Content of string
  | ToolCallRequest of string  (* 工具调用请求 *)
  | ToolCallResponse of string (* 工具调用响应 *)
  | Thought of thought_summary (* 思考过程 *)
  | LoopDetected of string     (* 循环检测 *)
  | Error of string

(* 消息 *)
type message = {
  role: string;  (* "user" | "assistant" | "system" *)
  content: string;
  events: event_type list;  (* 消息包含的事件 *)
  timestamp: float;
}

(* 对话历史 *)
type conversation = message list

(* 循环检测状态 - 基于 gemini-cli 的三种检测方式 *)
type loop_state = {
  recent_tool_calls: string list;   (* 最近的工具调用 *)
  recent_content: string list;      (* 最近的内容片段 *)
  tool_loop_count: int;             (* 工具循环计数 *)
  content_loop_count: int;          (* 内容循环计数 *)
}

(* 继续判断状态 *)
type continuation_state = 
  | UserSpeaksNext      (* 用户发言 *)
  | AssistantContinues  (* 助手继续 *)
  | Finished            (* 对话结束 *)

(* API 响应 *)
type response = 
  | Success of message
  | Error of string
```

#### 2. 动词（核心操作）
```ocaml
(* 事件解析和处理 *)
val parse_response : string -> event_type list  (* 解析 API 响应为事件列表 *)
val parse_thought : string -> thought_summary option  (* 解析思考内容 *)
val format_events : event_type list -> string

(* 循环检测 - 基于 gemini-cli 的三层检测 *)
val detect_tool_loop : loop_state -> string -> bool * loop_state
val detect_content_loop : loop_state -> string -> bool * loop_state
val detect_cognitive_loop : config -> conversation -> bool Lwt.t  (* LLM 检测 *)
val break_loop : conversation -> string  (* 生成打破循环的提示 *)

(* 继续判断 - 基于 nextSpeakerChecker 逻辑 *)
val determine_next_speaker : config -> conversation -> continuation_state Lwt.t
val should_assistant_continue : message -> bool

(* 对话管理 *)
val add_message : conversation -> message -> conversation
val build_prompt : conversation -> config -> string
val compress_conversation : config -> conversation -> conversation Lwt.t  (* 上下文压缩 *)

(* 事件处理 *)
val process_event_stream : string -> event_type list  (* 流式事件处理 *)
val handle_thought : thought_summary -> unit
val handle_content : string -> unit
```

#### 3. 引擎（核心循环）
```ocaml
(* 主循环：事件驱动的对话管理 *)
let rec chat_loop config conversation loop_state =
  (* 智能判断下一个发言者 *)
  let%lwt next_speaker = determine_next_speaker config conversation in
  match next_speaker with
  
  | UserSpeaksNext ->
      (* 等待用户输入 *)
      begin match read_input () with
      | None | Some "exit" | Some "quit" -> Lwt.return ()
      | Some input ->
          let user_msg = create_user_message input in
          let new_conv = add_message conversation user_msg in
          chat_loop config new_conv loop_state
      end
      
  | AssistantContinues ->
      (* AI 生成响应 *)
      let%lwt response = send_message config conversation in
      match response with
      | Success msg ->
          (* 处理事件流 *)
          List.iter (function
            | Thought thought -> handle_thought thought
            | Content content -> handle_content content
            | ToolCallRequest req -> (* Phase 2 处理 *)
            | ToolCallResponse resp -> (* Phase 2 处理 *)
            | LoopDetected reason -> Printf.printf "Loop detected: %s\n" reason
            | Error err -> Printf.printf "Error: %s\n" err
          ) msg.events;
          
          (* 多层循环检测 *)
          let content = String.concat " " (List.map format_events msg.events) in
          let%lwt cognitive_loop = detect_cognitive_loop config conversation in
          let tool_loop, new_loop_state1 = detect_tool_loop loop_state content in
          let content_loop, new_loop_state2 = detect_content_loop new_loop_state1 content in
          
          if cognitive_loop || tool_loop || content_loop then
            (* 注入循环中断消息 *)
            let break_msg = create_system_message (break_loop conversation) in
            let conv_with_break = add_message conversation break_msg in
            chat_loop config conv_with_break new_loop_state2
          else
            (* 正常流程继续 *)
            let new_conv = add_message conversation msg in
            chat_loop config new_conv new_loop_state2
            
      | Error err ->
          Printf.printf "API Error: %s\n" err;
          chat_loop config conversation loop_state
          
  | Finished ->
      (* 对话自然结束 *)
      Lwt.return ()

(* 流式事件处理辅助函数 *)
let process_streaming_response config conversation callback =
  let%lwt response_stream = send_message_stream config conversation in
  Lwt_stream.iter_s (fun chunk ->
    let events = process_event_stream chunk in
    List.iter callback events;
    Lwt.return ()
  ) response_stream
```

### Phase 2: 工具系统

#### 1. 新增名词
```ocaml
(* 工具定义 *)
type tool = 
  | Grep of { pattern: string; path: string option }
  | Find of { name: string; path: string }
  | Ls of { path: string }
  | ReadFile of { path: string }
  | WriteFile of { path: string; content: string }
  | Patch of { file: string; patch: string }
  | FixPatch of { file: string; patch: string }

(* 工具结果 *)
type tool_result = 
  | ToolSuccess of string
  | ToolError of string

(* 扩展动作类型 *)
type action = 
  | Plan of string list
  | Act of string
  | Think of string
  | UseTool of tool  (* 新增 *)
```

#### 2. 新增动词
```ocaml
(* 工具执行 *)
val execute_tool : tool -> tool_result Lwt.t

(* 工具相关 *)
val parse_tool_request : string -> tool option
val format_tool_result : tool_result -> string

(* 具体工具实现 *)
val grep : pattern:string -> ?path:string -> unit -> string Lwt.t
val find : name:string -> path:string -> string list Lwt.t
val ls : path:string -> string list Lwt.t
val read_file : path:string -> string Lwt.t
val write_file : path:string -> content:string -> unit Lwt.t
val apply_patch : file:string -> patch:string -> unit Lwt.t
val fix_patch : file:string -> patch:string -> string Lwt.t
```

### 实现优先级

#### Phase 1 (事件驱动对话引擎) - ✅ 已完成

- [x] **1. 项目初始化**
  - [x] 创建 dune-project 文件
  - [x] 创建基本目录结构 (bin/, lib/)
  - [x] 配置 .gitignore 和 .ocamlformat
  - [x] 添加必要依赖：lwt, yojson, re, unix

- [x] **2. 核心数据结构** (lib/types.ml)
  - [x] 定义 config 类型（包含 enable_thinking）
  - [x] 定义 thought_summary 类型
  - [x] 定义 event_type 变体类型（Content, Thought, ToolCall 等）
  - [x] 定义 message 类型（包含 events 和 timestamp）
  - [x] 定义 conversation 和 loop_state 类型
  - [x] 定义 continuation_state 类型

- [x] **3. 配置管理** (lib/config.ml)
  - [x] 实现 load_config 函数（环境变量 + 默认值）
  - [x] 支持 thinking 模式配置
  - [x] 添加配置验证和错误处理

- [x] **4. 事件解析器** (lib/event_parser.ml)
  - [x] 实现 parse_response 解析 API 响应为事件列表
  - [x] 实现 parse_thought 解析思考内容（**主题** 描述格式）
  - [x] 实现 process_event_stream 流式事件处理
  - [x] 实现 format_events 格式化事件输出

- [x] **5. API 客户端** (lib/api_client.ml)
  - [x] 实现 HTTP 请求基础设施（使用 curl 临时方案）
  - [x] 支持 Gemini 2.5 Flash API 调用
  - [x] 实现 send_message 核心功能
  - [x] 实现 JSON 请求构建和响应解析
  - [x] 添加基础错误处理

- [x] **6. 用户界面** (lib/ui.ml)
  - [x] 实现 read_input 用户输入处理
  - [x] 实现实时事件显示（思考过程、内容生成）
  - [x] 实现 print_welcome 和状态指示器
  - [x] 实现打字机效果和彩色输出

- [x] **7. 主程序引擎** (bin/main.ml)
  - [x] 实现基础 chat_loop
  - [x] 集成配置管理和 API 调用
  - [x] 添加错误处理和优雅退出
  - [x] 完整的事件处理流程

- [x] **8. 测试与验证**
  - [x] 端到端测试：完整对话流程
  - [x] 真实 API 调用验证
  - [x] 用户界面交互测试
  - [x] 配置加载和错误处理测试

### Phase 1 成果总结

🎉 **MVP 成功运行！** 实现了完整的事件驱动对话引擎：

**✅ 核心功能**
- 完整的 Dune 项目架构
- Gemini API 集成（支持 2.5 Flash）
- 事件驱动的消息处理
- 思考模式解析和显示
- 用户友好的界面交互
- 配置管理和错误处理

**✅ 技术特性**
- 类型安全的 OCaml 实现
- 异步 HTTP 调用（Lwt）
- JSON 处理（Yojson）
- 正则表达式解析（Re）
- 打字机效果和彩色输出

**✅ 运行演示**
```bash
source .env && dune exec ./bin/main.exe
# 成功启动，支持实时对话
```

### 待实现功能（Phase 2+）
- [ ] 循环检测系统 (lib/loop_detector.ml)
- [ ] 智能对话控制 (lib/conversation.ml)  
- [ ] 工具系统集成
- [ ] 流式输出优化
- [ ] 上下文压缩

#### Phase 2 (项目感知工具系统) - MVP 规格

### 核心工作流程
OGemini 的典型使用场景：
1. **项目初始化**：`cd toy_projects/ocaml_2048/` 
2. **规格驱动**：读取 `GEMINI.md` 了解项目目标
3. **上下文感知**：分析项目文件结构和现有代码
4. **迭代开发**：响应用户命令，执行 LLM 推理和文件操作
5. **保持活跃**：在项目目录内持续工作

### Phase 2 MVP 功能

#### 1. 项目上下文管理
```ocaml
(* 项目状态 *)
type project_context = {
  root_dir: string;                    (* 项目根目录 *)
  spec_file: string option;            (* GEMINI.md 路径 *)
  spec_content: string;                (* 项目规格内容 *)
  file_tree: string list;              (* 文件结构缓存 *)
  modified_files: string list;         (* 已修改文件列表 *)
}

(* 项目感知的工具调用 *)
type context_aware_tool = 
  | ReadProjectFile of { path: string }           (* 读取项目文件 *)
  | WriteProjectFile of { path: string; content: string }  (* 写入项目文件 *)
  | SearchInProject of { pattern: string; scope: string option }  (* 项目内搜索 *)
  | AnalyzeProjectStructure                        (* 分析项目结构 *)
  | LoadProjectSpec                                (* 加载 GEMINI.md *)
```

#### 2. 增强的工具系统
```ocaml
(* 基础文件操作 - 项目感知 *)
val read_file : project_context -> string -> string Lwt.t
val write_file : project_context -> string -> string -> unit Lwt.t
val ls_project : project_context -> string option -> string list Lwt.t

(* 搜索工具 - 项目范围 *)
val grep_in_project : project_context -> string -> string option -> string list Lwt.t
val find_files : project_context -> string -> string list Lwt.t

(* 代码分析工具 *)
val analyze_code_structure : project_context -> string -> string Lwt.t
val detect_language : project_context -> string -> string option Lwt.t
```

#### 3. 智能对话增强
```ocaml
(* 上下文感知的对话 *)
val build_context_prompt : project_context -> conversation -> string
val should_use_project_context : message -> bool
val extract_file_references : string -> string list  (* 提取 @file 引用 *)

(* 项目状态管理 *)
val init_project_context : string -> project_context Lwt.t
val update_project_context : project_context -> string -> project_context
val save_project_state : project_context -> unit Lwt.t
```

#### 4. 工作目录支持
```ocaml
(* 启动方式 *)
let start_with_project dir =
  let* context = init_project_context dir in
  match context.spec_file with
  | Some spec_path ->
      Printf.printf "📁 Project: %s\n" dir;
      Printf.printf "📋 Spec: %s\n" spec_path;
      Printf.printf "🎯 Goal: %s\n" (extract_goal context.spec_content);
      chat_loop_with_context config [] loop_state context
  | None ->
      Printf.printf "⚠️ No GEMINI.md found, starting basic mode\n";
      chat_loop config [] loop_state
```

### Phase 2 实现优先级

1. **项目上下文管理** (lib/project_context.ml)
   - 目录扫描和文件树构建
   - GEMINI.md 解析和缓存
   - 项目状态持久化

2. **增强工具系统** (lib/tools.ml)
   - 项目感知的文件操作
   - 上下文范围的搜索
   - 代码结构分析

3. **智能提示构建** (lib/context_prompt.ml) 
   - 自动包含相关文件内容
   - 项目规格集成
   - @file 引用解析

4. **工作流集成** (bin/main.ml)
   - 命令行参数支持 `ogemini ./toy_projects/ocaml_2048/`
   - 项目模式 vs 普通模式
   - 智能文件监控

### 示例使用场景

```bash
# 启动项目模式
cd toy_projects/ocaml_2048
ogemini .

# 或者直接指定项目
ogemini ./toy_projects/ocaml_2048/

# 项目内的典型对话
👤 You: Help me translate the Game2048 class to OCaml
🤖 Assistant: I can see from GEMINI.md that you want to translate game.py to OCaml with bit-level agreement. Let me analyze the existing Python implementation...

[自动读取 game.py，分析代码结构，生成 OCaml 版本]
```

## 开发原则
1. **循序渐进，小步快跑**：每次只实现一个小功能，确保可编译运行
2. **持续构建**：每个步骤都通过 `dune build` 和 `dune exec` 验证
3. **模块化设计**：遵循 OCaml 最佳实践，保持代码清晰可维护

## Event_Type 系统概述

事件系统将复杂的AI交互（思考过程、工具调用、流式输出、错误恢复、循环检测）分解为可管理的原子事件。

### 核心设计

```ocaml
(* 主要事件类型 *)
type event_type = 
  | Content of string                (* 文本内容 *)
  | Thought of thought_summary       (* AI思考过程 *)
  | ToolCallRequest of tool_call_info (* 工具调用请求 *)
  | ToolCallResponse of tool_result   (* 工具执行结果 *)
  | LoopDetected of string           (* 循环检测 *)
  | Error of string                  (* 错误信息 *)

(* 事件处理流程：解析 -> 派发 -> 处理 -> 显示 *)
val parse_response : string -> event_type list
val dispatch_event : event_type -> unit Lwt.t
val handle_event : event_type -> unit Lwt.t
```

### 关键特性

1. **实时处理**：流式解析API响应，即时显示思考和内容
2. **优雅错误处理**：可恢复的错误分类和用户友好提示
3. **工具调用管理**：状态跟踪、用户确认、并发执行
4. **循环检测**：三层检测机制防止AI陷入无限循环
5. **事件优先级**：错误 > 循环检测 > 工具调用 > 思考/内容

## MVP 技术栈
- **构建系统**：Dune
- **HTTP 客户端**：Cohttp-lwt（用于调用 Gemini API）
- **JSON 处理**：Yojson（解析 API 响应）
- **异步处理**：Lwt（处理 HTTP 请求）
- **事件处理**：自定义事件系统（参考上述设计）

## 项目结构
```
ogemini/
├── dune-project          # Dune 项目配置
├── .env                  # API 密钥配置
├── .gitignore           # Git 忽略文件
├── .ocamlformat         # OCaml 格式化配置
├── bin/
│   ├── dune            # 可执行文件构建配置
│   └── main.ml         # 程序入口点
├── lib/
│   ├── dune            # 库构建配置
│   ├── types.ml        # 核心数据类型定义
│   ├── config.ml       # 配置管理模块
│   ├── event_parser.ml # 事件解析和格式化
│   ├── api_client.ml   # Gemini API 客户端
│   └── ui.ml           # 用户界面和交互
├── ref_docs/
│   └── call_gemini.md  # API 调用参考文档
├── gemini-cli/         # 原始 TypeScript 实现（参考）
└── CLAUDE.md           # 项目文档
```

## 后续扩展方向
完成 MVP 后，可以逐步添加：
1. 工具系统（文件操作、命令执行等）
2. 流式输出支持
3. 会话历史管理
4. 更丰富的 UI
5. 多模型支持
