<script lang="ts">
  // Decorative line-art: a transport helicopter in the hover, inserting troops on ropes — the one
  // scene that says what this tool is for.
  //
  // It lives at the foot of the navigation rail rather than in the header: measured on a 1280px
  // window, the header's spare middle is only ~200px wide and the art landed under the readouts,
  // and a watermark beneath figures a Mission Maker is reading is worse than no watermark. The
  // bottom of the rail is genuinely empty space, so the drawing can breathe and never sits under
  // text. It goes away when the rail collapses into a horizontal bar.
</script>

<svg class="art" viewBox="0 0 300 112" fill="none" aria-hidden="true" focusable="false">
  <g stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
    <!-- main rotor disc, seen edge-on, with a slight cone -->
    <path d="M46 24q104-7 208 0" />
    <path d="M150 24v9" />
    <!-- fuselage: rounded nose at the left, tapering to the tail boom -->
    <path
      d="M112 52q0-19 24-19h44q17 0 23 11l31 4q4 1 0 2l-31 4q-7 8-23 8h-44q-24 0-24-10z"
    />
    <!-- cockpit glazing -->
    <path d="M118 44q6-7 18-8" />
    <!-- tail boom, fin and tail rotor -->
    <path d="M234 50h30" />
    <path d="M258 50l7-16 5 2-6 14" />
    <circle cx="266" cy="41" r="6" />
    <path d="M262 37l8 8M270 37l-8 8" />
    <!-- skids -->
    <path d="M133 62l-3 12M182 62l3 12" />
    <path d="M120 74h74" />
    <!-- fast ropes -->
    <path d="M150 62l-3 46M170 62l4 46" />
    <!-- two troopers on the way down -->
    <g>
      <circle cx="146" cy="82" r="3" />
      <path d="M146 85v9M146 94l-4 7M146 94l4 7M144 87l4-3M148 87l-2-3" />
    </g>
    <g>
      <circle cx="173" cy="96" r="3" />
      <path d="M173 99v8M173 107l-4 5M173 107l4 5M171 101l3-3" />
    </g>
  </g>
</svg>

<style>
  .art {
    display: block;
    width: 100%;
    max-width: 210px;
    height: auto;
    margin: 2.5rem auto 0.5rem;
    color: var(--accent);
    opacity: 0.22;
    pointer-events: none;
  }
  /* The rail becomes a horizontal bar here — no vertical space left to decorate. */
  @media (max-width: 1000px) {
    .art {
      display: none;
    }
  }
</style>
