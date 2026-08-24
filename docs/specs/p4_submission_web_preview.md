# P4 · 제출용 Web 프리뷰와 공개 링크

| 항목 | 내용 |
|---|---|
| status | `approved` |
| 작성 | 2026-08-24 |
| 승인 | 2026-08-24 · 사용자: WP-01~08 전체 승인 |
| 선행 계약 | P2 콘텐츠 회색상자, P3 AI, 제출용 전투 수직 슬라이스 |
| 구현 상태 | 2026-08-25 · 구현·자동 검증·공개 배포·브라우저 검수 완료 |

## 목표

OpenAI Game Builders Seoul 제출 검수자가 별도 설치 없이 현재 전투 수직 슬라이스를 브라우저에서 실행할 수 있게 한다. 로컬 재현 가능한 Web release export와 `main` 기반 GitHub Pages 공개 링크를 같은 계약으로 관리한다.

## 범위

- Godot 4.6.3 Web export preset
- `build/web/index.html` 기준 로컬 release 산출물과 필수 파일 검사
- GitHub Actions Pages 배포
- 배포 URL과 로컬 재현 명령 문서화
- Web import·첫 화면·입력·한 전투 smoke 기준
- 시스템 폰트 폴백 없이 한글 HUD를 표시하는 번들 폰트와 라이선스

번들 폰트는 Neo둥근모 v1.601 공식 `neodgm.ttf`를 사용한다. 체크인 SHA-256은 `77305267996073aae07bad9313dad2e306a4128e55bfafbed4c41558fee57b4d`이며, 원본 OFL 라이선스를 `assets/fonts/neodgm_ofl_license.txt`로 함께 보존한다.

## 비범위

- 정식 Steam/Windows 배포, 커스텀 도메인, 저장 데이터 이관
- PWA/offline cache, 멀티스레드 Web, 서버 권위 로직
- 아트·사운드·게임 콘텐츠 추가

## 승인 결정안

| ID | 결정 | 상태 |
|---|---|---|
| WP-01 | preset 이름은 `Web`, release 출력은 `build/web/index.html`로 고정한다 | ✅ 승인 |
| WP-02 | 브라우저 호환성을 우선해 Web은 single-thread로 export하고 COOP/COEP 전용 호스팅을 요구하지 않는다 | ✅ 승인 |
| WP-03 | Web 빌드는 640×1,024 세로 전장을 유지하고 브라우저 창에 맞춰 비율 보존 확장한다 | ✅ 승인 |
| WP-04 | 생성된 `build/`는 커밋하지 않고 CI artifact와 Pages deploy artifact로만 전달한다 | ✅ 승인 |
| WP-05 | 공개 호스팅은 GitHub Pages를 사용하며 `main` push 또는 수동 실행으로 배포한다 | ✅ 승인 |
| WP-06 | 배포 workflow는 Pages `contents:read`, `pages:write`, `id-token:write` 최소 권한만 사용한다 | ✅ 승인 |
| WP-07 | Pages 활성화·첫 공개 배포는 외부 상태 변경이므로 구현 검증 뒤 사용자 승인 범위로 실행한다 | ✅ 승인 |
| WP-08 | export template은 Godot 4.6.3 공식 template을 CI/로컬에 설치하고 저장소에는 넣지 않는다 | ✅ 승인 |

## 산출물 계약

- `export_presets.cfg`: Web release preset
- `pipeline/scripts/web_export.py`: pinned Godot 확인, export 실행, 필수 산출물 검사
- `pipeline/scripts/serve_web.py`: Windows에서도 JavaScript·WASM MIME을 고정하는 로컬 검수 서버
- `pipeline/tests/run_web_export.py`: template이 있으면 실제 export, 없으면 preset·workflow 정적 계약 검사
- `.github/workflows/pages.yml`: build artifact 생성 후 Pages 배포
- `README.md`, `HANDOFF.md`: 로컬 실행법·공개 URL·검수 체크리스트

필수 산출물은 최소 `index.html`, `.wasm`, `.pck`, JavaScript loader다. 파일명은 Godot 4.6.3 exporter가 만든 index stem을 기준으로 검사한다.

## 오류 계약

- Godot 버전이 4.6.3이 아니거나 export template이 없으면 명시적으로 실패한다.
- 산출물 누락, 0바이트 파일, HTML의 loader 참조 누락은 실패한다.
- CI 검증 workflow와 Pages workflow를 분리해 일반 테스트가 배포 권한을 얻지 않는다.
- PR은 export까지만 수행하고 공개 배포하지 않는다.

## 수용 기준

1. 로컬 공식 template 환경에서 release Web export가 성공한다.
2. 정적 서버에서 첫 화면이 열리고 마우스 조준·발사·적 턴·전투 종료가 동작한다.
3. 브라우저 콘솔에 fatal script/loader 오류가 없다.
4. Pages workflow의 PR 경로는 배포하지 않고 `main`/수동 경로만 배포한다.
5. 공개 URL에서 새로고침과 직접 진입이 동작한다.
6. 기존 Godot import·smoke·manifest와 P2 quick 회귀가 통과한다.

## 대상 파일

- `export_presets.cfg`
- `pipeline/scripts/web_export.py`
- `pipeline/scripts/serve_web.py`
- `pipeline/tests/run_web_export.py`
- `.github/workflows/pages.yml`
- `.gitignore`
- `README.md`
- `HANDOFF.md`
- `assets/fonts/neodgm.ttf`, `assets/fonts/neodgm_ofl_license.txt`, `assets/themes/default_theme.tres`

신규 런타임 에셋과 manifest 변경은 없다.

## 구현·배포 검증 기록

- 배포 수정 커밋: `555f9cb` (`fix: unblock Pages deployment`)
- 공개 URL: [Flickstone Web](https://jiwonkim-kr.github.io/TeamNuN-flickstone/)
- [GitHub Pages #3](https://github.com/JiwonKim-kr/TeamNuN-flickstone/actions/runs/32786567525): export·artifact 업로드·배포 성공
- [GitHub Actions verify #33](https://github.com/JiwonKim-kr/TeamNuN-flickstone/actions/runs/32786567552): Linux 전체 검증과 Windows 결정론 검증 성공
- 로컬 Godot 4.6.3 `verify --full`: 전체 25개 runner 통과
- 공개 URL HTTP 200, 직접 진입과 새로고침, 640×1,024 첫 화면과 한글 HUD 렌더링 확인
- 브라우저 fatal/error/warning 없음, 플레이어 드래그 발사 후 턴 2·적 actor 전환까지 확인
