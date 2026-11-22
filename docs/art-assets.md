# 河谷美术素材

《稻生江畔》0.3 的六张栅格素材由内置 ImageGen 生成功能制作。下列记录包含原图、在游戏中的用途和实际生成提示。屋体、农机、水车、农人、桥梁及田埂由 Godot 建模，植被用带透明通道的图像在三维场景中成片绘制。

## 河漫滩草皮

河岸与坡地的地表底色，随坡度、高度和季节着色。 [查看原图](../desktop/art/floodplain-grass.png)

```text
A single square seamless tileable photorealistic diffuse albedo texture for a 2.5D Yangtze floodplain terrain mesh. Orthographic camera directly overhead, sampling a 3 metre patch of short fine olive-sage meadow grasses intermingled with moss, occasional tawny dried grass and tiny patches of humid dark silt. Extremely fine natural variation, restrained contrast, matte even overcast illumination for physically shading in a game engine. Texture fills frame edge to edge. No horizon, no trees, no flowers, no objects, no stones larger than a blade cluster, no cast shadows or vignette, absolutely no titles, borders, text or layout.
```

## 江畔晨景

标题画面的河谷全景。 [查看原图](../desktop/art/river-dawn.png)

```text
Wide landscape 16:9 key art for an original premium Chinese agricultural strategy game in the middle Yangtze valley. Art-directed painterly realism, detailed finely brushed editorial landscape with a subtle silk-paper grain. Asymmetric cinematic view from a small shady wooded hill on the left toward an expansive meandering turquoise river on the right, connected geometric golden-green rice paddies with earthen bunds, a few timber and grey tile farmhouses, distant river boat, layered blue mist peaks. Right foreground reveals rice panicles and a farmer with bamboo hat. Late summer morning, warm low sunshine and atmospheric perspective. Deep shaded left third reserved for a game title added separately. Natural muted jade and warm brass palette, luminous water, small human scale, no fantasy, no snow, no reference to any existing game or painting, no characters or writing, no logos, absolutely no text or interface.
```

## 榆树

丘陵与台地的透明树冠和树干，成片实例化渲染。 [查看原图](../desktop/art/valley-elm.png)

```text
Create a single exquisitely realistic Chinese elm tree cutout, a game foliage texture for a Yangtze valley strategy diorama. One complete middle-aged, naturally irregular asymmetrical canopy and visible forked grey-brown trunk, broken canopy edges, small warm green leaves, multiple overlapping boughs with dark interior and distinct translucent tips. Isolated with genuine transparent alpha, no background, no shadow on the ground, no grass, no scenery. Entire tree from foot of trunk to crown centered with small clear margins. Orthographic camera looks down from 34 degrees above the horizon. Gentle diffuse morning sunlight from upper left. Refined photoreal botanical asset at legible miniature scale, muted jade color, no ink outline, no text.
```

## 垂柳

沿湿地和河岸分布的透明树冠，与榆树林形成不同轮廓。 [查看原图](../desktop/art/river-willow.png)

```text
Single full mature riverside Chinese weeping willow tree isolated on true transparent alpha for a photoreal isometric agriculture game. Narrow irregular canopy with weeping curtains of fine olive-green leaves, slender flexible branches, visible grey forking and slightly leaning trunk, taller than wide. Show whole tree with small clear margins including trunk foot, no ground, no shadow on ground, no scenery, absolutely no border, text or additional tree. Orthographic view from 34 degrees above horizon, gentle late morning light from upper left, dark interior foliage and delicate softly glowing leaf fringes, readable from a distance.
```

## 稻丛

稻田与秧圃使用的作物贴片，程序控制位置、株高、成熟色和风摆。 [查看原图](../desktop/art/rice-clump.png)

```text
A single isolated mature clump of Yangtze paddy rice as a photoreal agricultural game sprite, high angle 32 degrees above the horizon orthographic. Roughly twelve slender stalks from one compact shared point at bottom center, elegant slightly bent green-ochre blades, heavy drooping golden panicles with distinct small grains. Dense tuft, legs of stems visible at base, wider middle than at foot. Restrained real palette with natural warm highlights and cooler green undersides, morning light upper left. Frame entire plant centered with slight clear margins. Genuine transparent background all around and between the blades. No field, no soil, no pots, no ground shadow, no labels or border, no illustration outlines.
```

## 苇草屋面

茅屋与高脚仓屋顶使用的纹理，映射到实际三维屋面。 [查看原图](../desktop/art/reed-thatch.png)

