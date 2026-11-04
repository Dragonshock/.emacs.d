#!/usr/bin/env python3
"""Checks for hn-elfeed's Magpie model selection.  Does not call the gateway."""

import importlib.util
import sqlite3
import sys
import tempfile
import types
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
for name in ("trafilatura", "lxml", "lxml.html", "markdown_it", "pypdf"):
    sys.modules.setdefault(name, types.ModuleType(name))
sys.modules["lxml"].html = sys.modules["lxml.html"]
class _MarkdownIt:
    def __init__(self, *_args, **_kwargs):
        pass

    def enable(self, *_args, **_kwargs):
        return self


sys.modules["markdown_it"].MarkdownIt = _MarkdownIt
sys.modules["pypdf"].PdfReader = object

spec = importlib.util.spec_from_file_location(
    "hn_elfeed", ROOT / "scripts" / "hn-elfeed.py"
)
hn = importlib.util.module_from_spec(spec)
sys.modules["hn_elfeed"] = hn
spec.loader.exec_module(hn)


class MagpieModelTests(unittest.TestCase):
    def test_picker_blob_keeps_the_model_id(self):
        blob = "workbuddy/auto".encode("utf-16-le")
        self.assertEqual(hn.magpie_model_from_blob(blob), "workbuddy/auto")

    def test_pi_provider_prefix_is_removed(self):
        blob = "magpie/workbuddy/auto".encode("utf-16-le")
        self.assertEqual(hn.magpie_model_from_blob(blob), "workbuddy/auto")

    def test_empty_blob_uses_the_routing_group(self):
        self.assertEqual(hn.magpie_model_from_blob(b""), "group/smart-split")
        self.assertEqual(hn.magpie_model_from_blob(None), "group/smart-split")

    def test_sqlite_picker_and_missing_store(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "localstorage.sqlite3"
            with sqlite3.connect(path) as conn:
                conn.execute("create table ItemTable (key text, value blob)")
                conn.execute(
                    "insert into ItemTable values (?, ?)",
                    ("magpie.model", "workbuddy/auto".encode("utf-16-le")),
                )
            self.assertEqual(hn.magpie_model(path), "workbuddy/auto")
        missing = Path(tempfile.gettempdir()) / "hn-elfeed-missing-magpie.sqlite3"
        self.assertEqual(hn.magpie_model(missing), "group/smart-split")

    def test_request_body_has_no_deepseek_thinking_field(self):
        body = hn.llm_request_body(
            "workbuddy/auto",
            [{"role": "user", "content": "hi"}],
            100,
        )
        self.assertEqual(body["model"], "workbuddy/auto")
        self.assertEqual(body["temperature"], 0)
        self.assertEqual(body["response_format"], {"type": "json_object"})
        self.assertNotIn("thinking", body)
        self.assertEqual(hn.MAGPIE_URL, "http://127.0.0.1:3425/v1/chat/completions")
        self.assertEqual(hn.MAGPIE_API_KEY, "magpie")
        self.assertEqual(hn.LLM_TIMEOUT, 180)


class BlockedArticleHostTests(unittest.TestCase):
    def test_bot_walled_publishers_match_subdomains_only(self):
        blocked = (
            "https://www.science.org/content/article/serbia",
            "https://news.science.org/x",
            "https://www.ft.com/content/abc",
            "https://www.wsj.com/tech/ai/openai",
        )
        for url in blocked:
            self.assertTrue(hn.article_host_blocked(url), url)
        self.assertFalse(hn.article_host_blocked("https://example.com/story"))
        self.assertFalse(hn.article_host_blocked("https://notft.com/content"))
        self.assertFalse(hn.article_host_blocked("https://ft.com.evil.com/content"))

    def test_blocked_host_does_not_download(self):
        def fail_request(*_args, **_kwargs):
            raise AssertionError("blocked host must not be downloaded")

        original = hn.http_request
        hn.http_request = fail_request
        try:
            text = hn.fetch_article_text(
                "https://www.science.org/content/article/serbia",
                {"url": "https://www.science.org/content/article/serbia", "text": ""},
            )
        finally:
            hn.http_request = original
        self.assertEqual(text, "")


if __name__ == "__main__":
    unittest.main()
