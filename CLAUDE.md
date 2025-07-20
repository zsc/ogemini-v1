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

### 1. 名词（核心数据结构）
```ocaml
(* 配置 *)
type config = {
  api_key: string;
  api_endpoint: string;
}

(* 消息 *)
type message = {
  role: string;  (* "user" | "model" *)
  content: string;
}

(* 对话历史 *)
type conversation = message list

(* API 响应 *)
type response = 
  | Success of string
  | Error of string
```

### 2. 动词（核心操作）
```ocaml
(* 配置管理 *)
val load_config : unit -> config

(* API 交互 *)
val send_message : config -> conversation -> string -> response Lwt.t

(* 对话管理 *)
val add_message : conversation -> message -> conversation
val format_prompt : conversation -> string

(* 用户交互 *)
val read_input : unit -> string option
val print_response : string -> unit
```

### 3. 引擎（核心循环）
```ocaml
(* 主循环：读取输入 -> 调用 API -> 显示结果 -> 更新历史 *)
let rec chat_loop config conversation =
  match read_input () with
  | None | Some "exit" | Some "quit" -> ()
  | Some input ->
      let conv = add_message conversation (create_user_message input) in
      let%lwt response = send_message config conv input in
      match response with
      | Success text ->
          print_response text;
          let conv = add_message conv (create_model_message text) in
          chat_loop config conv
      | Error err ->
          print_error err;
          chat_loop config conversation
```

### 4. 点火钥匙（启动入口）
```ocaml
(* bin/main.ml *)
let () =
  let config = load_config () in
  print_welcome ();
  Lwt_main.run (chat_loop config [])
```

### MVP 实现优先级
1. **第一步**：定义数据结构（名词）
2. **第二步**：实现配置加载（最简单的动词）
3. **第三步**：实现 API 客户端（核心动词）
4. **第四步**：实现交互循环（引擎）
5. **第五步**：组装并运行（点火）

### MVP 不包含
- 工具调用系统
- 流式输出
- 复杂 UI
- 会话持久化
- 多模型支持

## 开发原则
1. **循序渐进，小步快跑**：每次只实现一个小功能，确保可编译运行
2. **持续构建**：每个步骤都通过 `dune build` 和 `dune exec` 验证
3. **模块化设计**：遵循 OCaml 最佳实践，保持代码清晰可维护

## MVP 技术栈
- **构建系统**：Dune
- **HTTP 客户端**：Cohttp-lwt（用于调用 Gemini API）
- **JSON 处理**：Yojson（解析 API 响应）
- **异步处理**：Lwt（处理 HTTP 请求）

## 项目结构
```
ogemini/
├── dune-project
├── bin/
│   ├── dune
│   └── main.ml         # 程序入口
├── lib/
│   ├── dune
│   ├── config.ml       # 配置管理
│   ├── config.mli
│   ├── api_client.ml   # Gemini API 客户端
│   ├── api_client.mli
│   └── chat.ml         # 对话管理
│   └── chat.mli
└── CLAUDE.md
```

## 后续扩展方向
完成 MVP 后，可以逐步添加：
1. 工具系统（文件操作、命令执行等）
2. 流式输出支持
3. 会话历史管理
4. 更丰富的 UI
5. 多模型支持
