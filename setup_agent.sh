#!/bin/bash
# ADK-Aligned Termux Agent Setup Script
# This script builds a complete agent based on a three-module architecture:
# 1. Frontend: User Interaction Layer (Vite/React)
# 2. Backend: Orchestration & Logic Core (FastAPI)
# 3. Tools: Action Execution Units (Python Functions)

set -e

# --- Environment Detection ---
if [ -d "/data/data/com.termux" ]; then
    ENVIRONMENT="termux"
    PKG_MANAGER="pkg"
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    ENVIRONMENT="linux"
    PKG_MANAGER="apt"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
fi

echo "Setting up ADK-Aligned Termux Agent..."
echo "Detected Environment: $ENVIRONMENT"
echo "---"

# --- 1. Dependency Installation ---
echo "Installing system dependencies..."
if [ "$ENVIRONMENT" = "termux" ]; then
    $PKG_MANAGER update -y
    $PKG_MANAGER install -y python nodejs-lts git curl
else
    sudo $PKG_MANAGER update -y
    sudo $PKG_MANAGER install -y python3 python3-pip nodejs npm git curl
fi

echo "Installing Python packages for Backend and Tools..."
$PIP_CMD install "fastapi[all]" uvicorn python-dotenv google-generativeai openai

echo "Installing global Node.js packages for Frontend..."
if [ "$ENVIRONMENT" = "termux" ]; then
    npm install -g create-vite
else
    sudo npm install -g create-vite
fi
echo "---"

# --- 2. Project Directory Structure ---
echo "Creating project directory structure..."
mkdir -p termux-agent/{frontend,backend/tools}
cd termux-agent
echo "Project root created at: $(pwd)"
echo "---"


###########################################################
# MODULE 3: THE TOOL MODULE (ACTION EXECUTION UNIT)
###########################################################
echo "Creating Module 3: The Tool Module..."

# Create __init__.py to mark 'tools' as a Python package
cat > backend/tools/__init__.py << 'EOF'
# This file makes the 'tools' directory a Python package.
EOF

# Create the execute_shell_command tool
cat > backend/tools/shell_executor.py << 'EOF'
"""
Tool: execute_shell_command
Responsibility: Execute a single shell command.
Independence: This function has zero knowledge of the web server,
              the AI model, or the user interface. It is a pure,
              reusable, and independently testable utility.
"""
import subprocess
import os
from typing import Dict, Any

def execute_shell_command(command: str, timeout: int = 30) -> Dict[str, Any]:
    """
    Executes a shell command and returns a structured dictionary.
    """
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=os.path.expanduser('~') # Always run from home directory for safety
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'return_code': result.returncode,
            'command': command,
            'type': 'shell_command'
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'command': command,
            'type': 'shell_command'
        }
EOF
echo "  - Created tools/shell_executor.py"
echo "---"


###########################################################
# MODULE 2: THE BACKEND MODULE (ORCHESTRATION & LOGIC CORE)
###########################################################
echo "Creating Module 2: The Backend Module..."
cat > backend/app.py << 'EOF'
"""
Backend: The Orchestration & Logic Core
Responsibility: Expose API, coordinate with LLM, delegate to tools.
Independence: Agnostic to the UI. Contains isolated business logic.
              The LLM client is a small, replaceable component.
"""
import os
import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime

# Import the independent tool functions
from tools.shell_executor import execute_shell_command
# Future tools would be imported here, e.g.:
# from tools.file_manager import manage_files

# --- Pydantic Model for API Data Validation ---
class CommandRequest(BaseModel):
    command: str

