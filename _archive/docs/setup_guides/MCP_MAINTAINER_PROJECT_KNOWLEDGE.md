# MCP Maintainer Project Knowledge Base

This document serves as a central knowledge base for the "MCP Maintainer" project, focused on establishing, maintaining, and optimizing the Model Context Protocol (MCP) ecosystem for seamless cross-platform development.

## I. Endgoals of the Unified MCP Ecosystem

The primary objective is to create a cohesive and highly functional MCP environment that enables intelligent agents (like Gemini CLI and Claude) and specialized tools (like Godot Engine) to communicate, share context, and collaborate effectively.

### 1. Central Intelligence Hub: `gemini-ai-orchestrator`
*   **Role:** This Python-based MCP server acts as the primary gateway for all Gemini-powered AI operations. It intelligently routes requests, selects optimal Gemini models (e.g., `flash` for quick queries, `pro` for deep analysis), and handles API fallbacks.
*   **Benefits:** Centralized AI access, optimized model usage, robust error handling, and security features (input sanitization, path validation).

### 2. Cross-Client Communication: Wrappers and Bridges
*   **Role:** Facilitate seamless context and task handoffs between different client environments (Gemini CLI, Claude Code, Claude Desktop, Cursor WSL).
*   **Mechanism:**
    *   **File-Based Bridge (Gemini CLI):** For the Gemini CLI (which is stateless), a file-based request/response system (`mcp_bridge/requests` and `mcp_bridge/responses` directories) is used. The `gemini-ai-orchestrator` monitors these directories, processes requests, and writes responses.
    *   **Conceptual Handoffs (Claude Clients):** Claude Code and Claude Desktop will leverage the `gemini-ai-orchestrator` and `memory` MCP to serialize and deserialize session states, open files, command histories, and task-specific data. This enables a "handoff" feature where a task can be initiated in one client and resumed in another.
*   **Benefits:** Eliminates context switching overhead, enables multi-tool workflows, and improves developer productivity.

### 3. Persistent Knowledge Hub: `memory` MCP Server
*   **Role:** A dedicated MCP server (`npx -y @modelcontextprotocol/server-memory@latest`) that provides persistent storage for shared information across sessions and clients.
*   **Data Stored:** User preferences, project-specific configurations, command histories, session summaries, and any other relevant context that needs to persist.
*   **Benefits:** Ensures continuity of work, personalizes agent interactions, and builds a collective knowledge base for the project.

### 4. Seamless Integration and Unified Workflow
*   **Ultimate Goal:** To achieve a state where developers can fluidly transition between different tools and platforms, with all relevant context and AI capabilities available at their fingertips, without manual data transfer or re-configuration.

## II. Best Practices for Efficient Collaboration with Gemini CLI

Working effectively with the Gemini CLI (and any stateless agent) requires a clear understanding of its operational model and limitations.

1.  **Environment Setup is Paramount:**
    *   **Virtual Environments:** Always use Python virtual environments (`python3 -m venv .venv`) for installing dependencies. This prevents conflicts with system-wide Python installations and ensures reproducibility.
    *   **`pip` Functionality:** Verify `pip` is correctly installed and accessible within your chosen Python environment (e.g., `python3 -m pip install ...`).
    *   **Environment Variables:** Ensure critical environment variables like `GOOGLE_API_KEY`, `GEMINI_FLASH_MODEL`, and `GEMINI_PRO_MODEL` are correctly set in the shell where the MCP servers or scripts are launched.

2.  **Understand Gemini's Stateless Nature:**
    *   **No Persistent Memory (Directly):** I do not retain information between turns. Any context I need for a task must be provided in the current prompt or retrieved from a shared source (like the `memory` MCP).
    *   **Context is Key:** When asking me to perform tasks, provide all necessary context (file contents, directory structures, relevant code snippets) using tools like `read_file`, `read_many_files`, `glob`, and `search_file_content`.

3.  **Respect the Sandbox Boundary:**
    *   **Project Root Only:** I can *only* access files and directories located within the project's root directory (`/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/`).
    *   **Copy Necessary Files:** If I need to interact with files outside this boundary (e.g., `claude_desktop_config.json`), you *must* copy them into the project directory first.

4.  **Clear and Concise Communication:**
    *   **Explain the "Why":** Instead of just telling me *what* to do, explain *why* you want it done. This helps me understand the underlying goal and make more intelligent decisions.
    *   **Specific Instructions:** Be precise with file paths, command arguments, and desired outcomes.
    *   **Full Error Messages:** When reporting issues, provide the complete error message and any relevant `stdout`/`stderr` output.

5.  **Troubleshooting and Verification:**
    *   **Check `run_shell_command` Output:** Always examine the `stdout`, `stderr`, and `exit code` from `run_shell_command` calls. These provide crucial debugging information.
    *   **Verify Background Processes:** Use `ps aux | grep <process_name>` to confirm if background processes (like MCP servers) are actually running.
    *   **Patience with Async Operations:** Some operations (like AI model calls or file system monitoring) can take time. Allow sufficient `sleep` time or implement polling mechanisms.

## III. Sharing Connections Across Platforms (e.g., Godot, Cursor WSL)

The goal is to ensure that all development environments can tap into the unified MCP ecosystem.

1.  **Unified MCP Server Configuration:**
    *   **Consistency:** All clients (Claude Desktop, Claude Code, Cursor WSL, Godot Engine) should be configured to connect to the *same instances* of the `gemini-ai-orchestrator` and `memory` MCP servers. This means their respective configuration files (e.g., `claude_desktop_config.json`, Cursor's `settings.json`, Godot's MCP plugin settings) must point to the correct addresses (e.g., `localhost:port` or specific IP addresses if running across different machines/VMs).
    *   **Environment Variables:** Ensure that environment variables like `GOOGLE_API_KEY` are consistently set across all platforms where AI-powered MCPs are used.

2.  **Godot Engine Integration:**
    *   **Godot's Native MCP:** The Godot Engine has its own MCP server (`godot` MCP) that exposes Godot-specific tools (e.g., `add_node`, `create_scene`).
    *   **Leveraging Gemini:** If Godot needs to leverage Gemini's AI capabilities (e.g., for generating game content, analyzing GDScript), its MCP configuration should include the `gemini-ai-orchestrator` as a connected server. This allows Godot to call `mcp__gemini-ai-orchestrator__gemini_quick_query` or other Gemini tools.

3.  **Cursor WSL Integration:**
    *   **Network Access:** If your MCP servers are running on your Windows host, ensure that your Cursor WSL environment can access them via `localhost` or the appropriate Windows host IP address. Network configuration within WSL might be necessary.
    *   **Cursor's `settings.json`:** Configure Cursor's MCP settings to include the `gemini-ai-orchestrator` and `memory` MCP servers, pointing to their correct network locations.
    *   **Consistent Python Environment:** If Cursor is running Python scripts that interact with MCPs, ensure those scripts use a virtual environment with the necessary `mcp` and `google-generativeai` packages installed, similar to the Gemini CLI setup.

By adhering to these principles and practices, we can build a highly integrated and efficient development environment powered by MCP.
