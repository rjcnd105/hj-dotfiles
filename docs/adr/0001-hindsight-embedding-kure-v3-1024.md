# Hindsight 임베딩은 KURE-v3를 1,024차원으로 잘라 쓴다

Hindsight 메모리 서버의 임베딩 모델로 KURE-v3(`i1-Q4_K_S` GGUF)를 홈랩 CPU에서 llama.cpp로 서빙하고, 2,048차원 출력을 앞 1,024차원만 남겨 다시 정규화해 저장한다. 메모리 내용이 한국어와 영어가 섞여 있어 한국어 검색 품질이 높은 모델이 필요했고, KURE-v3는 Matryoshka 학습 모델이라 절단해도 품질 손실이 작으면서 pgvector 인덱스와 저장 크기는 절반이 된다.

llama.cpp는 OpenAI 호환 API의 `dimensions`를 무시하므로 절단은 임베딩 서버 앞의 작은 프록시(`systems/homelab/hindsight-embedding-proxy.py`)가 맡는다.

## Considered Options

- **2,048차원 그대로**: 프록시가 필요 없지만 벡터 저장과 인덱스가 두 배다. 개인 규모 메모리에서 품질 차이를 체감할 근거가 없었다.
- **Hindsight 기본 임베딩(이미지 내장 로컬 모델)**: 구성이 가장 단순하지만 한국어 품질이 낮다.
- **외부 임베딩 API**: 홈랩 자원을 쓰지 않지만 메모리 내용이 외부로 나가고 모델 교체 시점을 직접 정할 수 없다.

## Consequences

모델이나 차원을 바꾸면 저장된 벡터를 전부 다시 임베딩해야 한다. 그래서 GGUF는 revision과 hash로, 차원은 `hindsight.nix`의 `embeddingDimensions` 한 곳에 고정했다.
