---
name: "source-command-se-gen"
description: "se gen — Flickstone 효과음 요구 목록을 승인된 백엔드로 생성·정규화·검증하고 사람 검수에 올린다."
---

# source-command-se-gen

전투 감각 승인 뒤 실제 효과음을 생성할 때 사용한다.

## 절차

1. `AGENTS.md`, `pipeline/commands/se.md`, `docs/command-catalog.md`를 읽고 현재 단계 제한을 확인한다.
2. manifest와 설계 정본에서 필요한 효과음 ID, 용도, 길이, 반복 여부, 출력 규격을 수집한다.
3. 합성형 효과음과 생성형 효과음 중 적절한 백엔드를 제안하고 비용·외부 호출이 있으면 사람 확인을 받는다.
4. 승인된 백엔드로 원본을 생성한다. API 키나 비밀값은 출력하지 않는다.
5. 저장소 규격으로 샘플레이트, 채널, 피크, 길이, 무음을 정규화한다.
6. 각 파일을 probe하고 누락·손상·클리핑·규격 불일치를 검사한다.
7. 생성 결과와 자동 검증을 사람 검수로 제시한다.

## 제한

- 이 단계에서는 씬이나 이벤트에 효과음을 연결하지 않는다. 연결은 `source-command-se-attach`에서 수행한다.
- 승인 없이 유료 또는 외부 생성 작업을 확대하지 않는다.
- manifest 변경이 필요하면 `pipeline/scripts/manifest.py`만 사용한다.
- P0·P1에서는 실행하지 않는다.