# --- LLM Orchestrator ---
class LLMOrchestrator:
    """A dedicated class to handle all LLM interactions."""
    def __init__(self):
        self.client = None # Placeholder for LLM client (e.g., Gemini)
        print("LLM Orchestrator initialized (model client to be configured).")

    def interpret_command(self, user_input: str) -> dict:
        """
        Interprets the user command to decide which tool to use.
        In a real implementation, this would call an LLM with function-calling capabilities.
        For this script, we use a simple fallback.
        """
        # This is a simplified fallback for when no LLM is configured.
        print(f"Interpreting command (fallback): '{user_input}'")
        if "list files" in user_input.lower() or "ls" in user_input.lower():
            return {"tool": "execute_shell_command", "params": {"command": "ls -la"}, "explanation": "List files in the current directory."}

        # Default to executing the command directly
        return {"tool": "execute_shell_command", "params": {"command": user_input}, "explanation": f"Executing the provided shell command: '{user_input}'"}

# --- FastAPI Application ---
app = FastAPI(title="ADK Agent Backend", version="1.0")
orchestrator = LLMOrchestrator()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

def execute_tool(interpretation: dict) -> dict:
    """
    Delegator function. Routes the request to the correct tool.
    This function has no business logic; it only calls the tool.
    """
    tool_name = interpretation.get('tool')
    params = interpretation.get('params', {})

    if tool_name == 'execute_shell_command':
        return execute_shell_command(**params)
    # Add other tools here with 'elif'
    else:
        return {'success': False, 'error': f'Tool "{tool_name}" not found.'}

@app.post("/api/execute")
async def handle_execute(request: CommandRequest):
    """API endpoint to receive commands from the Frontend Module."""
    try:
        # 1. Coordinate with LLM to get an action plan
        interpretation = orchestrator.interpret_command(request.command)

        # 2. Delegate to the appropriate tool
        result = execute_tool(interpretation)

        # 3. Return the structured result
        return {
            'success': True,
            'interpretation': interpretation,
            'result': result,
            'timestamp': str(datetime.now())
        }
    except Exception as e:
        return {'success': False, 'error': str(e)}

@app.get("/api/status")
async def status():
    """Health check endpoint for the frontend."""
    return {"status": "healthy", "timestamp": str(datetime.now())}
EOF
echo "  - Created backend/app.py"
echo "---"


###########################################################
# MODULE 1: THE FRONTEND MODULE (USER INTERACTION LAYER)
###########################################################
echo "Creating Module 1: The Frontend Module..."

# Use a non-interactive way to create the Vite project
cd frontend
npm create vite@latest . -- --template react > /dev/null 2>&1
echo "  - Vite project initialized."

npm install axios > /dev/null 2>&1
echo "  - Axios installed for API communication."

# Create the App.jsx file
cat > src/App.jsx << 'EOF'
/**
 * Frontend: The User Interaction Layer
 * Responsibility: Render UI, capture input, send to API, display result.
 * Independence: Has no knowledge of the AI or tools. Only communicates
 *               via the /api/execute endpoint. Can be completely replaced
 *               without affecting the backend or tools.
 */
import { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE_URL = 'http://localhost:5000';

function App() {
  const [command, setCommand] = useState('');
  const [history, setHistory] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [backendStatus, setBackendStatus] = useState('disconnected');
  const historyEndRef = useRef(null);

  // Scroll to bottom of history on update
  useEffect(() => {
    historyEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [history]);

  // Check backend status on initial load
  useEffect(() => {
    axios.get(`${API_BASE_URL}/api/status`)
      .then(() => setBackendStatus('connected'))
      .catch(() => setBackendStatus('disconnected'));
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!command.trim() || isLoading) return;

    setIsLoading(true);
    const userEntry = { type: 'user', content: command };
    setHistory(prev => [...prev, userEntry]);

    try {
      const response = await axios.post(`${API_BASE_URL}/api/execute`, { command });
      setHistory(prev => [...prev, { type: 'agent', data: response.data }]);
    } catch (error) {
      setHistory(prev => [...prev, { type: 'error', data: error.message }]);
    } finally {
      setIsLoading(false);
      setCommand('');
    }
  };

  return (
    <div className="container">
      <header className="header">
        <h1>ADK-Aligned Agent</h1>
        <div className={`status ${backendStatus}`}>
          Backend: {backendStatus}
        </div>
      </header>
      <div className="history-panel">
        {history.map((entry, index) => (
          <div key={index} className={`entry ${entry.type}`}>
            {entry.type === 'user' && <p><strong>You:</strong> {entry.content}</p>}
            {entry.type === 'agent' && <AgentResponse response={entry.data} />}
            {entry.type === 'error' && <p><strong>Error:</strong> {entry.data}</p>}
          </div>
        ))}
        {isLoading && <div className="entry agent"><p>Thinking...</p></div>}
        <div ref={historyEndRef} />
      </div>
      <form onSubmit={handleSubmit} className="input-form">
        <input
          type="text"
          value={command}
          onChange={(e) => setCommand(e.target.value)}
          placeholder="e.g., list files"
          disabled={isLoading || backendStatus !== 'connected'}
        />
        <button type="submit" disabled={isLoading || backendStatus !== 'connected'}>
          Send
        </button>
      </form>
    </div>
  );
}

// A component to nicely format the agent's response
const AgentResponse = ({ response }) => {
  const { interpretation, result } = response;
  return (
    <div>
      <p className="interpretation">
        <em>Interpreted as: {interpretation.explanation}</em>
      </p>
      {result.success ? (
        <pre>{result.stdout || "Command executed with no output."}</pre>
      ) : (
        <pre className="error-output">{result.stderr || result.error}</pre>
      )}
    </div>
  );
};

export default App;
EOF
echo "  - Created src/App.jsx"

# Create the App.css file
cat > src/App.css << 'EOF'
/* CSS for the Frontend Module */
body { margin: 0; font-family: system-ui, sans-serif; background-color: #f0f2f5; }
.container { display: flex; flex-direction: column; height: 100vh; max-width: 800px; margin: 0 auto; background-color: #fff; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
.header { padding: 1rem; border-bottom: 1px solid #ddd; display: flex; justify-content: space-between; align-items: center; }
.status { padding: 0.3rem 0.8rem; border-radius: 1rem; font-size: 0.8rem; }
.status.connected { background-color: #d4edda; color: #155724; }
.status.disconnected { background-color: #f8d7da; color: #721c24; }
.history-panel { flex: 1; padding: 1rem; overflow-y: auto; }
.entry { margin-bottom: 1rem; padding: 0.8rem; border-radius: 8px; }
.entry.user { background-color: #e7f3ff; text-align: right; }
.entry.agent { background-color: #f8f9fa; }
.interpretation { font-size: 0.9em; color: #6c757d; margin-bottom: 0.5rem; }
pre { background-color: #212529; color: #f8f9fa; padding: 1rem; border-radius: 4px; white-space: pre-wrap; word-break: break-all; }
pre.error-output { color: #f8d7da; }
.input-form { display: flex; padding: 1rem; border-top: 1px solid #ddd; }
input { flex: 1; padding: 0.8rem; border: 1px solid #ccc; border-radius: 4px; }
button { padding: 0.8rem 1.5rem; margin-left: 1rem; background-color: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
button:disabled { background-color: #a0c3e6; }
EOF
echo "  - Created src/App.css"
echo "---"

# --- Final Instructions ---
echo "✅ SETUP COMPLETE!"
echo "Your ADK-Aligned agent has been created."
echo ""
echo "--- HOW TO RUN YOUR AGENT ---"
echo ""
echo "1. In one terminal, start the Backend Module (Orchestration Core):"
echo "   cd backend"
echo "   uvicorn app:app --host 0.0.0.0 --port 5000 --reload"
echo ""
echo "2. In a second terminal, start the Frontend Module (UI Layer):"
echo "   cd frontend"
echo "   npm run dev"
echo ""
echo "3. Open the frontend URL from the second terminal in your browser."
echo "---"