```text
A square seamless PBR albedo material texture of carefully combed reed thatch on a traditional Yangtze granary roof. The uniform dried reeds all run vertically from top to bottom, in shingled softly overlapping bundles with delicate dark grooves and frayed reed ends, warm mid-value umber, muted honey brown, decades of gentle weathering. Orthographic perpendicular macro texture scan, neutral diffuse shadowless overcast light, no directional shadows, no building outline, sky, objects, nails, text or frame. Edge-to-edge, tileable in both directions. Fine realistic scale for an isometric 3D game roof.
```

## 六地起始生态

新战役的生态选址图从这张图集中分格取样。 [查看图集](../desktop/art/atlas-habitats.png)

```text
A production game asset for a naturalist's agricultural strategy game. Exactly SIX distinct landscape paintings in a mathematically regular 3-column by 2-row contact sheet. Horizontal 3:2 overall aspect ratio. Each cell is an edge-to-edge square painting viewed from above at a gentle angle with a distant horizon in its upper third. No margins, lines, text, letters, captions or numbers anywhere. Same refined gouache on subtly textured rag paper, warm raking light, natural restrained pigments, crisply backlit highlights, individually painted ecological detail. Each cell must read as a distinct place in a thumbnail. Strictly ordered: top left the lush Yangtze floodplain with silvery narrow oxbows, willow and paddy; top middle warm ochre Sahel savanna with sparse acacias and fields of millet; top right a rolling verdant temperate Danube valley with wheat strips and patches of blue river. Bottom left Andean terraced rocky highland mountain slopes with tiny high lakes; bottom middle a blue-green tidal marine estuary opening to the sea, tidal flats, dunes and white surf; bottom right a warm Mesoamerican volcanic plateau with patchwork golden maize gardens beneath far blue mountains. No people in foreground, no UI. Six equal cells, no center hero.
```

## 种圃的六种作物

种圃按顺序展示稻、粟、麦、薯、豆和玉米的植株与收获部位。 [查看图集](../desktop/art/atlas-crops.png)

```text
A beautiful original field-guide illustration atlas for an agricultural simulation. Single 3:2 horizontal sheet, SIX precisely equal square cells in a three-column by two-row arrangement with no divider, no margins between cells, no lettering anywhere. Each individual still life centered and fully contained in its own cell, breathing room. Consistent antique naturalist gouache with fine linework on a soft, lightly speckled warm ivory paper field. Legible, accurate farm crop shapes with muted greens, rust brown and honey ochre, each with a small cast shadow. Top left: delicate loose branched drooping golden rice panicles and slim grass leaves. Top middle: two club-like dense pearl millet seed heads, leaves. Top right: two unmistakable awned wheat ears on straw. Bottom left: three earthy potato tubers cutaway pale flesh, specimen stem leaves. Bottom middle: dry common bean pods split to show red and cream beans with trifoliate leaves. Bottom right: yellow maize cob partially uncovered by curled green husks, visible corn kernels. Natural history museum quality, simple specimen plates, no decorative border, no figures, no graphic symbols. All botanical content stays inset 12 percent from its cell edges.
```

## 农学手册的传统农技插画

六幅插画供正式版课题页使用，依次绘有曲辕犁、耧车、龙骨水车、稻鱼田、扬场竹箕和梯田。插画是对工具与田间场景的美术概括。[查看原图](../desktop/art/heritage-implements.png)

```text
A landscape 3:2 contact sheet of six square full-bleed original illustrations for the research almanac in a Chinese historical agriculture strategy game. Precisely equal 3 columns, 2 rows, no gutters, no text, no letters, no numbers or frames. Warm ivory silk-paper background, restrained malachite, iron oxide, umber and ink lines, muted golden light. Elegant accurate museum reconstruction in naturalist watercolor and fine engraved linework; objects centered, silhouettes and action read clearly at 130 pixels. TOP LEFT: a traditional Chinese curved-beam wooden plough, one curved draught pole, angled iron share and two handles placed on freshly turned soil. TOP MIDDLE: a traditional wooden multi-tube grain seed drill (lou che), wooden seed hopper above three downward sowing legs on rows in earth, no modern wheels. TOP RIGHT: a Chinese wooden dragon-back chain irrigation pump, inclined wooden trough with chain of flat wooden paddles lifting water from a canal into a higher field, isometric cutaway. BOTTOM LEFT: close section of traditional Qingtian rice-fish paddy, green rice stalks above water and two small carp below. BOTTOM MIDDLE: a split-willow winnowing basket tossing golden grain with a curved trail of chaff in a breeze above a threshing floor. BOTTOM RIGHT: soil profile through a traditional hill terrace, stone retaining wall, deep brown soil, small crop roots and grasses. Each drawing independent with generous negative ivory space and no overlay. Original field manual art, no decoration beyond the actual subjects.
```
