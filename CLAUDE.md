(本文档持续用中文更新)

# OGemini - OCaml 重写 Gemini-cli 项目

## 项目目标
我们希望用 OCaml 重写 Gemini-cli，作为后续扩展的基础。
不需要兼容 Gemini-cli。先出一个能运行的 MVP。

**📅 当前状态**: Phase 3.1 完成 - Docker 安全环境 + 自动工具执行！

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

### Phase 2: 工具系统（已更新 - 见下方新规格）

**注意**: 这个设计已被废弃，请参考下方 "Phase 2 (基于 gemini-cli 架构的工具系统)" 部分的最新规格。

#### 原始简化设计（已废弃）
```ocaml
(* 这个简化设计不符合 gemini-cli 的真实架构 *)
type tool = 
  | Grep of { pattern: string; path: string option }
  | ReadFile of { path: string }
  | WriteFile of { path: string; content: string }

(* 实际的 gemini-cli 使用面向对象的 Tool 接口和复杂的确认系统 *)
```

**重要**: gemini-cli 使用了更复杂但更强大的工具架构：
- 基于接口的工具定义（TypeScript 接口 → OCaml 类）
- 动态工具注册表系统
- 复杂的用户确认流程
- 状态机管理的工具调用生命周期
- 支持流式输出和中止信号

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

### Phase 2.1 完成功能 - 简化工具系统 ✅

- [x] **工具数据结构** (lib/types.ml)
  - [x] 添加 simple_tool_result, tool_spec, tool_call 类型
  - [x] 扩展 event_type 支持工具调用事件

- [x] **基础工具实现** (lib/tools/file_tools.ml)
  - [x] read_file - 文件读取工具（无需确认）
  - [x] write_file - 文件写入工具（需要确认）
  - [x] list_files - 目录列表工具（无需确认）

- [x] **工具执行** (bin/main.ml)
  - [x] 简单的工具调用分发
  - [x] 基础错误处理和结果格式化
  - [x] 集成到主循环

- [x] **确认界面** (lib/ui.ml)
  - [x] 简单的 Y/N 确认提示
  - [x] 工具调用显示
  - [x] 结果展示优化

- [x] **API 集成** (lib/api_client.ml)
  - [x] 工具声明发送到 Gemini API
  - [x] 解析 API 响应中的工具调用
  - [x] 工具结果处理

- [x] **事件系统集成**
  - [x] 更新 event_parser.ml 支持工具事件
  - [x] 更新 main.ml 的 chat_loop 处理工具调用
  - [x] 完整的工具调用生命周期

### Phase 2.1 成果总结

🎉 **简化工具系统成功运行！** 实现了完整的工具调用功能：

**✅ 核心功能**
- Gemini 2.0 Flash API 工具集成
- 三个基础文件操作工具（read_file, write_file, list_files）
- 简化的用户确认流程（Y/N）
- 完整的工具调用解析和执行
- 实时工具结果显示

**✅ 技术特性**
- 无 PPX 依赖的简洁实现
- 类型安全的工具调用系统
- 异步工具执行（Lwt）
- JSON 工具调用解析
- 事件驱动的架构

**✅ 验证结果**
```bash
👤 You: Can you list files in the current directory?
🤖 Assistant: [自动调用 list_files 工具]
⚡ Auto-executing safe tool...
✅ Tool result: [显示目录内容]
```

**✅ 架构设计**
- 简化的数据结构（避免复杂类系统）
- 模块化的工具实现
- 清晰的确认流程
- 完整的错误处理

### Phase 2.2 工作进展

**设计更新** - 基于 gemini-cli 真实架构分析：
- ✅ 确认工具调用为独立事件（非序列）
- ✅ 添加 shell 执行工具（安全白名单）
- ✅ 添加构建工具（dune_build, dune_test, dune_clean）
- ✅ 修复 JSON 解析中的 shell 转义问题
- ✅ 增强状态消息（"🤔 Thinking...", "🔧 Processing..."）

**实现状态**：
- ✅ Shell 工具（安全命令白名单）
- ✅ 构建工具（dune 集成）  
- ✅ API 集成（所有新工具已添加到 function_declarations）
- ✅ JSON 解析修复（使用临时文件避免转义问题）
- ✅ 增强错误处理和用户反馈

