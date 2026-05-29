"""Simple CLI client to interact with the mock /chat server.

Usage:
    python chat_client.py "What is the budget?"
    python chat_client.py    # interactive prompt
"""
import sys
import json
import http.client


def ask(question: str, host='localhost', port=8000):
    conn = http.client.HTTPConnection(host, port, timeout=10)
    payload = json.dumps({'question': question})
    conn.request('POST', '/chat', body=payload, headers={'Content-Type': 'application/json'})
    resp = conn.getresponse()
    data = resp.read().decode()
    conn.close()
    try:
        return json.loads(data)
    except Exception:
        return {'raw': data}


def main():
    if len(sys.argv) > 1:
        q = ' '.join(sys.argv[1:])
        print(ask(q))
        return

    print('Interactive chat client. Type a question or Ctrl-C to exit.')
    try:
        while True:
            q = input('> ').strip()
            if not q:
                print('Please type a question.')
                continue
            resp = ask(q)
            print(json.dumps(resp, indent=2))
    except KeyboardInterrupt:
        print('\nbye')


if __name__ == '__main__':
    main()
