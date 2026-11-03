"""OpenAI 호환 임베딩 프록시: `dimensions`를 Matryoshka 절단으로 구현한다.

llama.cpp는 `dimensions`를 무시하고 모델의 전체 차원을 돌려준다. 이 프록시는
앞 N개 값만 남기고 다시 L2 정규화한다(sentence-transformers `truncate_dim`과 같은 결과).
"""

import base64
import json
import math
import os
import struct
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

UPSTREAM = os.environ["UPSTREAM"]
LISTEN_PORT = int(os.environ["LISTEN_PORT"])


def truncate(vector, dims):
    head = vector[:dims]
    norm = math.sqrt(sum(x * x for x in head)) or 1.0
    return [x / norm for x in head]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def reply(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def forward(self, body):
        request = Request(
            UPSTREAM + self.path,
            data=body,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urlopen(request, timeout=300) as response:
                return response.status, response.read()
        except HTTPError as error:
            return error.code, error.read()

    def do_GET(self):
        self.reply(*self.forward(None))

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(length))
        dims = payload.pop("dimensions", None)
        # OpenAI SDK는 기본으로 base64를 요청한다. 업스트림에는 float로 받고 여기서 맞춘다.
        encoding = payload.pop("encoding_format", "float")
        status, body = self.forward(json.dumps(payload).encode())
        if status == 200 and self.path.endswith("/embeddings"):
            result = json.loads(body)
            for item in result["data"]:
                vector = item["embedding"]
                if dims:
                    vector = truncate(vector, dims)
                if encoding == "base64":
                    packed = struct.pack(f"<{len(vector)}f", *vector)
                    vector = base64.b64encode(packed).decode()
                item["embedding"] = vector
            body = json.dumps(result).encode()
        self.reply(status, body)


ThreadingHTTPServer(("127.0.0.1", LISTEN_PORT), Handler).serve_forever()
