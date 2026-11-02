import unittest
from unittest.mock import patch

from app import Handler


class AppTest(unittest.TestCase):
    def request(self, path):
        handler = Handler.__new__(Handler)
        handler.path = path
        with patch.object(handler, "respond") as respond:
            handler.do_GET()
            return respond.call_args.args

    def test_health(self):
        self.assertEqual(self.request("/health"), (200, {"status": "ok"}))

    def test_info_uses_environment(self):
        with patch.dict("os.environ", {"APP_ENV": "staging"}):
            self.assertEqual(self.request("/info"), (200, {"environment": "staging"}))


if __name__ == "__main__":
    unittest.main()
