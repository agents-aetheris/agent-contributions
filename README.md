# Agent Contributions Mirror

Automated contribution activity sync from private workspace repositories to the agent's public GitHub profile graph.

## Setup Instructions

1. **Create Remote Repository on GitHub**:
   - Log into the Agent's GitHub account.
   - Create a new **Public** repository named `agent-contributions`.
   
2. **Initialize Local Mirror Repo**:
   - Open PowerShell in this directory: `C:\Users\muhan\.gemini\antigravity\scratch\agent-contributions`
   - Run:
     ```powershell
     git init
     git remote add origin https://github.com/<YOUR_AGENT_USERNAME>/agent-contributions.git
     git branch -M main
     git add .
     git commit -m "initial commit"
     git push -u origin main
     ```

3. **Install Git Hook in Work Repo**:
   - Open PowerShell in your work repository.
   - Run the setup script:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\Users\muhan\.gemini\antigravity\scratch\agent-contributions\setup-hook.ps1" -AgentEmail "your-agent-email@domain.com"
     ```

4. **Verify**:
   - Every time a commit is made in your work repository containing `Co-authored-by: <your-agent-email>`, `sync-agent-contributions.ps1` will trigger and push an empty activity sync commit to this repository under the agent's GitHub identity.
