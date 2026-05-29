"""Minimal dependency-free mock chat server.

Run with: `python backend/mock_chat_server.py` and POST JSON {"question": "..."} to http://localhost:8000/chat
This avoids pydantic/build issues and works with the system Python.
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


def build_response(question: str) -> dict:
    q = (question or "").strip().lower()
    if not q:
        return {"question": question, "answer": "I didn't get a question.", "cited_data": []}

    if any(g in q for g in ("hello", "hi", "hey")):
        return {"question": question, "answer": "Hello — how can I help with road data or complaints?", "cited_data": []}

    if "budget" in q or "cost" in q or "spend" in q:
        return {
            "question": question,
            "answer": "Estimated yearly budget for road repairs is $1,200,000 (demo).",
            "cited_data": [
                {"source": "mock_budget.json", "summary": "Annual repair budget: $1.2M"}
            ],
        }

    if "complaint" in q or "report" in q or "issue" in q:
        return {
            "question": question,
            "answer": "There are 3 recent complaints near your selected road (demo).",
            "cited_data": [{"source": "mock_complaints.json", "summary": "3 complaints in last 7 days"}],
        }

    # Fallback rule-based reply
    return {"question": question, "answer": "Sorry — I don't have a full answer in demo mode.", "cited_data": []}


class ChatHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers()

    def do_POST(self):
        if self.path != "/chat":
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not found"}).encode())
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length else ""
        try:
            data = json.loads(body) if body else {}
        except Exception:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "Invalid JSON"}).encode())
            return

        question = data.get("question") or data.get("q") or ""
        resp = build_response(question)
        self._set_headers(200)
        self.wfile.write(json.dumps(resp).encode())


def run_server(host="0.0.0.0", port=8000):
    server = HTTPServer((host, port), ChatHandler)
    print(f"Mock chat server running at http://{host}:{port}/chat")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down")
        server.server_close()


if __name__ == "__main__":
    run_server()
