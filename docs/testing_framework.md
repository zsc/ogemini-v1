# Gemini-CLI 测试框架详细分析

## 目录
1. [测试技术栈](#测试技术栈)
2. [测试架构设计](#测试架构设计)
3. [核心测试模式](#核心测试模式)
4. [各层测试策略](#各层测试策略)
5. [具体测试案例分析](#具体测试案例分析)
6. [测试工具和辅助函数](#测试工具和辅助函数)
7. [OCaml 测试框架设计建议](#ocaml-测试框架设计建议)

## 测试技术栈

### 核心框架
- **Vitest**: 现代化的 Vite 原生测试框架，提供快速的测试运行和 HMR 支持
- **@testing-library/react**: React Hook 测试的标准库
- **ink-testing-library**: 专门为 Ink (React for CLI) 设计的测试工具

### Mock 工具
- **vi.mock()**: Vitest 的模块级 mock 功能
- **vi.fn()**: 创建 mock 函数
- **vi.hoisted()**: 提升 mock 定义，解决循环依赖

### 辅助工具
- **Snapshot Testing**: 用于验证复杂 UI 输出
- **Custom Matchers**: 自定义断言匹配器

## 测试架构设计

### 1. 分层测试策略

```
┌─────────────────────────────────────┐
│         E2E Tests (较少)             │
├─────────────────────────────────────┤
│    Integration Tests (中等)          │
├─────────────────────────────────────┤
│      Unit Tests (大量)               │
└─────────────────────────────────────┘
```

### 2. 测试文件组织

```
src/
├── ui/
│   ├── App.tsx
│   ├── App.test.tsx              # 组件测试
│   ├── components/
│   │   ├── InputPrompt.tsx
│   │   ├── InputPrompt.test.tsx  # 组件测试
│   │   └── __snapshots__/        # 快照测试
│   └── hooks/
│       ├── useGeminiStream.tsx
│       └── useGeminiStream.test.tsx  # Hook 测试
└── gemini.test.tsx               # 核心逻辑测试
```

## 核心测试模式

### 1. 全面 Mock 策略

#### 模块级 Mock
```typescript
// 完整模块 mock
vi.mock('@google/gemini-cli-core', async (importOriginal) => {
  const actualCore = await importOriginal<typeof import('@google/gemini-cli-core')>();
  return {
    ...actualCore,
    Config: ConfigClassMock,
    Session: SessionClassMock,
    executeCommand: vi.fn(),
  };
});
```

#### 提升式 Mock (Hoisted)
```typescript
// 解决循环依赖和初始化顺序问题
const { mockBuffer, mockHandleInput } = vi.hoisted(() => {
  const mockBuffer = {
    text: '',
    setText: vi.fn(),
    replaceRangeByOffset: vi.fn(),
    // ... 其他方法
  };
  return { mockBuffer, mockHandleInput: vi.fn() };
});
```

### 2. 异步测试模式

#### 流式响应 Mock
```typescript
const createMockStream = () => {
  return (async function* () {
    yield { type: 'content', value: 'Part 1' };
    yield { type: 'content', value: 'Part 2' };
    yield { type: 'tool_call', tool: { name: 'read_file', args: {} } };
  })();
};
```

#### Promise 控制
```typescript
let resolvePromise: (() => void) | null = null;
const controlledPromise = new Promise<void>((resolve) => {
  resolvePromise = resolve;
});

// 测试中控制 Promise 解析
test('async flow', async () => {
  const result = doAsyncOperation(controlledPromise);
  // 验证 pending 状态
  expect(component.state).toBe('loading');
  
  // 触发 Promise 解析
  resolvePromise!();
  await waitFor(() => {
    expect(component.state).toBe('completed');
  });
});
```

### 3. UI 交互测试

#### 终端输入模拟
```typescript
const { stdin, lastFrame, unmount } = render(<InputPrompt {...props} />);

// 模拟键盘输入
stdin.write('hello');
stdin.write('\r'); // Enter 键

// 模拟特殊键
stdin.write('\u001B[A'); // 上箭头
stdin.write('\u0003');   // Ctrl+C
stdin.write('\t');       // Tab 键
```

#### 输出验证
```typescript
// 验证渲染输出
expect(lastFrame()).toMatch(/Enter your prompt/);
expect(lastFrame()).toContain('suggestion text');
expect(lastFrame()).not.toContain('error');
```

### 4. 状态机测试

#### 完整状态转换测试
```typescript
describe('StreamingState transitions', () => {
  it('should transition: idle -> preparing -> streaming -> processing -> idle', async () => {
    const { result } = renderHook(() => useGeminiStream());
    
    // Initial state
    expect(result.current.streamingState).toBe(StreamingState.Idle);
    
    // Start streaming
    act(() => {
      result.current.startStream(mockRequest);
    });
    expect(result.current.streamingState).toBe(StreamingState.Preparing);
    
    // Wait for streaming
    await waitFor(() => {
      expect(result.current.streamingState).toBe(StreamingState.Streaming);
    });
    
    // Complete streaming
    await act(async () => {
      await completeStream();
    });
    expect(result.current.streamingState).toBe(StreamingState.ProcessingTools);
    
    // Final state
    await waitFor(() => {
      expect(result.current.streamingState).toBe(StreamingState.Idle);
    });
  });
});
```

## 各层测试策略

### 1. 组件测试 (Component Tests)

#### 测试重点
- 用户交互响应
- 状态管理
- 条件渲染
- 事件处理

#### 示例：InputPrompt 测试
```typescript
describe('InputPrompt', () => {
  it('should handle file drag and drop', async () => {
    const { stdin } = render(<InputPrompt {...props} />);
    
    // 模拟文件拖拽
    stdin.write("'/path/to/file.txt'");
    await wait();
    
    // 验证转换为 @ 命令
    expect(mockBuffer.setText).toHaveBeenCalledWith('@/path/to/file.txt');
  });
  
  it('should navigate shell history', async () => {
    mockShellHistory.getPreviousCommand.mockReturnValue('previous command');
    
    const { stdin } = render(<InputPrompt {...props} />);
    stdin.write('\u001B[A'); // 上箭头
    
    await wait();
    expect(mockBuffer.setText).toHaveBeenCalledWith('previous command');
  });
});
```

### 2. Hook 测试

#### 测试重点
- 状态变化
- 副作用
- 异步操作
- 清理函数

#### 示例：useGeminiStream 测试
```typescript
describe('useGeminiStream', () => {
  it('should handle tool execution lifecycle', async () => {
    const { result } = renderHook(() => useGeminiStream());
    
    // 捕获回调
    let toolCompleteCallback: ((tools: TrackedToolCall[]) => Promise<void>) | null = null;
    mockUseReactToolScheduler.mockImplementation((onComplete) => {
      toolCompleteCallback = onComplete;
      return [[], mockScheduleToolCalls, mockMarkToolsAsSubmitted];
    });
    
    // 开始流
    act(() => {
      result.current.startStream(mockRequest);
    });
    
    // 模拟工具调用
    const mockTools = [
      { id: '1', name: 'read_file', status: 'pending' as const }
    ];
    
    await act(async () => {
      await toolCompleteCallback!(mockTools);
    });
    
    // 验证工具提交
    expect(mockSession.addToolResponse).toHaveBeenCalled();
  });
});
```

### 3. 工具系统测试

#### 测试重点
- 工具调用解析
- 执行状态管理
- 错误处理
- 结果提交

#### 示例：ToolMessage 测试
```typescript
describe('ToolMessage', () => {
  it('should display different states correctly', () => {
    // Pending 状态
    const { lastFrame: pending } = render(
      <ToolMessage tool={{ ...mockTool, status: 'pending' }} />
    );
    expect(pending()).toContain('⏳');
    
    // Executing 状态
    const { lastFrame: executing } = render(
      <ToolMessage tool={{ ...mockTool, status: 'executing' }} />
    );
    expect(executing()).toContain('🔄');
    
    // Success 状态
    const { lastFrame: success } = render(
      <ToolMessage tool={{ ...mockTool, status: 'success', output: 'Done!' }} />
    );
    expect(success()).toContain('✓');
    expect(success()).toContain('Done!');
  });
});
```

### 4. 错误处理测试

#### 自定义错误类
```typescript
class MockProcessExitError extends Error {
  constructor(public code: number) {
    super(`Process exited with code ${code}`);
  }
}

// 测试错误处理
it('should handle process exit gracefully', async () => {
  mockStartConversationStream.mockRejectedValue(new MockProcessExitError(0));
  
  const { stdin } = render(<App />);
  stdin.write('test\r');
  
  await waitFor(() => {
    expect(mockExit).toHaveBeenCalledWith(0);
  });
});
```

## 测试工具和辅助函数

### 1. 时间控制工具
```typescript
const wait = (ms = 50) => new Promise((resolve) => setTimeout(resolve, ms));

// 使用示例
await wait(); // 等待默认 50ms
await wait(100); // 等待 100ms
```

### 2. Mock 工厂函数
```typescript
function createMockCommandContext(): CommandContext {
  return {
    currentDirectory: '/test/dir',
    environmentVariables: {},
    shellHistory: [],
    theme: 'dark',
    configOptions: new Map(),
  };
}
```

### 3. 测试数据构建器
```typescript
const createMockToolCall = (overrides?: Partial<ToolCall>): ToolCall => ({
  id: 'tool-1',
  name: 'read_file',
  args: { path: 'test.txt' },
  status: 'pending',
  ...overrides,
});
```

### 4. 自定义断言
```typescript
// 验证复杂对象结构
expect(result).toMatchObject({
  type: 'tool_call',
  tool: expect.objectContaining({
    name: expect.stringMatching(/read_file|write_file/),
    args: expect.any(Object),
  }),
});
```

## OCaml 测试框架设计建议

基于 Gemini-CLI 的测试策略，为 OCaml 版本提出以下建议：

### 1. 测试框架选择
```ocaml
(* 推荐使用 Alcotest - OCaml 的现代测试框架 *)
open Alcotest

let test_basic_math () =
  check int "addition" 4 (2 + 2);
  check string "concatenation" "hello world" ("hello" ^ " " ^ "world")

let () =
  run "OGemini Tests" [
    "math", [ test_case "basic" `Quick test_basic_math ];
  ]
```

### 2. Mock 策略
```ocaml
(* 使用模块替换实现 Mock *)
module type API_CLIENT = sig
  val send_request : request -> response Lwt.t
end

(* 生产实现 *)
module Real_API_Client : API_CLIENT = struct
  let send_request req = (* 真实 HTTP 请求 *) 
end

(* 测试 Mock *)
module Mock_API_Client : API_CLIENT = struct
  let responses = ref []
  let send_request req = 
    match !responses with
    | h::t -> responses := t; Lwt.return h
    | [] -> failwith "No more mock responses"
end
```

### 3. 异步测试
```ocaml
(* 使用 Lwt 进行异步测试 *)
let test_async_operation () =
  let open Lwt.Syntax in
  let* result = async_function () in
  Alcotest.(check string) "async result" "expected" result;
  Lwt.return_unit

let async_tests = [
  Alcotest_lwt.test_case "async op" `Quick test_async_operation;
]
```

### 4. 状态机测试
```ocaml
(* 使用 QCheck 进行属性测试 *)
open QCheck

let test_state_transitions =
  Test.make ~count:100
    ~name:"state machine transitions"
    (triple state_gen action_gen state_gen)
    (fun (initial, action, expected) ->
      let result = transition initial action in
      result = expected || is_valid_transition initial action result)
```

### 5. UI 测试策略
```ocaml
(* 模拟终端输入输出 *)
module Mock_Terminal = struct
  type t = {
    mutable input_buffer : string list;
    mutable output_buffer : string list;
  }
  
  let create () = {
    input_buffer = [];
    output_buffer = [];
  }
  
  let write_input t input =
    t.input_buffer <- t.input_buffer @ [input]
  
  let read_output t =
    String.concat "\n" t.output_buffer
end
```

### 6. 集成测试框架
```ocaml
(* dune 测试配置 *)
(test
 (name test_ogemini)
 (libraries ogemini alcotest alcotest-lwt qcheck)
 (deps
  (source_tree test_data))
 (action
  (setenv OGEMINI_TEST_MODE true
   (run %{test}))))
```

### 关键建议

1. **分层测试**: 保持单元测试、集成测试和端到端测试的平衡
2. **Mock 优先**: 使用模块系统实现依赖注入和 Mock
3. **属性测试**: 利用 QCheck 测试复杂状态机和不变量
4. **异步测试**: 完善的 Lwt 测试支持
5. **快照测试**: 使用 PPX 导出可比较的数据结构
6. **CI 集成**: 确保测试可以在 Docker 环境中运行

这种测试策略将确保 OCaml 版本具有与原版相当的质量和可靠性。