**待验证**：
- 🔄 在 toy_projects/ocaml_2048 中实际测试完整工作流程
- 🔄 确认代理能正确创建和构建 OCaml 项目

### Phase 2+ 长期功能
- [ ] 循环检测系统 (lib/loop_detector.ml)
- [ ] 智能对话控制 (lib/conversation.ml)  
- [ ] 流式输出优化
- [ ] 上下文压缩
- [ ] Phase 2.2 完整工具系统

#### Phase 2 (基于 gemini-cli 架构的工具系统) - MVP 规格

**重要更新**: 基于对 gemini-cli 真实架构的深入分析，Phase 2 规格已完全重写以符合原始实现的设计模式。

### 核心架构对齐

#### 1. 精确的工具接口系统
```ocaml
(* 基于深入分析的完整工具接口 *)

(* 工具结果 - 对应 ToolResult *)
type tool_result = {
  summary: string option;                    (* 可选的简短摘要 *)
  llm_content: string;                      (* 给 LLM 的内容 *)
  return_display: tool_result_display;      (* 用户显示内容 *)
}

and tool_result_display = 
  | StringDisplay of string                 (* 简单字符串显示 *)
  | FileDiffDisplay of {                    (* 文件差异显示 *)
      file_diff: string;
      file_name: string;
      original_content: string option;
      new_content: string;
    }

(* 工具位置信息 *)
type tool_location = {
  path: string;                            (* 绝对文件路径 *)
  line: int option;                        (* 可选行号 *)
}

(* 确认结果枚举 - 对应 ToolConfirmationOutcome *)
type tool_confirmation_outcome = 
  | ProceedOnce                            (* 仅此次执行 *)
  | ProceedAlways                          (* 总是允许此类操作 *)
  | ProceedAlwaysServer                    (* 总是允许此服务器 *)
  | ProceedAlwaysTool                      (* 总是允许此工具 *)
  | ModifyWithEditor                       (* 用编辑器修改 *)
  | Cancel                                 (* 取消操作 *)

(* 确认载荷 - 用于内联修改 *)
type tool_confirmation_payload = {
  new_content: string;                     (* 修改后的内容 *)
}

(* 工具确认详情 - 完整的确认类型系统 *)
type tool_confirmation_details = 
  | EditConfirmation of {
      title: string;
      file_name: string;
      file_diff: string;
      original_content: string option;
      new_content: string;
      is_modifying: bool option;           (* 是否为修改操作 *)
      on_confirm: tool_confirmation_outcome -> tool_confirmation_payload option -> unit Lwt.t;
    }
  | ExecConfirmation of {
      title: string;
      command: string;
      root_command: string;
      on_confirm: tool_confirmation_outcome -> unit Lwt.t;
    }
  | McpConfirmation of {
      title: string;
      server_name: string;
      tool_name: string;
      tool_display_name: string;
      on_confirm: tool_confirmation_outcome -> unit Lwt.t;
    }
  | InfoConfirmation of {
      title: string;
      prompt: string;
      urls: string list option;
      on_confirm: tool_confirmation_outcome -> unit Lwt.t;
    }

(* Icon 枚举 *)
type icon = 
  | FileSearch | Folder | Globe | Hammer 
  | LightBulb | Pencil | Regex | Terminal

(* JSON Schema 类型定义 *)
type json_schema = {
  schema_type: string;                     (* "object", "string", etc. *)
  properties: (string * json_schema) list option;
  required: string list option;
  description: string option;
  items: json_schema option;               (* for arrays *)
}

(* 函数声明 - 对应 FunctionDeclaration *)
type function_declaration = {
  name: string;
  description: string;
  parameters: json_schema;
}

(* 核心工具接口 *)
class virtual base_tool = object
  method virtual name : string
  method virtual display_name : string  
  method virtual description : string
  method virtual icon : icon
  method virtual is_output_markdown : bool
  method virtual can_update_output : bool
  method virtual parameter_schema : json_schema
  
  (* 计算的属性 *)
  method schema : function_declaration = {
    name = self#name;
    description = self#description;
    parameters = self#parameter_schema;
  }
  
  (* 核心方法 - 严格对应 gemini-cli *)
  method virtual validate_tool_params : 'a -> string option
  method virtual get_description : 'a -> string
  method virtual tool_locations : 'a -> tool_location list
  method virtual should_confirm_execute : 'a -> Lwt_unix.signal -> tool_confirmation_details option Lwt.t
  method virtual execute : 'a -> Lwt_unix.signal -> (string -> unit) option -> tool_result Lwt.t
end

(* 可修改工具接口 - 对应 ModifiableTool *)
type 'a modify_context = {
  get_file_path: 'a -> string;
  get_current_content: 'a -> string Lwt.t;
  get_proposed_content: 'a -> string Lwt.t;
  create_updated_params: string -> string -> 'a -> 'a;
}

class virtual ['a] modifiable_tool = object
  inherit base_tool
  method virtual get_modify_context : Lwt_unix.signal -> 'a modify_context
end
```

