# 使用した生成プロンプト

生成方法：組み込み image_gen。CLI/APIは使用していない。
後続のアトラスでは `concept.png` を同一キャラクターの参照として使用。

## イメージイラスト

```text
Use case: stylized-concept
Asset type: finished character concept illustration for original 2D side-scrolling action game UMBRUST.
Primary request: illustrate the playable character "疾走者 / The Runner", a fast, solitary explorer crossing a land consumed by black rust. One adult androgynous human hero, athletic lean silhouette, practical worn light armor, ivory segmented half-helmet with a narrow dark horizontal visor and a tiny warm amber eye slit, smoke charcoal hood pushed back, short asymmetric desaturated blue-teal cloak, long weathered amber-orange scarf flowing left, pale steel forearm and shin plates, dark wrapped boots and leather belt with one small recovery flask. No exposed face. One modest worn straight sword held low in the right hand, never an oversized fantasy sword.
Style: premium hand-painted dark fantasy concept art, crisp silhouette, confident angular brushwork, restrained detail, beautiful material contrast, readable shape language. Original design, not a rendition of an existing franchise.
Composition: portrait canvas, single complete full-body character from helmet to boots, dynamic but clear three-quarter stance facing right, leave breathing room around every extremity and trailing scarf. Character fills most of canvas. Atmospheric ruined forge arches far behind, black branching corrosion in the earth, a few warm embers. The hero remains much lighter and sharper than the quiet backdrop.
Palette: soot navy #101a21, weathered teal #35454a, pale bone steel #dfe8dc, ember amber #e8b475. Soft cool rim light and warm reflected furnace light.
Constraints: no text, no logo, no watermark, no UI, no collage, no extra characters, no gore. This is the visual identity reference for a practical game sprite set.
```

## 透過キャラクターアトラス

```text
Use case: identity-preserve
Asset type: production 2D side-scroller CHARACTER ANIMATION ATLAS, transparent PNG, square 2048x2048 if possible.
Input image 1 is the identity reference, not the output layout. Translate that SAME ivory armored visor helmet, amber scarf, dark teal short cape, dark boots and leather belt into readable hand-painted game sprites with bold clean outlines and 4.5-head-tall proportions. Simplify fine detail for display at 64px tall. Do NOT reproduce the painting background.
MANDATORY LAYOUT: exactly 4 equal columns by 4 equal rows = 16 isolated full-body frames. No grid lines or labels. Every cell is one quarter of canvas width and height. Each frame must stay within its own cell with generous fully transparent margins. ALL frames face RIGHT in strict side view, orthographic, identical character scale and proportions, no perspective. The pelvis anchor is centered horizontally in each cell. In grounded poses both sole contact and lowest foot are at 88% of cell height. Helmet top in standing pose approximately 18% of cell height. Never trim or crop any body part. Keep scarf short enough to stay in its cell.
Read cells left to right, top to bottom:
Row 1: four subtle idle breathing poses, legs planted, right forearm bent forward ready to grip a separately rendered weapon.
Row 2: four distinct running-cycle poses: right leg extended forward / legs passing under body / left leg extended forward / opposite passing pose. Arms and scarf react naturally. Maintain body scale and ground line.
Row 3: jump rising with tucked legs / jump falling with legs lowered / low horizontal forward dash with bent knees / recoiling from a hit.
Row 4: attack wind-up right hand lifted / attack forward extension right hand extended at chest height / attack recovery right hand lowering / healing with a small warm amber flask near the visor.
NO WEAPONS in any frame: sword/spear/axe will be separate layers; hands should hold an imaginary hilt. Exception: the small healing flask in the final frame.
Use restrained painterly game art, strong silhouette, pale helmet and armor, amber scarf, dark teal cape. Flat consistent lighting for all cells. No cast shadows, no ground plane, no glow cloud, no particles, no background, no watermark, no text, no duplicate or additional figures. Actual transparent alpha background, not a painted checkerboard.
```

## 透過武器アトラス

```text
Use case: stylized-concept
Asset type: transparent equipment atlas for a 2D side-scrolling action game.
Input image 1 is the character/material reference. Create THREE separate hand-painted weapons that belong to this character's worn ivory-steel, dark leather and ember-amber visual world. Clean outlined sprite art, simplified for small in-game rendering.
Output layout: a square transparent canvas divided invisibly into THREE EQUAL HORIZONTAL ROWS. Exactly ONE weapon per row, with ample transparent space around it and no overlap between rows. Each weapon is viewed flat from the side, horizontally oriented: pommel/butt at LEFT, blade/tip at RIGHT. No foreshortening. No visible grid, no labels.
Top row: worn straight sword, narrow pale steel double-edged blade with a few black rust scars, small brass crossguard, dark leather handle.
Middle row: long mining-bell spear, ash wood shaft, small amber cloth tie near the blade, narrow long steel spearhead.
Bottom row: compact heavy miner's war axe, dark wood straight handle extending left to right, pale chipped crescent axe head at the right end, black rust veins near the socket.
Match the pale armor metal and warm bronze accents of the reference. These are separate EQUIPMENT assets, not held by a hand. No human, no hand, no character, no shadow, no floor, no scenic background, no particles, no text, no signature, no glow outside object edges. TRUE alpha transparency.
```
