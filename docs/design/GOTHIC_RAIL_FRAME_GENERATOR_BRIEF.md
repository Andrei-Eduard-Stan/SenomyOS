# Gothic Rail frame generator brief

## Production requirements

- Create border artwork only, not a complete bar mockup.
- The border must work around islands from `68x44` to approximately `397x44`
  logical pixels without stretching its corners or changing stroke weight.
- Preferred deliverable: clean SVG with a transparent background. Raster
  fallback: transparent PNG at 4x size; if transparency is unavailable, use a
  perfectly flat `#000000` background for later removal.
- Build one reusable nine-slice base frame. Keep the four corner ornaments in
  fixed square zones and make the straight edge regions seamless and
  repeatable. Do not create a separate full frame for every island.
- Optional second deliverable: one wide-island crest/finial overlay for Senomy
  and telemetry. It must remain separate from the base frame.
- Preserve a completely clear content area. Ornament must stay within the
  outer 6–8 logical pixels and must never cross text, icons, hover fills, or
  pointer targets.
- Use symmetrical Gothic architectural language: restrained lancet arches,
  narrow cathedral tracery, wrought-iron fence rhythm, small spear finials,
  and tapered corner caps.
- Keep the design elegant and technical, not horror-themed. No skulls, bats,
  cobwebs, crosses, gargoyles, letters, logos, buttons, or UI icons.
- The structural stroke should resolve to roughly 1px at final size, with a
  few 2px emphasis nodes. Avoid thick frames and dense filigree.
- Core line colors: cool silver `#DDE0EA`, dim steel `#777C89`, and sparse
  violet energy `#9A72E8`. Keep most of the asset semi-transparent.
- Do not bake a large blur into the artwork. Supply a crisp luminous core;
  Eww/GTK will add the controllable outer glow and hover bloom.
- No perspective, bevelled 3D metal, photographic texture, solid panel fill,
  background scene, drop shadow rectangle, or text.
- Include a preview showing the same base frame at narrow, medium, and wide
  aspect ratios so corner preservation and edge repetition can be judged.

## Copy-paste generator prompt

> Create a production-ready reusable Gothic UI border asset sheet for the
> SenomyOS Obsidian Rail. This is border artwork only, not a screenshot and not
> a complete user interface. Design one horizontally scalable nine-slice frame
> that can surround translucent islands ranging from 68x44 to 397x44 logical
> pixels. Preserve four fixed corner zones and make the middle portions of the
> top, bottom, left, and right edges perfectly seamless and repeatable. Use
> restrained pointed lancet arches, narrow cathedral-window tracery,
> wrought-iron garden-fence rhythm, tiny spear finials, and tapered corner
> caps. The style is dark, precise, futuristic Gothic architecture—elegant and
> technical, never horror-themed. Use a crisp 1px-equivalent cool-silver core
> with dim steel secondary lines and only sparse violet energy accents. Keep
> the center fully empty and transparent, with all ornament confined to the
> outer 6–8 logical pixels. Do not include text, logos, icons, buttons, panel
> fill, scenery, skulls, bats, cobwebs, crosses, gargoyles, perspective, thick
> metal, or a baked rectangular shadow. Do not bake in a large glow; the UI
> compositor will add bloom. Preferred output is clean editable SVG on a
> transparent background. Also provide a 4x transparent PNG preview and show
> the same frame applied at narrow, medium, and wide aspect ratios. If a second
> asset is produced, make it a separate symmetrical wide-island crest/finial
> overlay, not another complete frame.

## Acceptance checks

- Corners are identical at every preview width.
- Long edges repeat without seams or obvious stretched arches.
- The frame remains legible at 44px high.
- The interior is transparent and unobstructed.
- The artwork can be recolored or have opacity adjusted independently of the
  GTK surface and glow.
