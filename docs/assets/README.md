# The hero image — provenance

`hero.png` is the five stages of the pipeline drawn as five smithing implements, reading left to
right: a brick coke forge with a bed of glowing coals (**forge**), a wrought-steel anvil
(**anvil**), an arming sword whose blade carries the temper colours from straw yellow through
bronze to peacock blue (**temper**), an oak quenching tub with steam rising off the water
(**quench**), and a whetstone in its holder (**hone**).

Drawn with the [`transparent-logo`](https://github.com/forkrul/dotfiles-agents) skill
(`gemini-3-pro-image`, Audubon-era engraved-plate style reference) and cut to a real alpha channel.
**It cannot be reproduced.** An image model draws a different picture every run, so the command
below records *how* it was made and will make another one — not this one. That is why the prompt is
committed beside the asset.

## No lettering

The previous hero baked the words `forge anvil temper quench` into its pixels. Painted text cannot
be re-cropped, restyled or localised, it is illegible at favicon size, and it goes stale silently —
that image still read as a four-stage pipeline long after `hone` became stage five. The stage names
belong in the README's caption and in the pipeline table, never in the image.

## Command

```bash
export GEMINI_API_KEY=...   # never as an argument: it lands in shell history

uv run python3 .claude/skills/transparent-logo/assets/generate_plate.py \
  --objects 5 --warm --size 4K --ratio 21:9 --out plate.jpg --subject "$(cat subject.txt)"

uv run --with pillow python3 .claude/skills/transparent-logo/assets/cut_background.py \
  plate.jpg docs/assets/hero.png --width 1536 --report
```

The subject line is in [`hero-subject.txt`](hero-subject.txt), verbatim.

**Cut:** 5 regions for 5 objects, partial alpha 2.06%, zero opaque key-coloured pixels, zero border
bleed, no fringe over white, mid-grey or `#0d1117`. A region count matching the object count is the
skill's artefact detector; partial alpha in the 2–4% band is the second one.

## What the four rejected plates taught

Five generations, four rejected. Each failure is a property of the *subject*, not of the keyer:

| # | Defect | Cause | Fix applied to the next subject |
| :--- | :--- | :--- | :--- |
| 1 | 28 regions; 69 opaque magenta pixels dithered through the forge's ash arch | An open recess is drawn as dark hatching, so the key colour bleeds between the strokes and the cut half-takes it | Close the recess: *"the brick base is solid and closed, with no arch, no opening, no recess and no cavity"* |
| 2 | 7 regions; flame tips painted **pink**, two of them detached into their own regions | A thin glowing wisp tints towards the magenta key however firmly `--warm` bans rose, and then breaks off | Remove the wisps and name the fire's colours: *"coals glowing in orange, amber and straw yellow only … no flame, no wisp and no spark"* |
| 3 | Clean at 5 regions / 2.48%, but the sword lost its hilt and read as a shard | "A sword blade" is a blade, not a sword | Name every part: *"a straight double-edged blade, a plain straight iron crossguard, a leather-wrapped grip and a rounded iron pommel"* |
| 4 | Clean at 5 regions / 2.33%, but an 18px magenta sliver under the honing guide's clamp | A **narrow enclosed** gap is mostly antialiased fringe, so it fails the keyer's hole test (a hole needs half its pixels above the clear threshold) and survives as opaque key colour | Remove the bridge rather than loosen the keyer: *"the guide lies flat against the stone … with no arch, no bridge, no clamp jaw, no leg and no gap"* |

Findings 1, 2 and 4 are recorded upstream as `L15`–`L17` in the skill's running log.
