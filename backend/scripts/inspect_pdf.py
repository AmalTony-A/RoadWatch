from pathlib import Path
import re

pdf_text_path = Path("c:/Users/acer/AppData/Roaming/Code/User/workspaceStorage/25cbe862dd812f18dadb9cdf2e605eb4/GitHub.copilot-chat/chat-session-resources/31342412-f10b-4a29-8f6c-5f6c9d1137e0/call_GFi314hsBsFTKtP5Gjwq0kdt__vscode-1777776354928/content.txt")
lines = [line.strip() for line in pdf_text_path.read_text(encoding="utf-8", errors="ignore").splitlines()]
starts = [i for i, line in enumerate(lines) if re.fullmatch(r"\d{3}", line)]
print("count", len(starts), "first", starts[:10])
if starts:
    idx = starts[0]
    print("ENTRY", lines[idx])
    print(" | ".join(lines[idx:idx+15]))
