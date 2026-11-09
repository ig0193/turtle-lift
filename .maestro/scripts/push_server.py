"""A localhost-only HTTP endpoint that runs `xcrun simctl push` on request.

Maestro cannot run shell commands, but its JavaScript can `http.post`, so a
flow calls POST http://127.0.0.1:<port>/push and gets a notification on the
simulator at the moment it needs one, then taps the banner in the same run
(the banner is not in the accessibility tree, and it is gone before a second
Maestro run can attach).

  python3 push_server.py <udid> <apns-file> [port] [training-apns-file]

POST /push sends <apns-file> (a diet reminder); POST /push/training sends the
training-day reminder, whose payload routes to the Workout tab (ADR 0008).
"""
import http.server
import subprocess
import sys

UDID, APNS = sys.argv[1], sys.argv[2]
PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 8765
TRAINING = sys.argv[4] if len(sys.argv) > 4 else None


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        files = {'/push': APNS, '/push/training': TRAINING}
        apns = files.get(self.path)
        if apns is None:
            self.send_response(404)
            self.end_headers()
            return
        r = subprocess.run(['xcrun', 'simctl', 'push', UDID, 'dev.indresh.turtleLift', apns],
                           capture_output=True, text=True)
        self.send_response(200 if r.returncode == 0 else 500)
        self.end_headers()
        self.wfile.write((r.stdout + r.stderr).encode())

    def log_message(self, *args):
        pass


http.server.HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