#### 2. 工具注册表系统
```ocaml
(* 动态工具注册表 - 基于 ToolRegistry *)
module ToolRegistry = struct
  type t = {
    tools: (string, base_tool) Hashtbl.t;
    config: Config.t;
  }

  val create : Config.t -> t
  val register_tool : t -> base_tool -> unit
  val discover_tools : t -> unit Lwt.t  (* 动态工具发现 *)
  val get_function_declarations : t -> function_declaration list
  val get_all_tools : t -> base_tool list
  val get_tool : t -> string -> base_tool option
end
```

#### 3. 具体工具实现
```ocaml
(* 文件读取工具 - 基于 ReadFileTool *)
class read_file_tool (config : Config.t) = object
  inherit base_tool
  
  method name = "read_file"
  method display_name = "ReadFile"
  method description = "Reads and returns the content of a specified file from the local filesystem"
  method icon = "fileSearch"
  method is_output_markdown = true
  method can_update_output = false
  
  method validate_tool_params params =
    (* 验证路径是绝对路径，在工作目录内，不被忽略等 *)
    
  method should_confirm_execute params signal =
    (* 大多数文件操作不需要确认 *)
    Lwt.return None
    
  method execute params signal update_callback =
    (* 实际文件读取逻辑 *)
end

(* 文件写入工具 - 基于 WriteFileTool *)  
class write_file_tool (config : Config.t) = object
  inherit base_tool
  
  method name = "write_file"
  method should_confirm_execute params signal =
    (* 写入操作需要用户确认 *)
    let confirmation = EditConfirmation {
      title = "Write file";
      file_name = params.path;
      file_diff = generate_diff params.path params.content;
      original_content = read_existing_file params.path;
      new_content = params.content;
    } in
    Lwt.return (Some confirmation)
end

(* Shell 执行工具 - 基于 ShellTool *)
class shell_tool (config : Config.t) = object
  inherit base_tool
  
  method name = "shell"
  method should_confirm_execute params signal =
    (* Shell 命令需要执行确认 *)
    let confirmation = ExecConfirmation {
      title = "Execute command";
      command = params.command;
      root_command = extract_root_command params.command;
    } in
    Lwt.return (Some confirmation)
end

(* Grep 搜索工具 - 基于 GrepTool *)
class grep_tool (config : Config.t) = object
  inherit base_tool
  
  method name = "grep"
  method execute params signal update_callback =
    (* 使用 ripgrep 进行搜索 *)
end
```

