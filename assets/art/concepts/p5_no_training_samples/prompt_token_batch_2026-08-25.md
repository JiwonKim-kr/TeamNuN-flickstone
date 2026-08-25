# P5 대표 기물 6종 무학습 생성 프롬프트

## 공통 입력

- Image 1: 각 기물의 `../p5_token_refs_a/*_00.png` 주 피사체·실루엣 참조
- Image 2: `baduk_stone_test_00.png` 픽셀 밀도·원형 크기·림·좌상단 광원 참조
- Image 3: `../p5_map_board_a/p5_map_board_a_refined_02.png` 재질·팔레트 참조
- 실행: Codex 내장 imagegen, 기물당 독립 호출
- 모델 식별자·시드: 도구에서 노출하지 않음

## 공통 프롬프트

```text
Use case: stylized-concept
Asset type: production candidate for a top-down game piece sprite
Input images: Image 1 is the exact subject and silhouette reference; Image 2 is the approved no-training baduk token reference for pixel density, circular scale, rim treatment, and upper-left lighting; Image 3 is the approved board material and palette reference.
Primary request: create one <SUBJECT> as a self-contained circular game token, suitable for later nearest-neighbor reduction to a crisp 64x64 runtime sprite.
Style/medium: polished high-resolution pixel art matching the references, deliberately clustered pixels and crisp stepped edges, not smooth vector art and not photorealistic.
Composition/framing: exact orthographic top-down view, one token centered, even transparent padding, circular silhouette fully contained, no part touching the canvas edge.
Lighting/mood: fixed upper-left highlight, short compact lower-right contact shadow, dark tactile otherworld board-game mood.
Color palette: <PALETTE>; no cyan or orange faction ring baked into the piece.
Materials/textures: <MATERIALS>.
Constraints: genuinely transparent background; preserve alpha; exactly one token; no text; no letters; no numbers; no logo; no watermark; no extra objects; no environment; no colored faction ring; <SUBJECT CONSTRAINTS>
```

## 기물별 치환값

| 기물 | SUBJECT | PALETTE | MATERIALS | SUBJECT CONSTRAINTS |
|---|---|---|---|---|
| 병뚜껑 | worn metal bottle-cap token with a shallow embossed radial starburst and clearly readable crimped rim | neutral steel, charcoal, restrained aged-brass accents | scratched aged steel, slight brass oxidation near the lower edge, sturdy embossed ridges | keep the entire cap inside a circular footprint; no brand mark; no beverage label |
| 원시인 | caveman token represented as a primitive heavy stone face relief carved into a round medallion | charcoal stone and muted gray only | rough charcoal stone, shallow chiseled planes, compact brow and nose relief | face relief must remain inside the circular token; no full body; no hair or weapons protruding; readable at small size |
| AI | AI-core token with a single luminous mechanical eye surrounded by simple radial circuit traces | black metal, graphite, a small controlled cool-cyan lens accent only | dark machined metal, engraved circuit channels, glassy central lens | the eye and circuits must be bold and sparse enough for 64x64; no letters; no interface text; no humanoid face |
| 탱탱볼 | translucent bouncy-ball token with a bold internal spiral that reads as rubber rather than a magic orb | hot magenta, violet and restrained pink-white highlights | glossy semi-translucent rubber, thick toy-like surface, simple internal swirl | keep a clear dark outer rim; no magical runes; no gemstone facets; no flame |
| 체스 나이트 | chess-knight token with a bold ivory horse-head relief mounted inside a dark circular base | warm ivory, graphite and muted gray | carved ivory or pale bone-like chess material on a dark stone-metal medallion | horse relief must stay entirely inside the circle; recognizable chess knight silhouette at 64x64; no chessboard; no crown |
| 불 원소 | fire-elemental token showing a contained swirling flame vortex sealed inside a dark circular stone-metal medallion | deep red, ember orange, bright yellow core and charcoal | charred cracked stone, dark metal rim, bright contained pixel flame | all flames must remain inside the circular footprint; no flame protrusion; no face; no creature body; preserve a strong dark rim |
