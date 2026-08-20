---
name: "source-command-art-concept"
description: "art concept — Flickstone의 캐릭터·배경·UI 컨셉 이미지를 탐색하고 사람 선택용 후보를 만든다."
---

# source-command-art-concept

아트 방향을 탐색할 컨셉 후보가 필요할 때 사용한다. 이 단계는 탐색 전용이며 manifest나 게임 씬을 바꾸지 않는다.

## 절차

1. `AGENTS.md`, `pipeline/commands/art.md`, `docs/command-catalog.md`를 읽는다.
2. 대상, 수량, 용도, 필수 제약이 요청에 없으면 짧게 확인한다.
3. 세계관과 관련되면 `source-command-lore-query`로 정본 근거를 확인한다. 정본에 없는 설정을 만들지 않는다.
4. 다양한 방향의 컨셉 후보를 `assets/art/concepts/` 아래에 생성한다. 실험 목적에 맞는 범용 이미지 생성 모델을 사용한다.
5. 생성 파일을 probe하고 크기·형식·알파 채널 등 기계 검사를 수행한다.
6. 후보별 의도와 차이를 요약해 사람 선택을 요청한다.

## 제한

- 컨셉 파일을 런타임 manifest에 등록하지 않는다.
- 씬이나 게임 코드에 연결하지 않는다.
- 스타일 잠금, 파인튜닝, 양산으로 자동 진행하지 않는다.
- P0·P1에서는 전투 감각 승인 전까지 탐색 제안만 가능하며 실제 art lock 이후 단계는 시작하지 않는다.
