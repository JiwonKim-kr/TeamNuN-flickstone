---
name: "source-command-art-gen"
description: "art gen — 승인된 Flickstone 스타일로 런타임 아트 에셋을 생성·후처리·검증한다."
---

# source-command-art-gen

승인된 스타일로 실제 게임 아트를 생성할 때 사용한다. 전투 감각 승인과 art lock 완료가 모두 선행되어야 한다.

## 절차

1. `AGENTS.md`, `pipeline/commands/art.md`, `docs/command-catalog.md`를 읽는다.
2. 잠긴 스타일 가이드와 manifest 등록 상태를 검증한다. 없거나 미승인이면 중단한다.
3. 요청된 에셋 목록, 규격, 수량, 출력 경로를 확정한다. 미정 값을 임의로 채우지 않는다.
4. 잠긴 커스텀 모델과 스타일 가이드에 따라 에셋을 생성한다.
5. 프로젝트 규격에 맞게 크기, 여백, 배경, 알파, 파일명을 후처리한다.
6. 각 파일을 probe하고 누락·손상·규격 불일치를 보고한다.
7. 생성 결과를 사람 검수로 제시한다.

## 제한

- 이 단계에서는 씬의 플레이스홀더를 교체하지 않는다. 연결은 `source-command-art-reskin`에서 수행한다.
- 승인되지 않은 스타일이나 임시 컨셉을 런타임 에셋으로 사용하지 않는다.
- manifest 변경이 필요하면 `pipeline/scripts/manifest.py`만 사용한다.
- 비밀값은 출력하지 않는다.