#### 4. 精确的工具调度器系统
```ocaml
(* 工具调用请求信息 - 对应 ToolCallRequestInfo *)
type tool_call_request_info = {
  call_id: string;
  name: string;
  args: Yojson.Safe.t;                     (* JSON 参数 *)
  is_client_initiated: bool;               (* 是否由客户端发起 *)
  prompt_id: string option;                (* 关联的提示ID *)
}

(* 工具调用响应信息 - 对应 ToolCallResponseInfo *)
type tool_call_response_info = {
  call_id: string;
  name: string;
  result: tool_result;
  is_error: bool;
}

(* 批准模式 - 对应 ApprovalMode *)
type approval_mode = 
  | AutoEdit                               (* 自动批准编辑操作 *)
  | Manual                                 (* 手动批准所有操作 *)
  | Yolo                                   (* 跳过所有批准 *)

(* 工具调用状态 - 精确对应 gemini-cli 的7种状态 *)
type tool_call_state = 
  | Validating of {
      request: tool_call_request_info;
      tool: base_tool;
      start_time: float option;
      outcome: tool_confirmation_outcome option;
    }
  | Scheduled of {
      request: tool_call_request_info;
      tool: base_tool;
      start_time: float option;
      outcome: tool_confirmation_outcome option;
    }
  | Executing of {
      request: tool_call_request_info;
      tool: base_tool;
      live_output: string option;
      start_time: float option;
      outcome: tool_confirmation_outcome option;
    }
  | AwaitingApproval of {
      request: tool_call_request_info;
      tool: base_tool;
      confirmation_details: tool_confirmation_details;
      start_time: float option;
      outcome: tool_confirmation_outcome option;
    }
  | Successful of {
      request: tool_call_request_info;
      tool: base_tool;
      response: tool_call_response_info;
      duration_ms: float option;
      outcome: tool_confirmation_outcome option;
    }
  | Errored of {
      request: tool_call_request_info;
      response: tool_call_response_info;
      duration_ms: float option;
      outcome: tool_confirmation_outcome option;
    }
  | Cancelled of {
      request: tool_call_request_info;
      tool: base_tool;
      response: tool_call_response_info;
      duration_ms: float option;
      outcome: tool_confirmation_outcome option;
    }

(* 核心工具调度器 - 对应 CoreToolScheduler *)
module ToolScheduler = struct
  type t = {
    tool_registry: ToolRegistry.t;
    tool_calls: tool_call_state list ref;
    approval_mode: approval_mode;
    on_tool_calls_update: unit -> unit;                    (* UI 更新回调 *)
    on_all_tool_calls_complete: tool_call_state list -> unit Lwt.t;  (* 完成回调 *)
  }

  (* 核心调度方法 *)
  val schedule : t -> tool_call_request_info list -> Lwt_unix.signal -> unit Lwt.t
  
  (* 状态转换 *)
  val set_status_internal : t -> string -> string -> 'a option -> unit
  
  (* 执行管理 *)
  val attempt_execution_of_scheduled_calls : t -> Lwt_unix.signal -> unit Lwt.t
  
  (* 确认处理 *)
  val handle_confirmation_response : 
    t -> string -> (tool_confirmation_outcome -> unit Lwt.t) -> 
    tool_confirmation_outcome -> Lwt_unix.signal -> 
    tool_confirmation_payload option -> unit Lwt.t
  
  (* 生命周期管理 *)
  val check_and_notify_completion : t -> unit
  val is_running : t -> bool
  val get_tool_calls : t -> tool_call_state list
  
  (* 外部编辑器集成 *)
  val modify_with_editor : 
    'a -> 'a modify_context -> editor_type -> Lwt_unix.signal -> 
    ('a * string) Lwt.t
end

(* 编辑器类型 *)
type editor_type = VSCode | Vim | Emacs | Nano | System
```

### Phase 2 实现策略（重新规划）

基于深入分析 gemini-cli 的复杂性，将 Phase 2 拆分为两个阶段：

#### Phase 2.1: 简化工具系统 MVP - 🎯 当前目标

**设计理念**: 优先可用性，采用最简设计快速实现工具集成

##### 1. 简化数据结构
```ocaml
(* 简化的工具结果 *)
type simple_tool_result = {
  content: string;                        (* 返回内容 *)
  success: bool;                          (* 是否成功 *)
  error_msg: string option;               (* 错误信息 *)
}

(* 简化的工具接口 *)
type tool_spec = {
  name: string;
  description: string;
  parameters: (string * string) list;     (* 参数名和描述 *)
}

(* 工具调用信息 *)
type tool_call = {
  id: string;
  name: string;
  args: (string * string) list;           (* 参数键值对 *)
}

(* 简化的确认类型 - 仅支持批准/拒绝 *)
type simple_confirmation = 
  | Approve 
  | Reject
```

##### 2. 核心模块设计
- **lib/tools/simple_tools.ml** - 简化工具接口和注册
- **lib/tools/file_tools.ml** - read_file, write_file, list_files 三个基础工具
- **lib/tools/tool_executor.ml** - 简单的工具执行器（无复杂状态机）
- **lib/tools/tool_parser.ml** - 解析 API 响应中的工具调用

