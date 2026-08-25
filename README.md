# Flickstone

TeamNuN의 탑다운 픽셀아트 물리 전술 로그라이트 프로젝트입니다. 원형 기물을 드래그로 발사해 충돌 피해와 위치 제어를 만들고, CTB 턴 순서·기물 덱빌딩·분기형 런 구조를 결합합니다.

`Flickstone`은 프로젝트 코드명이며 정식 타이틀은 아직 확정하지 않았습니다.

## 현재 단계

- 엔진: Godot 4.6.x / GDScript
- 대상 플랫폼: PC(Steam) 우선, 제출 검수용 웹 프리뷰 제공
- 개발 단계: P4-1~3 구현·자동 검증 완료. 다음 런 작업은 P4-4 영입·골드·휴식·합성·덱 관리이며, P4-W 웹 공개 프리뷰는 배포·검수 완료
- 아트 정책: 현재 회색상자는 매니페스트의 P1 플레이스홀더 3개를 재사용한다. P5 A/B/C 스타일 보드 3장은 생성·probe 완료했으며 사람의 방향 선택 대기 중
- 아트·사운드 생성: 전투 감각 승인은 완료했다. `art concept` 선택 뒤 `art lock` 사람 승인을 거쳐 생성·reskin하며, 사운드는 별도 요청으로 진행

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
python pipeline/scripts/verify.py --demo --skip-godot
```

Godot 4.6.x 실행 파일을 설정한 뒤에는 `--skip-godot` 없이 전체 게이트를 실행합니다.

데모 기간의 push/PR CI는 기본 게이트와 대표 회귀 9종을 `--demo`로 실행하고 P0 결정론을 quick 값(20회·순열 3회)으로 줄입니다. 문서 전용 변경은 자동 검증을 생략하며, 정식 릴리스 전에는 Actions에서 수동 `release` 프로필(전체 25종·1,000회·Windows 교차 검증)을 통과시켜야 합니다.

## Web 프리뷰

공개 프리뷰: [Flickstone Web](https://jiwonkim-kr.github.io/TeamNuN-flickstone/)

Godot 4.6.3 공식 Web export template을 `pipeline/artifacts/godot-4.6.3/templates/4.6.3.stable/`에 둔 뒤 다음 명령으로 빌드하고 실행합니다. 전용 서버는 Windows MIME 설정과 무관하게 AudioWorklet JavaScript와 WASM을 올바른 형식으로 제공합니다.

```powershell
$env:PYTHONUTF8 = "1"
python pipeline/scripts/web_export.py --godot pipeline/artifacts/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe
python pipeline/scripts/serve_web.py
```

브라우저에서 `http://127.0.0.1:8060/`을 엽니다. `main` 브랜치의 승인된 변경은 GitHub Pages workflow가 위 공개 프리뷰로 배포합니다.
