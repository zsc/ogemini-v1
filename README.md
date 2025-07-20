# OGemini

A modern AI CLI assistant implemented in OCaml, featuring event-driven conversation engine and Gemini API integration.

## 🚀 Quick Start

### Prerequisites

- OCaml (5.0+)
- Dune (3.0+)
- A valid Gemini API key

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd ogemini
```

2. Set up your API key:
```bash
echo "GEMINI_API_KEY=your_api_key_here" > .env
```

3. Build the project:
```bash
dune build
```

4. Run the assistant:
```bash
source .env && dune exec ./bin/main.exe
```

## 💬 Usage

Once started, OGemini provides an interactive chat interface:

```
🚀 OGemini - OCaml AI Assistant (Phase 1 MVP)
====================================================
Type your message, or 'exit'/'quit' to exit.

✅ Using model: gemini-2.5-flash
💭 Thinking mode: disabled

👤 You: Hello, how are you?
🤖 Assistant: Hello! I'm doing well, thank you for asking. How can I help you today?

👤 You: exit
👋 Goodbye!
```

## ✨ Features

### Phase 1 (Completed)
- ✅ **Event-driven architecture** - Modular message processing
- ✅ **Gemini API integration** - Direct connection to Gemini 2.5 Flash
- ✅ **Thinking mode support** - Parse and display AI reasoning
- ✅ **Real-time output** - Typing effects and colored display
- ✅ **Configuration management** - Environment-based setup
- ✅ **Error handling** - Graceful failure recovery

### Phase 2 (Planned)
- 🔄 Tool system integration (grep, find, ls, file operations)
- 🔄 Loop detection and prevention
- 🔄 Smart conversation control
- 🔄 Streaming output optimization

## 🏗️ Architecture

OGemini uses an event-driven architecture that processes AI interactions as discrete events:

```ocaml
type event_type = 
  | Content of string              (* Regular text content *)
  | Thought of thought_summary     (* AI thinking process *)
  | ToolCallRequest of string      (* Tool execution requests *)
  | ToolCallResponse of string     (* Tool execution results *)
  | LoopDetected of string         (* Loop detection alerts *)
  | Error of string                (* Error information *)
```

## 📦 Project Structure

```
ogemini/
├── bin/main.ml           # Program entry point
├── lib/
│   ├── types.ml          # Core data types
│   ├── config.ml         # Configuration management
│   ├── event_parser.ml   # Event parsing and formatting
│   ├── api_client.ml     # Gemini API client
│   └── ui.ml             # User interface and interaction
├── dune-project          # Dune build configuration
└── .env                  # API key configuration
```

## 🔧 Configuration

Create a `.env` file with your Gemini API key:

```bash
GEMINI_API_KEY=your_actual_api_key_here
```

The system will automatically:
- Load the API key from environment
- Use Gemini 2.5 Flash model by default
- Enable/disable thinking mode as needed

## 🧪 Development

### Building
```bash
dune build
```

### Testing
```bash
# Run with test input
echo -e "Hello\nexit" | source .env && dune exec ./bin/main.exe
```

### Formatting
```bash
dune build @fmt --auto-promote
```

## 🤝 Contributing

This project follows the "small steps, fast iterations" principle. Each change should:

1. Maintain compilability with `dune build`
2. Follow OCaml best practices
3. Add appropriate error handling
4. Include documentation updates

## 📄 License

MIT License - see LICENSE file for details.

## 🔗 Related Projects

- [Gemini CLI](https://github.com/google/gemini-cli) - Original TypeScript implementation
- [Claude Code](https://claude.ai/code) - Development assistant used for this project

---

**Phase 1 MVP Complete!** 🎉 Ready for Phase 2 tool integration.