##### 3. 基础工具实现
```ocaml
(* 文件读取 - 无需确认 *)
val read_file : string -> simple_tool_result Lwt.t

(* 文件写入 - 简单确认 *)
val write_file : string -> string -> simple_tool_result Lwt.t

(* 目录列表 - 无需确认 *)
val list_files : string -> simple_tool_result Lwt.t
```

##### 4. 集成到事件系统
- 扩展现有 `event_type` 支持工具调用
- 在 `chat_loop` 中添加工具调用处理
- 简单的用户确认界面

##### 5. 实现优先级
1. **工具解析器** - 解析 API 响应中的工具调用请求
2. **基础工具** - 实现三个文件操作工具
3. **简单确认** - Y/N 确认界面
4. **事件集成** - 与现有事件系统整合
5. **测试验证** - 使用 toy_projects/ocaml_2048/ 进行测试

#### Phase 2.2: 高级工具能力 - 🎯 下一目标

**重要发现**: 通过分析 gemini-cli 源码发现，它**没有内置的工具序列或自动化修复流程**。所有工具调用都是：
1. **独立事件**: 每个工具调用都是独立的，通过 CoreToolScheduler 并发执行
2. **状态机管理**: 7种状态（validating → scheduled → executing → success/error/cancelled）
3. **无序列概念**: 没有 editCorrector.ts 或自动 build->analyze->patch 流程
4. **LLM 驱动**: 复杂工作流程由 LLM 通过多轮对话实现，而非程序化序列

**新设计理念**: 遵循 gemini-cli 的真实架构，重点实现：
- 更多实用工具（shell、grep、build 等）
- 更好的错误处理和状态管理
- LLM 可以通过多轮对话实现复杂工作流程

##### 1. Shell 执行工具 (lib/tools/shell_tools.ml)
```ocaml
(* Shell 命令执行 - 基于 gemini-cli 的 ShellTool *)
val execute_shell : string -> simple_tool_result Lwt.t
val is_safe_command : string -> bool  (* 基础安全检查 *)
```

##### 2. 构建工具 (lib/tools/build_tools.ml)  
```ocaml
(* 构建工具 - 支持 dune, make, npm 等 *)
val dune_build : string option -> simple_tool_result Lwt.t
val dune_test : string option -> simple_tool_result Lwt.t
val parse_build_output : string -> string  (* 格式化构建输出 *)
```

##### 3. 搜索工具 (lib/tools/search_tools.ml)
```ocaml
(* 基于 ripgrep 的搜索工具 *)
val grep_search : string -> string option -> simple_tool_result Lwt.t
val find_files : string -> string option -> simple_tool_result Lwt.t
```

##### 4. 更好的错误处理
```ocaml
(* 增强错误信息 *)
type enhanced_tool_result = {
  content : string;
  success : bool;
  error_msg : string option;
  exit_code : int option;        (* Shell 命令退出码 *)
  execution_time : float option; (* 执行时间 *)
}
```

##### 5. 实现优先级
1. **Shell 工具** - 安全的命令执行（受限白名单）
2. **构建工具** - dune build/test 集成
3. **搜索工具** - grep 和文件查找
4. **错误处理增强** - 更详细的错误信息和执行反馈
5. **测试集成** - 与 toy_projects 的完整验证

#### Phase 2.3: 完整工具系统 - 🔮 未来目标

**设计理念**: 完全对齐 gemini-cli 架构，支持所有高级功能

##### 1. 完整架构实现
- **类系统**: 完整的 base_tool 类和继承体系
- **状态机**: 7种工具调用状态的完整实现
- **确认系统**: 7种确认结果类型，4种确认详情类型
- **注册表**: 动态工具发现和管理
- **调度器**: 并发执行和生命周期管理

##### 2. 高级功能
- **ModifiableTool 接口**: 外部编辑器集成
- **Shell 工具**: 命令白名单/黑名单系统
- **实时输出**: 流式工具输出和更新
- **错误恢复**: 复杂的错误处理和重试机制
- **安全性**: 完整的路径验证和权限检查

##### 3. 实现子阶段
- **Phase 2.3.1**: 核心接口和状态机
- **Phase 2.3.2**: 确认系统和编辑器集成
- **Phase 2.3.3**: 高级工具（shell, grep）
- **Phase 2.3.4**: 性能优化和错误处理

