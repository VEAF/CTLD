<script lang="ts">
  // Decorative line-art: a transport helicopter in the hover with a crate slung under it — the one
  // scene that says what this tool is for.
  //
  // Composed after a real DCS screenshot David sent: seen head-on rather than in profile, the rotor
  // disc read almost edge-on as a shallow lens, the sling line hanging dead vertical, and the crate
  // already sitting on the ground. The profile sketch this replaces was legible but flat — head-on is
  // how you actually watch a load being placed.
  //
  // Hand-drawn vector rather than the photo itself: a DCS capture is someone else's frame (that one
  // even carries a third party's watermark) and this repo ships publicly.
  //
  // It lives at the foot of the navigation rail, not in the header: measured on a 1280px window the
  // header's spare middle is only ~200px wide and the drawing landed under the readouts. The bottom
  // of the rail is genuinely empty, so it never sits under text. It goes away when the rail collapses
  // into a horizontal bar.
</script>

<svg class="art" viewBox="0 0 220 164" fill="none" aria-hidden="true" focusable="false">
  <g stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <!-- rotor disc, seen almost edge-on: two arcs closing into a shallow lens -->
    <path d="M12 34q98-13 196 0" />
    <path d="M12 34q98 13 196 0" opacity="0.55" />
    <!-- hub and mast -->
    <path d="M110 34v10" />
    <!-- fuselage, head-on: a rounded cabin -->
    <path d="M84 61q0-17 26-17t26 17q0 18-26 18t-26-18z" />
    <!-- glazing -->
    <path d="M93 55q7-8 17-8t17 8" />
    <path d="M110 47v9" opacity="0.6" />
    <!-- main gear, splayed left and right -->
    <path d="M92 76l-11 13M128 76l11 13" />
    <circle cx="79" cy="92" r="3.4" />
    <circle cx="141" cy="92" r="3.4" />
    <!-- sling line, dead vertical, and the hook -->
    <path d="M110 79v39" />
    <circle cx="110" cy="121" r="3" />
    <!-- four-point strop down to the crate -->
    <path d="M110 124l-14 8M110 124l14 8" />
    <!-- the crate, already on the ground: front face plus a top edge for depth -->
    <path d="M96 132h28v20H96z" />
    <path d="M96 132l6-5h28l-6 5" opacity="0.7" />
    <path d="M124 132l6-5v20l-6 5" opacity="0.7" />
    <!-- ground line -->
    <path d="M58 157h104" opacity="0.35" stroke-dasharray="5 7" />
  </g>
</svg>

<style>
  .art {
    display: block;
    width: 100%;
    max-width: 200px;
    height: auto;
    margin: 2.5rem auto 0.5rem;
    color: var(--accent);
    opacity: 0.28;
    pointer-events: none;
  }
  /* The rail becomes a horizontal bar here — no vertical space left to decorate. */
  @media (max-width: 1000px) {
    .art {
      display: none;
    }
  }
</style>
