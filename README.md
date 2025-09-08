### **Structure of the ADK-Aligned Termux Agent**

This architecture is designed with clear separation of concerns, resulting in three primary, independent modules.

---

#### **1. Frontend Module: The User Interaction Layer**

This module is exclusively responsible for everything the user sees and interacts with. It is a self-contained application.

*   **Directory:** `frontend/`
*   **Technology:** Vite/React (or any modern web framework)
*   **Core Responsibility:**
    *   Render the user interface (chat window, input box, etc.).
    *   Capture user input (natural language commands).
    *   Send user commands to the Backend Module via an API call.
    *   Receive results from the Backend Module and display them to the user.
*   **Principle of Independence:**
    *   The frontend has **no knowledge** of the AI model, the tools, or the internal logic of the backend.
    *   It communicates **only** through a defined API endpoint (e.g., `/execute`).
    *   This module can be developed, tested, and even completely replaced (e.g., with a Vue.js app) without requiring any changes to the other modules.

---

#### **2. Backend Module: The Orchestration & Logic Core**

This module acts as the central "brain" of the agent, receiving requests, coordinating with the AI model, and delegating tasks to the appropriate tools.

*   **File:** `backend/app.py`
*   **Technology:** Flask (or any web server framework)
*   **Core Responsibilities:**
    *   Expose an API endpoint (`/execute`) for the Frontend Module.
    *   Receive the user's command from the API request.
    *   Communicate with the Large Language Model (e.g., Gemini) to interpret the command and determine which tool to use.
    *   Call the appropriate function from the Tool Module based on the model's decision.
    *   Return the result from the tool back to the Frontend Module.
*   **Principle of Independence:**
    *   The backend is **agnostic** about how the user interface looks or functions; it only cares about receiving data at its API endpoint.
    *   It contains the **isolated business logic**, preventing complex decision-making from leaking into the presentation layer.
    *   The connection to the specific AI model is a small, replaceable part of this module, making it **model-agnostic** in spirit.

---

#### **3. Tool Module: The Action Execution Unit**

This module is a collection of simple, reusable functions that perform specific, real-world actions. It has no awareness of the user or the AI.

*   **Component:** `execute_shell_command` function (and other potential tool functions within `backend/app.py` or a separate `tools.py` file).
*   **Technology:** Python
*   **Core Responsibility:**
    *   Execute a single, well-defined task (e.g., run a shell command).
    *   Accept specific, structured input (e.g., a string containing the command).
    *   Return a specific, structured output (e.g., the standard output of the command).
*   **Principle of Independence:**
    *   This function has **zero knowledge** of the frontend, the Flask server, or the AI model. It is a pure, self-contained utility.
    *   It can be **tested in complete isolation** to ensure its reliability.
    *   It is highly **reusable** and could be easily integrated into a different agent or application.