### 当前策略：专注 Phase 2.1

**目标**: 在 1-2 周内实现可用的工具系统，支持基本的文件操作和代码生成场景。

**成功标准**:
```bash
👤 You: Read the game.py file and analyze its structure
🤖 Assistant: [调用 read_file 工具] 
文件内容显示和分析...

👤 You: Create an OCaml version with similar logic
🤖 Assistant: [调用 write_file 工具，用户确认]
✓ 用户批准文件写入
文件创建成功: game.ml
```

### 基于真实架构的使用场景

```bash
# 启动 OGemini
ogemini

# 工具集成对话示例
👤 You: Read the file ./game.py and help me understand the bit operations
🤖 Assistant: I'll read the file for you.

[工具调用请求] read_file { absolute_path: "/full/path/to/game.py" }
[工具执行 - 无需确认] 读取文件内容...
[返回] 文件内容和分析

👤 You: Now create an OCaml version with the same logic
🤖 Assistant: I'll create the OCaml version for you.

[工具调用请求] write_file { absolute_path: "/full/path/to/game.ml", content: "..." }
[用户确认] ✓ 文件写入确认框（显示 diff）
[工具执行] 创建文件...
[返回] 文件创建成功
```

### 关键架构洞察

从 gemini-cli 深入分析中获得的重要发现：

#### 1. 工具接口复杂性远超预期
- **ModifiableTool 接口**：支持外部编辑器修改工具参数的高级功能
- **getModifyContext**：提供文件路径、当前内容、建议内容的复杂上下文管理
- **临时文件系统**：用于diff编辑的完整临时文件管理机制

#### 2. 参数验证的多层架构
- **JSON Schema 验证**：使用 AJV 库进行标准验证，包含复杂的类型转换逻辑
- **业务逻辑验证**：路径安全性、权限检查、文件存在性等
- **命令安全验证**：Shell工具有复杂的白名单/黑名单系统

#### 3. 确认流程的状态管理
- **ApprovalMode 枚举**：AUTO_EDIT、MANUAL、YOLO 三种模式
- **ToolConfirmationOutcome 枚举**：7种不同的用户响应类型
- **动态白名单**：用户批准后的命令会加入会话级白名单

#### 4. 工具调用的完整生命周期
```
validating → [shouldConfirmExecute] → awaiting_approval | scheduled 
→ executing → success | error | cancelled
```
- **7种状态**：每种状态都有特定的数据结构和转换规则
- **时间跟踪**：startTime、durationMs 用于性能监控和遥测
- **中止处理**：AbortSignal 在所有异步操作中传播

#### 5. 流式输出和实时更新
- **updateOutput 回调**：支持工具执行期间的实时输出更新（如shell命令）
- **throttled updates**：限制更新频率避免UI性能问题
- **输出汇总**：长输出的自动汇总功能

#### 6. 错误处理的分层设计
- **llmContent vs returnDisplay**：为LLM和用户提供不同的错误信息
- **结构化错误**：带有错误代码、消息、上下文的完整错误对象
- **错误恢复**：某些错误情况下的自动重试和修正机制

### Phase 2 开发和测试环境

#### 测试项目设置
- **测试项目**: `toy_projects/ocaml_2048/`
- **项目规格**: `GEMINI.md` - "Translate game.py to OCaml with bit-level agreement"
- **测试文件**: `game.py` - 完整的 2048 游戏实现（位操作优化）
- **Git 管理**: 项目已初始化 git，可通过 `git checkout` 重置状态

#### 开发测试流程
```bash
# 重置测试环境到初始状态
cd toy_projects/ocaml_2048
git checkout HEAD~0  # 回到第一个 commit

# 启动 OGemini 项目模式进行测试
cd ../../
ogemini ./toy_projects/ocaml_2048/

# 测试各种项目感知功能
👤 You: What's the goal of this project?
👤 You: Show me the project structure
👤 You: Analyze the game.py implementation
👤 You: Start translating to OCaml
```

#### 测试验证重点
1. **项目上下文加载** - 正确读取 GEMINI.md 和项目文件
2. **智能文件操作** - 项目范围内的读写和搜索
3. **代码分析能力** - 理解 Python 代码结构和位操作逻辑
4. **迭代开发支持** - 逐步生成和完善 OCaml 代码
5. **状态管理** - 跟踪项目修改和开发进度

