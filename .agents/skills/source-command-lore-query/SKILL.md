---
name: "source-command-lore-query"
description: "lore query — Flickstone 세계관 질문을 canon과 lore index에서 읽기 전용으로 조회하고 근거 위치와 함께 답한다."
---

# source-command-lore-query

세계관 사실을 확인하거나 다른 작업에 필요한 정본 근거를 찾을 때 사용한다. 이 스킬은 읽기 전용이다.

## 절차

1. `AGENTS.md`, `pipeline/commands/lore.md`, `docs/command-catalog.md`를 읽는다.
2. 질문이 없거나 범위가 불명확하면 확인 질문을 한다.
3. 저장소 lore index/query 경로로 `lore/canon/`을 검색한다.
4. 결과가 없으면 핵심 명사를 1~2개의 가까운 동의어로 바꾸어 재검색한다.
5. canon에서 확인되는 사실만 요약하고 `path:line` 근거를 붙인다.
6. 답이 없거나 canon끼리 충돌하면 그 사실을 명시하고 승인 결정 또는 lore check를 제안한다.

## 제한

- canon 파일, index, manifest, 게임 코드를 수정하지 않는다.
- 일반 상식이나 모델 기억으로 세계관 공백을 채우지 않는다.
- 검색 결과가 없다는 이유로 새 설정을 확정하지 않는다.
- 비밀값을 출력하지 않는다.
