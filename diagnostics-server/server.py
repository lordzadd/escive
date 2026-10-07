"""Small authenticated diagnostic collector. No scooter control endpoints."""
import hmac
import json
import os
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = os.environ.get('DIAGNOSTICS_DB', '/data/events.sqlite')
UPLOAD = os.environ.get('UPLOAD_TOKEN', '')
READ = os.environ.get('READ_TOKEN', '')


def database():
    db = sqlite3.connect(DB, timeout=10)
    db.execute('CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, received REAL, body TEXT)')
    return db


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass  # Never log authorization headers or diagnostic bodies.

    def reply(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authorized(self, token):
        return bool(token) and hmac.compare_digest(
            self.headers.get('Authorization', ''), 'Bearer ' + token)

    def do_GET(self):
        if self.path == '/health':
            with database() as db:
                db.execute('SELECT 1')
            return self.reply(200, {'status': 'ok'})
        if self.path != '/events':
            return self.reply(404, {'error': 'not_found'})
        if not self.authorized(READ):
            return self.reply(401, {'error': 'unauthorized'})
        with database() as db:
            db.execute('DELETE FROM events WHERE received < ?', (time.time() - 7*86400,))
            rows = db.execute('SELECT received, body FROM events ORDER BY id DESC LIMIT 1000').fetchall()
        self.reply(200, [{'received': t, **json.loads(b)} for t, b in rows])

    def do_POST(self):
        if self.path != '/events':
            return self.reply(404, {'error': 'not_found'})
        if not self.authorized(UPLOAD):
            return self.reply(401, {'error': 'unauthorized'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 65536:
                return self.reply(413, {'error': 'size'})
            self.connection.settimeout(10)
            items = json.loads(self.rfile.read(size))
            if not isinstance(items, list) or not 1 <= len(items) <= 100:
                raise ValueError()
            for e in items:
                if not isinstance(e, dict) or set(e) != {'session', 'time', 'kind', 'data'}:
                    raise ValueError()
                if not isinstance(e['session'], str) or len(e['session']) > 64:
                    raise ValueError()
                if not isinstance(e['time'], str) or len(e['time']) > 40:
                    raise ValueError()
                if e['kind'] not in ['state', 'tx', 'rx', 'device', 'telemetry', 'parking', 'write_error']:
                    raise ValueError()
                if not isinstance(e['data'], dict) or len(json.dumps(e)) > 4096:
                    raise ValueError()
        except (ValueError, TypeError, TimeoutError):
            return self.reply(400, {'error': 'invalid_batch'})
        with database() as db:
            db.executemany('INSERT INTO events(received, body) VALUES (?, ?)',
                           [(time.time(), json.dumps(e)) for e in items])
            db.execute('DELETE FROM events WHERE received < ?', (time.time() - 7*86400,))
            db.execute('DELETE FROM events WHERE id <= (SELECT MAX(id)-20000 FROM events)')
        self.reply(202, {'accepted': len(items)})


if __name__ == '__main__':
    if len(UPLOAD) < 32 or len(READ) < 32 or UPLOAD == READ:
        raise SystemExit('Set distinct UPLOAD_TOKEN and READ_TOKEN with at least 32 characters.')
    os.makedirs(os.path.dirname(os.path.abspath(DB)), exist_ok=True)
    ThreadingHTTPServer(('0.0.0.0', int(os.environ.get('PORT', '8080'))), Handler).serve_forever()