通过 git reset 机制，我们可以快速重置测试环境，确保每次测试都从干净的状态开始。

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

## 项目结构和导航
```
🏠 /Users/zsc/Downloads/ogemini/  ← ROOT DIRECTORY (工作目录)
├── 📄 .env                      ← API 密钥配置
├── 📄 CLAUDE.md                 ← 项目文档 (本文件)
├── 📄 dune-project              ← Dune 项目配置
├── 📁 bin/                      
│   ├── dune
│   └── main.ml                  ← 程序入口点
├── 📁 lib/                      ← 核心库
│   ├── types.ml                 ← 数据类型
│   ├── config.ml                ← 配置管理
│   ├── event_parser.ml          ← 事件解析
│   ├── api_client.ml            ← API 客户端
│   ├── ui.ml                    ← 用户界面
│   └── tools/                   ← Phase 2.2 工具
│       ├── file_tools.ml        ← 文件操作工具
│       ├── shell_tools.ml       ← Shell 执行工具 ✨
│       └── build_tools.ml       ← 构建工具 ✨
├── 📁 toy_projects/             ← 测试项目
│   └── ocaml_2048/              ← 2048 游戏项目 (测试 Phase 2.2)
│       ├── GEMINI.md            ← 项目目标
│       └── game.py              ← Python 源码
└── 📁 gemini-cli/               ← 参考实现

🚀 执行命令 (从 ROOT 执行):
- dune build                     ← 构建项目
- dune exec ./bin/main.exe       ← 运行 OGemini
- source .env && dune exec ./bin/main.exe  ← 带环境变量运行

🎯 测试 Phase 2.2 (从 ROOT 执行):
cd toy_projects/ocaml_2048 && source ../../.env && ../../_build/default/bin/main.exe

⚠️  IMPORTANT BASH TIPS: 
- Always add 'cd -' at the end of bash commands that change directories to return to original location.
  Example: cd some/path && do_something && cd -
- On macOS, use 'gtimeout' instead of 'timeout' (install with: brew install coreutils)
- For better diagnosis, agent should emit intermediate status during long operations
- **PATH CONFUSION FIX**: Prefix all bash commands with "cd /Users/zsc/Downloads/ogemini" to ensure proper directory
  Example: cd /Users/zsc/Downloads/ogemini && dune build

📝 PROMPT GUIDANCE:
- For effective prompts, refer to gemini-cli/prompts.md for examples and patterns
- Core system prompt shows best practices for tool usage and user interaction
- Use specific, direct instructions rather than vague requests

🐍 PYTHON NOTE:
- Use '/usr/bin/env python' not 'python3' (python is actually python3.11 on this system and is good, but python3 is something without proper libs)
```

## 后续扩展方向
完成 MVP 后，可以逐步添加：
1. 工具系统（文件操作、命令执行等）
2. 流式输出支持
3. 会话历史管理
4. 更丰富的 UI
5. 多模型支持

## Phase 3: 开发基础设施

### Phase 3.1: Docker 虚拟化环境 - ✅ 已完成

**目标**: 为 OGemini Agent 提供安全隔离的执行环境，使其能够自由操作文件系统而不影响宿主机。

#### 实现架构
```
宿主机 (macOS) → Docker 容器 (Linux ARM64)
├── 源码挂载: /ogemini (读写)
├── 工作空间: /workspace (Agent 完全权限)  
├── 环境变量: GEMINI_API_KEY
└── 运行方式: dune exec (跨平台兼容)
```

#### 核心文件
- **Dockerfile**: OCaml 5.1 + 精简工具链 (dune, lwt, yojson, re, ocamlformat)
- **scripts/docker-simple.sh**: 简化启动脚本 (无需 docker-compose)
- **.dockerignore**: 优化构建上下文

#### 关键特性实现
- ✅ **Agent 视角**: Agent 认为自己在正常环境中运行，对 `/workspace/` 拥有完全权限
- ✅ **透明性**: Agent 不知道自己在容器中，行为自然  
- ✅ **安全隔离**: 所有危险操作限制在容器内，源码与宿主机完全隔离
- ✅ **工具链完整**: OCaml 5.1 + Dune 3.19.1 + 系统工具
- ✅ **跨平台兼容**: 容器内构建避免二进制架构问题
- ✅ **生产级安全**: 源码复制到容器内，Agent 无法修改宿主机文件

