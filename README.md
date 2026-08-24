# Flickstone

TeamNuN의 탑다운 픽셀아트 물리 전술 로그라이트 프로젝트입니다. 원형 기물을 드래그로 발사해 충돌 피해와 위치 제어를 만들고, CTB 턴 순서·기물 덱빌딩·분기형 런 구조를 결합합니다.

`Flickstone`은 프로젝트 코드명이며 정식 타이틀은 아직 확정하지 않았습니다.

## 현재 단계

- 엔진: Godot 4.6.x / GDScript
- 대상 플랫폼: PC(Steam) 우선, 웹 빌드는 개발 프리뷰 용도
- 개발 단계: P2 콘텐츠 기반 회색상자 구현·자동 검증 완료, 사람 플레이 검수 대기
- 아트 정책: 현재 회색상자는 매니페스트에 등록된 P1 플레이스홀더를 재사용
- 아트·사운드 생성: 전투 감각 승인은 완료했으며 별도 요청·승인 절차로 진행

## 설계 정본

게임 규칙과 개발 로드맵의 정본은 [`docs/design/game_design.md`](docs/design/game_design.md)입니다. 기능 구현 명세는 이 문서를 참조하되, 미정 항목을 임의로 확정하지 않습니다.

## 핵심 기술 원칙

- Godot 내장 물리 대신 엔진 비의존 결정론적 시뮬레이션을 사용합니다.
- 고정소수점 수학, 자체 PRNG, 고정 스텝, 정렬된 처리 순서로 리플레이 재현성을 보장합니다.
- 지원하는 트리거와 효과 원자의 조합은 데이터만 추가해 콘텐츠를 확장합니다.
- 구현은 승인된 `docs/specs/*.md` 범위 안에서 진행합니다.
- 모든 변경은 임포트·스모크·회귀 테스트와 매니페스트 정합성 검사를 통과해야 합니다.

## 개발 흐름

```text
play spec → 사람 승인 → play build → play test
→ verify → review
```

P0 순서:

```text
FixMath·SimRng → SimWorld → 충돌·벽·소멸 영역 → 상태 해시 회귀 테스트
```

아트·사운드 순서:

```text
P0·P1 플레이스홀더 → 전투 감각 검증
→ art concept → art lock → art gen/reskin → se gen/attach
```

## 주요 경로

| 경로 | 용도 |
|---|---|
| `docs/design/` | 게임 설계 정본 |
| `docs/specs/` | 승인 대상 기능 구현 명세 |
| `src/core/` | 게임 핵심 로직 |
| `src/core/data/` | 런타임 콘텐츠·튜닝 데이터 |
| `src/ui/`, `src/tools/` | UI와 개발 도구 |
| `scenes/` | Godot 씬 |
| `assets/` | 매니페스트로 관리하는 아트·오디오 |
| `pipeline/` | 검증·에셋·오케스트레이션 도구 |

## 검증

Windows에서는 UTF-8 모드를 활성화해 실행합니다.

```powershell
$env:PYTHONUTF8 = "1"
python pipeline/scripts/verify.py --full --skip-godot
```

Godot 4.6.x 실행 파일을 설정한 뒤에는 `--skip-godot` 없이 전체 게이트를 실행합니다.
