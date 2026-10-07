import http.client
import json
import tempfile
import threading
import unittest
import server


class CollectorTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        server.DB = cls.tmp.name + '/test.sqlite'
        server.UPLOAD, server.READ = 'u'*32, 'r'*32
        cls.http = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        threading.Thread(target=cls.http.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.tmp.cleanup()

    def request(self, method, token='', body=None, path='/events'):
        c = http.client.HTTPConnection('127.0.0.1', self.http.server_port)
        c.request(method, path, json.dumps(body) if body is not None else None,
                  {'Authorization': 'Bearer '+token})
        r = c.getresponse()
        result = r.status, json.loads(r.read())
        c.close()
        return result

    def test_auth_validation_storage_and_expiry(self):
        event = {'session': 'synthetic', 'time': '2026-10-07T00:00:00Z',
                 'kind': 'parking', 'data': {'requested': True}}
        self.assertEqual(self.request('POST', body=[event])[0], 401)
        self.assertEqual(self.request('POST', server.READ, [event])[0], 401)
        self.assertEqual(self.request('GET', server.UPLOAD)[0], 401)
        self.assertEqual(self.request('POST', server.UPLOAD, [event]*101)[0], 400)
        self.assertEqual(self.request('POST', server.UPLOAD, [{'bad': 1}])[0], 400)
        self.assertEqual(self.request('POST', server.UPLOAD, [event])[0], 202)
        status, rows = self.request('GET', server.READ)
        self.assertEqual(status, 200)
        self.assertEqual(rows[0]['data'], {'requested': True})
        with server.database() as db:
            db.execute('UPDATE events SET received=0')
        self.assertEqual(self.request('GET', server.READ)[1], [])
        self.assertEqual(self.request('GET', path='/health')[0], 200)