#### 使用方法
```bash
# 构建并启动安全的 OGemini 容器
./scripts/docker-simple.sh

# 手动安全模式运行
docker build -t ogemini:latest .
docker build -t ogemini-secure:latest -f- . <<'EOF'
FROM ogemini:latest
COPY --chown=opam:opam . /ogemini-src
WORKDIR /ogemini-src
RUN eval $(opam env) && dune build
WORKDIR /workspace
EOF

docker run -it --rm \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/.env:/workspace/.env:ro" \
  -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
  -w /workspace \
  ogemini-secure:latest \
  /ogemini-src/_build/default/bin/main.exe
```

#### 安全模型
```
🔒 容器安全隔离
├── 源码: 复制到容器内 (Agent 无法修改宿主机)
├── 工作空间: /workspace/ (Agent 完全控制)
├── 网络: 仅 API 访问 (无宿主机网络)
└── 文件系统: 容器内隔离 (无宿主机访问)
```

#### 验证结果
- ✅ OCaml 5.1.1 + Dune 3.19.1 工具链正常
- ✅ OGemini 在容器中成功启动和运行
- ✅ API 密钥环境变量正确传递和识别  
- ✅ Workspace 目录隔离和文件访问正常
- ✅ toy_projects/ocaml_2048 测试项目可用
- ✅ 源码安全隔离 (Agent 无法修改宿主机源码)
- ✅ 生产级安全模型验证通过
- ✅ 自动工具执行 (无需用户确认，安全容器环境)
- ✅ 简化用户交互 (专注对话，不中断工具操作)

### Phase 3.2: Mock LLM 录制回放系统 - 🔮 后续目标

**目标**: 建立 LLM 交互的录制和回放机制，支持确定性测试和回归测试。

#### 核心功能
1. **录制模式**
   - 捕获所有 LLM API 请求和响应
   - 保存为可重放的测试用例
   - 记录时间戳和上下文信息

2. **回放模式**
   - 根据请求匹配返回录制的响应
   - 支持模糊匹配和精确匹配
   - 处理工具调用的确定性

3. **测试集成**
   - 单元测试使用 Mock 响应
   - 集成测试使用真实录制
   - CI/CD 中的回归测试

#### 数据结构设计
```ocaml
type mock_interaction = {
  request_hash: string;      (* 请求的唯一标识 *)
  request: api_request;      (* 完整请求内容 *)
  response: api_response;    (* 完整响应内容 *)
  timestamp: float;          (* 录制时间 *)
  metadata: (string * string) list;  (* 额外信息 *)
}

type mock_mode = 
  | Record                   (* 录制真实交互 *)
  | Replay                   (* 回放录制内容 *)
  | PassThrough             (* 直接调用真实 API *)
```

#### 实现策略
1. **API Client 拦截器** - 在 api_client.ml 添加 Mock 层
2. **存储格式** - JSON 文件存储交互记录
3. **匹配算法** - 智能匹配请求和响应
4. **测试框架** - 集成到现有测试系统
5. **管理工具** - 录制文件的管理和维护

#### 使用场景
```bash
# 录制模式 - 捕获真实交互
MOCK_MODE=record dune exec ./bin/main.exe

# 回放模式 - 使用录制内容
MOCK_MODE=replay dune test

# 回归测试 - CI 环境
MOCK_MODE=replay dune runtest
```

### 实施计划

**Phase 3.1 (✅ 已完成)**
- ✅ Docker 环境搭建和测试
- ✅ 跨平台二进制兼容性解决 (使用 dune exec)
- ✅ 完整验证 Phase 2.2 功能
- ✅ 简化部署流程 (无需 docker-compose)

**Phase 3.2 (🎯 下一目标)**  
- Mock 系统架构设计
- 录制回放核心功能
- 测试集成和文档

Phase 3.1 的成功完成为 OGemini Agent 提供了安全隔离的执行环境，现在可以安全地进行各种文件操作和代码生成任务，为 Phase 3.2 的确定性测试系统奠定了坚实基础。
