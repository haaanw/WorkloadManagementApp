/* @ds-bundle: {"format":4,"namespace":"DesignSystem_cf6e68","components":[{"name":"Button","sourcePath":"components/actions/Button.jsx"},{"name":"IconButton","sourcePath":"components/actions/IconButton.jsx"},{"name":"KeyRow","sourcePath":"components/actions/KeyRow.jsx"},{"name":"AttentionBanner","sourcePath":"components/display/AttentionBanner.jsx"},{"name":"Card","sourcePath":"components/display/Card.jsx"},{"name":"DeltaIndicator","sourcePath":"components/display/DeltaIndicator.jsx"},{"name":"MetricRow","sourcePath":"components/display/MetricRow.jsx"},{"name":"MetricTile","sourcePath":"components/display/MetricTile.jsx"},{"name":"TagChip","sourcePath":"components/display/TagChip.jsx"},{"name":"Toast","sourcePath":"components/display/Toast.jsx"},{"name":"ZoneBadge","sourcePath":"components/display/ZoneBadge.jsx"},{"name":"ReadoutWell","sourcePath":"components/forms/ReadoutWell.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"Stepper","sourcePath":"components/forms/Stepper.jsx"},{"name":"TextField","sourcePath":"components/forms/TextField.jsx"},{"name":"Toggle","sourcePath":"components/forms/Toggle.jsx"},{"name":"SparkBar","sourcePath":"components/instruments/SparkBar.jsx"},{"name":"Sparkline","sourcePath":"components/instruments/Sparkline.jsx"},{"name":"SufficiencyRing","sourcePath":"components/instruments/SufficiencyRing.jsx"},{"name":"TickScale","sourcePath":"components/instruments/TickScale.jsx"},{"name":"ScreenHeader","sourcePath":"components/navigation/ScreenHeader.jsx"},{"name":"SectionHeader","sourcePath":"components/navigation/SectionHeader.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"}],"sourceHashes":{"components/actions/Button.jsx":"0170a1fb2be7","components/actions/IconButton.jsx":"63c26269a3c2","components/actions/KeyRow.jsx":"b0ae4aad7c84","components/display/AttentionBanner.jsx":"f63296985509","components/display/Card.jsx":"504e23c4de42","components/display/DeltaIndicator.jsx":"581dccd2d5fe","components/display/MetricRow.jsx":"7a6f05df71ab","components/display/MetricTile.jsx":"85a9e008a6f2","components/display/TagChip.jsx":"63bdcaffaef5","components/display/Toast.jsx":"e55669545469","components/display/ZoneBadge.jsx":"0f17650987c0","components/forms/ReadoutWell.jsx":"353e163c8ae5","components/forms/SegmentedControl.jsx":"cbec7c639bfb","components/forms/Stepper.jsx":"6587151b5251","components/forms/TextField.jsx":"b21c2ea8a3c4","components/forms/Toggle.jsx":"751acb96c000","components/instruments/SparkBar.jsx":"a4465879106d","components/instruments/Sparkline.jsx":"aa0d1293a05f","components/instruments/SufficiencyRing.jsx":"27c87362fd57","components/instruments/TickScale.jsx":"30e36bbb5228","components/navigation/ScreenHeader.jsx":"f0e935df8697","components/navigation/SectionHeader.jsx":"b3969fc14c85","components/navigation/TabBar.jsx":"bada62c7f025","ui_kits/ios-app/Dashboard.jsx":"984c72e0070f","ui_kits/ios-app/LoadScreen.jsx":"0df89ac98aef","ui_kits/ios-app/WorkoutSheet.jsx":"56f02d376d05","ui_kits/website/motion.js":"e1b4df01551d"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.DesignSystem_cf6e68 = window.DesignSystem_cf6e68 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/actions/Button.jsx
try { (() => {
/* Primary = the ONE ink-filled pill per screen. Secondary = hairline rect (8px). Quiet = text. Never accent-filled. */
function Button({
  variant = 'primary',
  children,
  disabled,
  onClick,
  fullWidth,
  style
}) {
  const [p, setP] = React.useState(false);
  const base = {
    fontFamily: 'var(--font-sans)',
    fontSize: 'var(--text-key)',
    fontWeight: 500,
    minHeight: 44,
    padding: '0 var(--space-md)',
    cursor: disabled ? 'default' : 'pointer',
    border: 'none',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    opacity: disabled ? 0.5 : 1,
    transition: 'transform 100ms var(--ease), background 100ms var(--ease)',
    width: fullWidth ? '100%' : undefined,
    boxSizing: 'border-box',
    ...style
  };
  const v = {
    primary: {
      background: 'var(--cta-fill)',
      color: 'var(--cta-ink)',
      borderRadius: 'var(--radius-pill)',
      boxShadow: p ? 'inset 0 1.5px 0 var(--relief-shade)' : 'inset 0 1px 0 rgba(255,255,254,.25)'
    },
    secondary: {
      background: p ? 'linear-gradient(var(--well-top),var(--well-bottom))' : 'var(--surface-el)',
      color: 'var(--text-1)',
      borderRadius: 'var(--radius-control)',
      border: '0.5px solid var(--divider-strong)'
    },
    quiet: {
      background: 'transparent',
      color: 'var(--text-2)',
      borderRadius: 'var(--radius-control)'
    }
  }[variant];
  return /*#__PURE__*/React.createElement("button", {
    style: {
      ...base,
      ...v
    },
    disabled: disabled,
    onClick: onClick,
    onPointerDown: () => setP(true),
    onPointerUp: () => setP(false),
    onPointerLeave: () => setP(false)
  }, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/Button.jsx", error: String((e && e.message) || e) }); }

// components/actions/IconButton.jsx
try { (() => {
/* 44px square control. Glyph is a Unicode/annotation character (no icon font). */
function IconButton({
  glyph,
  label,
  selected,
  onClick
}) {
  return /*#__PURE__*/React.createElement("button", {
    "aria-label": label,
    onClick: onClick,
    style: {
      width: 44,
      height: 44,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'var(--font-mono)',
      fontSize: 15,
      color: selected ? 'var(--text-1)' : 'var(--text-2)',
      background: selected ? 'var(--surface-el-2)' : 'var(--surface)',
      border: selected ? '0.5px solid var(--divider-strong)' : '0.5px solid var(--divider)',
      borderRadius: 'var(--radius-control)',
      cursor: 'pointer'
    }
  }, glyph);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/actions/KeyRow.jsx
try { (() => {
/* Butted equal-weight decision cells in ONE 12px container — the nocebo guard:
   'act' and 'keep plan' carry identical size/type/press; only the fill differs. */
function KeyRow({
  keys
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      minHeight: 44,
      borderRadius: 'var(--radius-card)',
      overflow: 'hidden',
      border: '0.5px solid var(--divider-strong)'
    }
  }, keys.map((k, i) => [i > 0 && /*#__PURE__*/React.createElement("span", {
    key: 'd' + i,
    style: {
      width: '0.5px',
      background: 'var(--divider-strong)'
    }
  }), /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: k.onClick,
    style: {
      flex: 1,
      border: 'none',
      cursor: 'pointer',
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-key)',
      fontWeight: 500,
      minHeight: 44,
      background: k.role === 'cta' ? 'var(--cta-fill)' : 'var(--surface-el)',
      color: k.role === 'cta' ? 'var(--cta-ink)' : 'var(--text-1)'
    }
  }, k.title)]));
}
Object.assign(__ds_scope, { KeyRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/KeyRow.jsx", error: String((e && e.message) || e) }); }

// components/display/AttentionBanner.jsx
try { (() => {
const zones = {
  optimal: 'var(--zone-optimal)',
  caution: 'var(--zone-caution)',
  danger: 'var(--zone-danger)',
  low: 'var(--zone-low)',
  accent: 'var(--accent)'
};
/* Shared banner plane (PR / spike / fatigue / cycle): standard card + 2px zone rule clipped inside.
   Text label carries the state; the rule is supplementary. */
function AttentionBanner({
  zone = 'caution',
  title,
  message,
  action,
  onAction,
  onDismiss
}) {
  const c = zones[zone] || zones.caution;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      overflow: 'hidden',
      background: 'var(--surface-el)',
      border: '0.5px solid var(--divider)',
      borderRadius: 'var(--radius-card)',
      padding: '14px 16px 14px 18px',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 0,
      top: 0,
      bottom: 0,
      width: 2,
      background: c
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-label)',
      fontWeight: 500,
      color: 'var(--text-1)'
    }
  }, title), message && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--text-small)',
      color: 'var(--text-2)',
      lineHeight: 'var(--leading-body)',
      marginTop: 2
    }
  }, message), action && /*#__PURE__*/React.createElement("button", {
    onClick: onAction,
    style: {
      marginTop: 8,
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-key)',
      fontWeight: 500,
      background: 'none',
      border: 'none',
      padding: 0,
      color: 'var(--text-1)',
      textDecoration: 'underline',
      textUnderlineOffset: 3,
      cursor: 'pointer'
    }
  }, action)), onDismiss && /*#__PURE__*/React.createElement("button", {
    onClick: onDismiss,
    "aria-label": "Dismiss",
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      color: 'var(--text-3)',
      background: 'none',
      border: 'none',
      cursor: 'pointer',
      padding: 0
    }
  }, "\xD7")));
}
Object.assign(__ds_scope, { AttentionBanner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/AttentionBanner.jsx", error: String((e && e.message) || e) }); }

// components/display/Card.jsx
try { (() => {
/* The stone planes. plain = surface-el + divider; emphasis = surface-el-2 + strong hairline;
   raised = milled plate gradient + top highlight; debossed = well pocket. NO shadows. */
function Card({
  variant = 'plain',
  children,
  style,
  padding = 'var(--space-md) var(--space-sm)'
}) {
  const v = {
    plain: {
      background: 'var(--surface-el)',
      border: '0.5px solid var(--divider)',
      borderRadius: 'var(--radius-card)'
    },
    emphasis: {
      background: 'var(--surface-el-2)',
      border: '0.5px solid var(--divider-strong)',
      borderRadius: 'var(--radius-card)'
    },
    raised: {
      background: 'linear-gradient(var(--surface-el-2),var(--surface-el))',
      border: '0.5px solid var(--divider-strong)',
      borderRadius: 'var(--radius-card)',
      boxShadow: 'inset 0 1px 0 var(--relief-highlight)'
    },
    debossed: {
      background: 'linear-gradient(var(--well-top),var(--well-bottom))',
      border: '0.5px solid var(--divider-strong)',
      borderRadius: 'var(--radius-control)',
      boxShadow: 'inset 0 1.5px 0 var(--relief-shade), inset 0 -1px 0 var(--relief-highlight)'
    }
  }[variant];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding,
      boxSizing: 'border-box',
      ...v,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Card.jsx", error: String((e && e.message) || e) }); }

// components/display/DeltaIndicator.jsx
try { (() => {
/* Signed delta glyph in mono: ▲/▼ significant, △/▽ mild, = flat. Color by direction (goodIsUp flips). */
function DeltaIndicator({
  delta,
  goodIsUp = true,
  threshold = 3
}) {
  const flat = delta === 0;
  const up = delta > 0;
  const big = Math.abs(delta) >= threshold;
  const glyph = flat ? '=' : up ? big ? '▲' : '△' : big ? '▼' : '▽';
  const good = flat ? null : up === goodIsUp;
  const color = flat ? 'var(--text-3)' : good ? 'var(--zone-optimal)' : 'var(--zone-caution)';
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      color
    }
  }, glyph, !flat && ' ' + (up ? '+' : '') + delta);
}
Object.assign(__ds_scope, { DeltaIndicator });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/DeltaIndicator.jsx", error: String((e && e.message) || e) }); }

// components/display/MetricRow.jsx
try { (() => {
/* A metric list row: hue identity dot · sans label · mono value + delta. Rows butt with 0.5px separators. */
function MetricRow({
  label,
  value,
  unit,
  delta,
  hue,
  onClick,
  last
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline',
      padding: '12px 0',
      borderBottom: last ? 'none' : '0.5px solid var(--divider)',
      cursor: onClick ? 'pointer' : 'default',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-label)',
      color: 'var(--text-1)',
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8
    }
  }, hue && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: '50%',
      background: hue,
      flex: 'none'
    }
  }), label), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno)',
      color: 'var(--text-1)',
      display: 'inline-flex',
      gap: 6,
      alignItems: 'baseline'
    }
  }, value, unit && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-3)',
      fontSize: 'var(--anno-sm)',
      textTransform: 'uppercase'
    }
  }, unit), delta !== undefined && /*#__PURE__*/React.createElement(__ds_scope.DeltaIndicator, {
    delta: delta
  })));
}
Object.assign(__ds_scope, { MetricRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/MetricRow.jsx", error: String((e && e.message) || e) }); }

// components/display/MetricTile.jsx
try { (() => {
/* Compact stat tile: micro-caps title / tabular value / mono subtitle. */
function MetricTile({
  title,
  value,
  subtitle,
  color = 'var(--text-1)'
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--surface-el)',
      border: '0.5px solid var(--divider)',
      borderRadius: 'var(--radius-card)',
      padding: '12px 16px',
      fontFamily: 'var(--font-sans)',
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--space-pair)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      letterSpacing: '.06em',
      textTransform: 'uppercase',
      color: 'var(--text-3)'
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20,
      fontWeight: 500,
      color,
      fontVariantNumeric: 'tabular-nums'
    }
  }, value), subtitle && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      color: 'var(--text-2)',
      textTransform: 'uppercase'
    }
  }, subtitle));
}
Object.assign(__ds_scope, { MetricTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/MetricTile.jsx", error: String((e && e.message) || e) }); }

// components/display/TagChip.jsx
try { (() => {
/* Behavior tag chip (check-ins): neutral capsule; selected = ink fill. */
function TagChip({
  label,
  selected,
  onClick
}) {
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-small)',
      padding: '6px 14px',
      borderRadius: 'var(--radius-pill)',
      cursor: 'pointer',
      background: selected ? 'var(--text-1)' : 'var(--surface-el)',
      color: selected ? 'var(--ink-inverse)' : 'var(--text-2)',
      border: selected ? '0.5px solid var(--text-1)' : '0.5px solid var(--divider-strong)'
    }
  }, label);
}
Object.assign(__ds_scope, { TagChip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/TagChip.jsx", error: String((e && e.message) || e) }); }

// components/display/Toast.jsx
try { (() => {
/* Transient confirmation: ink plate, inverse text, mono tick. Bottom-center, rises 6px on entrance. */
function Toast({
  message,
  glyph = '✓',
  visible = true
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      background: 'var(--text-1)',
      color: 'var(--ink-inverse)',
      borderRadius: 'var(--radius-pill)',
      padding: '10px 20px',
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-small)',
      opacity: visible ? 1 : 0,
      transform: visible ? 'none' : 'translateY(var(--rise))',
      transition: 'opacity var(--dur-state) var(--ease), transform var(--dur-state) var(--ease)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12
    }
  }, glyph), message);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Toast.jsx", error: String((e && e.message) || e) }); }

// components/display/ZoneBadge.jsx
try { (() => {
const zones = {
  optimal: 'var(--zone-optimal)',
  caution: 'var(--zone-caution)',
  danger: 'var(--zone-danger)',
  low: 'var(--zone-low)'
};
/* Text-first hairline capsule. Zone color = text + border only, never a fill. cjk widens padding, drops caps/tracking. */
function ZoneBadge({
  zone = 'optimal',
  label,
  cjk
}) {
  const c = zones[zone] || zones.optimal;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: cjk ? 'var(--font-cjk)' : 'var(--font-sans)',
      fontSize: 'var(--text-micro)',
      letterSpacing: cjk ? 0 : 'var(--tracking-caps)',
      textTransform: cjk ? 'none' : 'uppercase',
      color: c,
      border: '0.5px solid ' + c,
      borderRadius: 'var(--radius-pill)',
      padding: cjk ? '4px 16px' : '4px 10px',
      display: 'inline-block'
    }
  }, label);
}
Object.assign(__ds_scope, { ZoneBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/ZoneBadge.jsx", error: String((e && e.message) || e) }); }

// components/forms/ReadoutWell.jsx
try { (() => {
/* Fixed-width debossed pocket holding a tabular value + mono unit. */
function ReadoutWell({
  value,
  unit,
  width = 96,
  color = 'var(--text-1)',
  size = 22
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'baseline',
      justifyContent: 'center',
      gap: 6,
      width,
      boxSizing: 'border-box',
      padding: '8px 10px',
      background: 'linear-gradient(var(--well-top),var(--well-bottom))',
      border: '0.5px solid var(--divider-strong)',
      borderRadius: 'var(--radius-control)',
      boxShadow: 'inset 0 1.5px 0 var(--relief-shade), inset 0 -1px 0 var(--relief-highlight)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: size,
      lineHeight: 1.1,
      color,
      fontVariantNumeric: 'tabular-nums'
    }
  }, value), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      color: 'var(--text-3)',
      textTransform: 'uppercase'
    }
  }, unit));
}
Object.assign(__ds_scope, { ReadoutWell });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/ReadoutWell.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
/* Butted segments, hairline separators, 2px ink top-rule on the active cell. */
function SegmentedControl({
  options,
  value,
  onChange
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      minHeight: 44,
      background: 'var(--surface)',
      borderRadius: 'var(--radius-control)',
      overflow: 'hidden',
      border: '0.5px solid var(--divider)'
    }
  }, options.map((o, i) => {
    const sel = o === value;
    return [i > 0 && /*#__PURE__*/React.createElement("span", {
      key: 'd' + i,
      style: {
        width: '0.5px',
        background: 'var(--divider)'
      }
    }), /*#__PURE__*/React.createElement("button", {
      key: o,
      onClick: () => onChange && onChange(o),
      style: {
        flex: 1,
        position: 'relative',
        border: 'none',
        cursor: 'pointer',
        fontFamily: 'var(--font-sans)',
        fontSize: 'var(--text-label)',
        fontWeight: sel ? 500 : 400,
        color: sel ? 'var(--text-1)' : 'var(--text-2)',
        background: sel ? 'var(--surface-el-2)' : 'transparent'
      }
    }, sel && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: 2,
        background: 'var(--divider-strong)'
      }
    }), o)];
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/Stepper.jsx
try { (() => {
/* Detent control: − / readout well / + . Value cell never resizes with digit count. */
function Stepper({
  value,
  onChange,
  min = 0,
  max = 999,
  step = 1,
  unit,
  wellWidth = 88
}) {
  const clamp = v => Math.min(max, Math.max(min, v));
  const b = {
    width: 44,
    height: 44,
    border: '0.5px solid var(--divider-strong)',
    borderRadius: 'var(--radius-control)',
    background: 'linear-gradient(var(--surface-el-2),var(--surface-el))',
    boxShadow: 'inset 0 1px 0 var(--relief-highlight)',
    fontFamily: 'var(--font-mono)',
    fontSize: 16,
    color: 'var(--text-1)',
    cursor: 'pointer'
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 'var(--space-xs)'
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: b,
    onClick: () => onChange && onChange(clamp(value - step)),
    "aria-label": "Decrease"
  }, "\u2212"), /*#__PURE__*/React.createElement(__ds_scope.ReadoutWell, {
    value: value,
    unit: unit,
    width: wellWidth
  }), /*#__PURE__*/React.createElement("button", {
    style: b,
    onClick: () => onChange && onChange(clamp(value + step)),
    "aria-label": "Increase"
  }, "\uFF0B"));
}
Object.assign(__ds_scope, { Stepper });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Stepper.jsx", error: String((e && e.message) || e) }); }

// components/forms/TextField.jsx
try { (() => {
/* Focus thickens the INK hairline to 1px (accent never marks focus). Error uses zone-danger. */
function TextField({
  label,
  value,
  onChange,
  placeholder,
  error,
  type = 'text'
}) {
  const [f, setF] = React.useState(false);
  const bc = error ? 'var(--zone-danger)' : f ? 'var(--text-1)' : 'var(--divider)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--space-pair)',
      fontFamily: 'var(--font-sans)'
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-small)',
      color: 'var(--text-2)'
    }
  }, label), /*#__PURE__*/React.createElement("input", {
    type: type,
    value: value,
    placeholder: placeholder,
    onChange: e => onChange && onChange(e.target.value),
    onFocus: () => setF(true),
    onBlur: () => setF(false),
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-body)',
      color: 'var(--text-1)',
      minHeight: 44,
      padding: '0 var(--space-sm)',
      background: f ? 'linear-gradient(var(--well-top),var(--well-bottom))' : 'var(--surface)',
      border: f || error ? '1px solid ' + bc : '0.5px solid ' + bc,
      borderRadius: 'var(--radius-control)',
      outline: 'none',
      boxSizing: 'border-box',
      transition: 'border-color var(--dur-state) var(--ease)'
    }
  }), error && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-small)',
      color: 'var(--zone-danger)'
    }
  }, error));
}
Object.assign(__ds_scope, { TextField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TextField.jsx", error: String((e && e.message) || e) }); }

// components/forms/Toggle.jsx
try { (() => {
/* Neutral toggle — no Apple green. On-track = ink; knob rides a debossed track. */
function Toggle({
  checked,
  onChange,
  label
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--space-sm)',
      minHeight: 44,
      cursor: 'pointer',
      fontFamily: 'var(--font-sans)',
      fontSize: 'var(--text-body)',
      color: 'var(--text-1)'
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    onClick: () => onChange && onChange(!checked),
    role: "switch",
    "aria-checked": !!checked,
    style: {
      position: 'relative',
      width: 48,
      height: 32,
      borderRadius: 'var(--radius-control)',
      background: checked ? 'var(--text-1)' : 'linear-gradient(var(--well-top),var(--well-bottom))',
      border: '0.5px solid var(--divider-strong)',
      transition: 'background var(--dur-state) var(--ease)',
      boxSizing: 'border-box',
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 3,
      left: checked ? 19 : 3,
      width: 24,
      height: 24,
      borderRadius: 6,
      background: checked ? 'var(--bg)' : 'linear-gradient(var(--surface-el-2),var(--surface-el))',
      border: '0.5px solid var(--divider-strong)',
      boxShadow: 'inset 0 1px 0 var(--relief-highlight)',
      transition: 'left var(--dur-state) var(--ease)',
      boxSizing: 'border-box'
    }
  })));
}
Object.assign(__ds_scope, { Toggle });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Toggle.jsx", error: String((e && e.message) || e) }); }

// components/instruments/SparkBar.jsx
try { (() => {
const LEVELS = '▁▂▃▄▅▆▇█';
/* ASCII spark bars — inline 8-level history in pure text. The last glyph takes the hue. */
function SparkBar({
  data = [],
  hue = 'var(--accent)',
  trailing = 0
}) {
  const min = Math.min(...data),
    max = Math.max(...data),
    span = max - min || 1;
  const g = v => LEVELS[Math.round((v - min) / span * 7)];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno)',
      letterSpacing: 1,
      color: 'var(--text-1)'
    }
  }, data.slice(0, -1).map(g).join(''), /*#__PURE__*/React.createElement("span", {
    style: {
      color: hue
    }
  }, g(data[data.length - 1])), trailing > 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--divider)'
    }
  }, '▁'.repeat(trailing)));
}
Object.assign(__ds_scope, { SparkBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/instruments/SparkBar.jsx", error: String((e && e.message) || e) }); }

// components/instruments/Sparkline.jsx
try { (() => {
/* Plotter sparkline: 1.5px hue line, dashed baseline, mono end annotations, open-circle 'now' marker. */
function Sparkline({
  data = [],
  hue = 'var(--metric-readiness)',
  baseline,
  width = 340,
  height = 40,
  startLabel,
  endLabel
}) {
  const min = Math.min(...data),
    max = Math.max(...data),
    span = max - min || 1;
  const x = i => i / (data.length - 1) * width;
  const y = v => 4 + (1 - (v - min) / span) * (height - 12);
  const d = data.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + y(v).toFixed(1)).join(' ');
  return /*#__PURE__*/React.createElement("svg", {
    width: "100%",
    height: height,
    viewBox: '0 0 ' + width + ' ' + height,
    style: {
      display: 'block'
    }
  }, baseline !== undefined && /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: y(baseline),
    x2: width,
    y2: y(baseline),
    stroke: "var(--text-3)",
    strokeWidth: "1",
    strokeDasharray: "1 3"
  }), /*#__PURE__*/React.createElement("path", {
    d: d,
    fill: "none",
    stroke: hue,
    strokeWidth: "1.5"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: x(data.length - 1),
    cy: y(data[data.length - 1]),
    r: "2.5",
    fill: "var(--surface-el)",
    stroke: hue
  }), startLabel && /*#__PURE__*/React.createElement("text", {
    x: "0",
    y: height - 1,
    fontFamily: "Fragment Mono",
    fontSize: "7",
    fill: "var(--text-3)"
  }, startLabel), endLabel && /*#__PURE__*/React.createElement("text", {
    x: width,
    y: height - 1,
    textAnchor: "end",
    fontFamily: "Fragment Mono",
    fontSize: "7",
    fill: "var(--text-3)"
  }, endLabel));
}
Object.assign(__ds_scope, { Sparkline });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/instruments/Sparkline.jsx", error: String((e && e.message) || e) }); }

// components/instruments/SufficiencyRing.jsx
try { (() => {
/* Data-sufficiency dial: hairline ring, accent arc (live state), tabular % in the middle. */
function SufficiencyRing({
  pct = 0,
  size = 64,
  label
}) {
  const r = size / 2 - 3,
    c = 2 * Math.PI * r;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'inline-flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 4
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: '0 0 ' + size + ' ' + size
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: "var(--divider)",
    strokeWidth: "1"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: "var(--accent)",
    strokeWidth: "2.5",
    strokeDasharray: c * pct / 100 + ' ' + c,
    strokeLinecap: "butt",
    transform: 'rotate(-90 ' + size / 2 + ' ' + size / 2 + ')',
    style: {
      transition: 'stroke-dasharray var(--dur-countup) var(--ease)'
    }
  }), /*#__PURE__*/React.createElement("text", {
    x: "50%",
    y: "50%",
    dy: "0.36em",
    textAnchor: "middle",
    fontFamily: "var(--font-sans)",
    fontSize: size / 4.2,
    fill: "var(--text-1)",
    style: {
      fontVariantNumeric: 'tabular-nums'
    }
  }, Math.round(pct), "%")), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      textTransform: 'uppercase',
      color: 'var(--text-3)'
    }
  }, label));
}
Object.assign(__ds_scope, { SufficiencyRing });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/instruments/SufficiencyRing.jsx", error: String((e && e.message) || e) }); }

// components/instruments/TickScale.jsx
try { (() => {
/* The measured-value grammar: two-weight ticks, optional zone band, 1.5px accent needle.
   Needles travel current→new directly, never back through zero. */
function TickScale({
  value = 0,
  min = 0,
  max = 100,
  zone,
  ghost,
  width = '100%',
  hue = 'var(--accent)'
}) {
  const pct = v => (v - min) / (max - min) * 100;
  const ticks = [];
  for (let i = 0; i <= 16; i++) ticks.push(i);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width,
      height: 26,
      boxSizing: 'border-box'
    }
  }, zone && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: pct(zone[0]) + '%',
      width: pct(zone[1]) - pct(zone[0]) + '%',
      top: 2,
      height: 14,
      background: 'var(--zone-optimal)',
      opacity: .12
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: '2px 0 auto 0',
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'flex-start',
      height: 14
    }
  }, ticks.map(i => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: 1,
      height: i % 4 === 0 ? 12 : 6,
      background: i % 4 === 0 ? 'var(--text-2)' : 'var(--text-3)',
      opacity: i % 4 === 0 ? 1 : .7
    }
  }))), ghost !== undefined && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 'calc(' + pct(ghost) + '% - 0.75px)',
      top: 0,
      width: 1.5,
      height: 18,
      background: 'var(--text-3)',
      opacity: .5
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 'calc(' + pct(value) + '% - 0.75px)',
      top: 0,
      width: 1.5,
      height: 18,
      background: hue,
      transition: 'left var(--dur-countup) var(--ease)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      display: 'flex',
      justifyContent: 'space-between',
      fontFamily: 'var(--font-mono)',
      fontSize: 8,
      color: 'var(--text-3)'
    }
  }, /*#__PURE__*/React.createElement("span", null, min), /*#__PURE__*/React.createElement("span", null, max)));
}
Object.assign(__ds_scope, { TickScale });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/instruments/TickScale.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ScreenHeader.jsx
try { (() => {
/* v1 editorial header: mono context line (annotation register) above a 28px sentence-case title. */
function ScreenHeader({
  title,
  context,
  meta,
  trailing
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-sans)',
      padding: 'var(--space-xs) 0 var(--space-md)'
    }
  }, (context || meta) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      letterSpacing: '.06em',
      textTransform: 'uppercase',
      color: 'var(--text-3)'
    }
  }, context), meta && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      color: 'var(--text-3)'
    }
  }, meta)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 'var(--space-sm)',
      marginTop: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-page-title)',
      color: 'var(--text-1)',
      flex: 1
    }
  }, title), trailing && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontWeight: 500,
      letterSpacing: '.06em',
      textTransform: 'uppercase',
      color: 'var(--text-2)'
    }
  }, trailing)));
}
Object.assign(__ds_scope, { ScreenHeader });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ScreenHeader.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SectionHeader.jsx
try { (() => {
/* 17px/500 section head; optional mono annotation on the right. Sections break with 32px gaps. */
function SectionHeader({
  title,
  anno
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline',
      fontFamily: 'var(--font-sans)',
      marginTop: 'var(--space-lg)',
      marginBottom: 'var(--space-xs)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-section-head)',
      fontWeight: 500,
      color: 'var(--text-1)'
    }
  }, title), anno && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 'var(--anno-sm)',
      textTransform: 'uppercase',
      color: 'var(--text-3)'
    }
  }, anno));
}
Object.assign(__ds_scope, { SectionHeader });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SectionHeader.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
/* Console tab bar: text-only title-case labels on a flat opaque bar; selection = ink step +
   sliding well + the 1.5px accent tick — the app's ONE sanctioned overshoot. No icons. */
function TabBar({
  items,
  active,
  onSelect
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      background: '#ECEBE7',
      borderTop: '0.5px solid var(--divider-strong)',
      fontFamily: 'var(--font-sans)'
    }
  }, items.map(t => {
    const sel = t === active;
    return /*#__PURE__*/React.createElement("button", {
      key: t,
      onClick: () => onSelect && onSelect(t),
      style: {
        flex: 1,
        position: 'relative',
        border: 'none',
        cursor: 'pointer',
        background: sel ? 'rgba(27,26,23,.05)' : 'transparent',
        color: sel ? 'var(--text-1)' : 'var(--text-3)',
        fontFamily: 'inherit',
        fontSize: 'var(--text-tab)',
        fontWeight: 500,
        padding: '14px 0 18px',
        transition: 'color var(--dur-state) var(--ease)'
      }
    }, sel && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: -1,
        left: '25%',
        right: '25%',
        height: 1.5,
        background: 'var(--accent)'
      }
    }), t);
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/Dashboard.jsx
try { (() => {
/* Home / Dashboard — recreation of 01_Dashboard in Field Notes dress. */
function Dashboard({
  onStart
}) {
  const {
    Card,
    Button,
    MetricRow,
    ScreenHeader,
    SectionHeader,
    TickScale,
    SufficiencyRing,
    SparkBar,
    AttentionBanner,
    ZoneBadge
  } = window.DesignSystem_cf6e68;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px'
    }
  }, /*#__PURE__*/React.createElement(ScreenHeader, {
    context: "TUE 07.21 \xB7 WK 30",
    meta: "D-021",
    title: "Dashboard",
    trailing: "Log workout"
  }), /*#__PURE__*/React.createElement(Card, {
    variant: "raised",
    padding: "20px 16px 18px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      letterSpacing: '.06em',
      color: 'var(--metric-readiness)'
    }
  }, "READINESS \u25CF"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-hero)',
      lineHeight: 1.05,
      letterSpacing: '-0.02em',
      color: 'var(--metric-readiness)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, "71"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      color: 'var(--text-2)'
    }
  }, "GO +3/7D")), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(TickScale, {
    value: 71,
    zone: [66, 100],
    ghost: 68,
    hue: "var(--metric-readiness)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      color: 'var(--text-2)',
      marginTop: 10
    }
  }, "GO ZONE \u2014 RECOVERY IS HIGH")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(Card, {
    padding: "4px 16px"
  }, /*#__PURE__*/React.createElement(MetricRow, {
    label: "Resting heart rate",
    value: "\u22123%",
    unit: "vs base",
    hue: "var(--metric-strain)"
  }), /*#__PURE__*/React.createElement(MetricRow, {
    label: "Heart rate variability",
    value: "+0%",
    unit: "vs base",
    hue: "var(--metric-recovery)"
  }), /*#__PURE__*/React.createElement(MetricRow, {
    label: "Sleep",
    value: "7.6",
    unit: "h",
    delta: 0,
    hue: "var(--metric-sleep)",
    last: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(Card, {
    padding: "14px 16px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(SufficiencyRing, {
    pct: 37,
    size: 52
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 500,
      color: 'var(--text-1)'
    }
  }, "3 of 8 weeks"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-2)',
      lineHeight: 1.5
    }
  }, "Keep logging \u2014 periodization insights unlock after 8 weeks.")))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(AttentionBanner, {
    zone: "accent",
    title: "Guidance method updated",
    message: "Readiness now blends HRV and strain history.",
    onDismiss: () => {}
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 20
    }
  }), /*#__PURE__*/React.createElement(Button, {
    fullWidth: true,
    onClick: onStart
  }, "Start session"), /*#__PURE__*/React.createElement(SectionHeader, {
    title: "Training load",
    anno: "LOAD STEADY"
  }), /*#__PURE__*/React.createElement(Card, {
    padding: "14px 16px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement(SparkBar, {
    data: [3, 4, 4, 5, 4, 6, 5, 6, 7, 6, 7, 8],
    hue: "var(--metric-load)",
    trailing: 2
  }), /*#__PURE__*/React.createElement(ZoneBadge, {
    zone: "optimal",
    label: "Load steady"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 9,
      color: 'var(--text-3)',
      marginTop: 8,
      textTransform: 'uppercase'
    }
  }, "ACWR 1.23 \xB7 ATL 47 \xB7 CTL 38 \xB7 TSB \u22129")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }));
}
window.TuwaDashboard = Dashboard;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/Dashboard.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/LoadScreen.jsx
try { (() => {
/* Load & progress — recreation of 02_Workload in Field Notes dress. */
function LoadScreen() {
  const {
    Card,
    MetricTile,
    ScreenHeader,
    SectionHeader,
    TickScale,
    SegmentedControl
  } = window.DesignSystem_cf6e68;
  const [range, setRange] = React.useState('4W');
  const load = [22, 26, 24, 25, 23, 28, 26, 30, 27, 32, 29, 34, 31, 36, 32, 38, 34, 40, 36, 42, 38, 44, 40, 46];
  const tsb = [-1, -2, -1, -3, -2, -4, -3, -5, -4, -6, -5, -7, -6, -8, -7, -9, -8, -9, -9, -10, -9, -11, -10, -9];
  const W = 326,
    H = 120;
  const x = i => i / (load.length - 1) * W;
  const yl = v => 10 + (1 - v / 50) * 80;
  const yt = v => 100 + -v / 12 * 16;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px'
    }
  }, /*#__PURE__*/React.createElement(ScreenHeader, {
    context: "TUE 07.21 \xB7 WK 30",
    meta: "D-021",
    title: "Load & progress",
    trailing: "Share"
  }), /*#__PURE__*/React.createElement(Card, {
    variant: "raised",
    padding: "20px 16px 18px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      letterSpacing: '.06em',
      color: 'var(--metric-load)'
    }
  }, "ACWR \u25CF"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--text-hero)',
      lineHeight: 1.05,
      letterSpacing: '-0.02em',
      color: 'var(--metric-load)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, "1.23"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      color: 'var(--zone-optimal)'
    }
  }, "LOAD STEADY")), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(TickScale, {
    value: 1.23,
    min: 0,
    max: 2,
    zone: [0.8, 1.3],
    hue: "var(--metric-load)"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr 1fr',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(MetricTile, {
    title: "ATL",
    value: "47",
    subtitle: "ACUTE \xB7 7D",
    color: "var(--metric-strain)"
  }), /*#__PURE__*/React.createElement(MetricTile, {
    title: "CTL",
    value: "38",
    subtitle: "CHRONIC \xB7 28D",
    color: "var(--metric-load)"
  }), /*#__PURE__*/React.createElement(MetricTile, {
    title: "TSB",
    value: "\u22129",
    subtitle: "FATIGUED",
    color: "var(--metric-sleep)"
  })), /*#__PURE__*/React.createElement(SectionHeader, {
    title: "Load trend",
    anno: range
  }), /*#__PURE__*/React.createElement(SegmentedControl, {
    options: ['4W', '12W', '6M'],
    value: range,
    onChange: setRange
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement(Card, {
    padding: "14px 12px"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "100%",
    height: H,
    viewBox: '0 0 ' + W + ' ' + H
  }, /*#__PURE__*/React.createElement("g", {
    stroke: "var(--chart-grid)"
  }, /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: "30",
    x2: W,
    y2: "30"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: "60",
    x2: W,
    y2: "60"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: "90",
    x2: W,
    y2: "90"
  })), /*#__PURE__*/React.createElement("path", {
    d: tsb.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + yt(v).toFixed(1)).join(' ') + ' L' + W + ' 100 L0 100 Z',
    fill: "var(--metric-sleep)",
    opacity: ".14"
  }), /*#__PURE__*/React.createElement("path", {
    d: load.map((v, i) => (i ? 'L' : 'M') + x(i).toFixed(1) + ' ' + yl(v).toFixed(1)).join(' '),
    fill: "none",
    stroke: "var(--metric-load)",
    strokeWidth: "1.5"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M0 46 L326 34",
    stroke: "var(--text-3)",
    strokeWidth: "1",
    strokeDasharray: "1 3"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: x(load.length - 1),
    cy: yl(load[load.length - 1]),
    r: "2.5",
    fill: "var(--surface-el)",
    stroke: "var(--metric-load)"
  }), /*#__PURE__*/React.createElement("g", {
    fontFamily: "Fragment Mono",
    fontSize: "8",
    fill: "var(--text-3)"
  }, /*#__PURE__*/React.createElement("text", {
    x: "2",
    y: "10"
  }, "LOAD/AU"), /*#__PURE__*/React.createElement("text", {
    x: "2",
    y: "98"
  }, "TSB"), /*#__PURE__*/React.createElement("text", {
    x: W - 30,
    y: H - 4
  }, "JUL 19"), /*#__PURE__*/React.createElement("text", {
    x: "2",
    y: H - 4
  }, "JUN 28")))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }));
}
window.TuwaLoadScreen = LoadScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/LoadScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/ios-app/WorkoutSheet.jsx
try { (() => {
/* Log workout sheet — recreation of the ActiveWorkout entry sheet in Field Notes dress. */
function WorkoutSheet({
  onClose
}) {
  const {
    Card,
    Button,
    TextField,
    TagChip,
    KeyRow
  } = window.DesignSystem_cf6e68;
  const [name, setName] = React.useState('');
  const [sport, setSport] = React.useState('Strength');
  const sports = [['Strength', '▮▮'], ['Basketball', '●'], ['Aerobic / class', '≋'], ['Other sport', '+']];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'rgba(27,26,23,.12)',
      display: 'flex',
      alignItems: 'flex-end',
      zIndex: 5
    },
    onClick: onClose
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      background: 'var(--bg)',
      borderRadius: '12px 12px 0 0',
      borderTop: '0.5px solid var(--divider-strong)',
      width: '100%',
      padding: '14px 16px 24px',
      boxSizing: 'border-box',
      maxHeight: '88%',
      overflowY: 'auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 16
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    style: {
      background: 'none',
      border: 'none',
      fontFamily: 'var(--font-sans)',
      fontSize: 11,
      fontWeight: 500,
      letterSpacing: '.06em',
      textTransform: 'uppercase',
      color: 'var(--text-2)',
      cursor: 'pointer',
      padding: 0
    }
  }, "Cancel"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20
    }
  }, "Workout"), /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    style: {
      background: 'none',
      border: 'none',
      fontFamily: 'var(--font-sans)',
      fontSize: 11,
      fontWeight: 500,
      letterSpacing: '.06em',
      textTransform: 'uppercase',
      color: 'var(--text-1)',
      cursor: 'pointer',
      padding: 0
    }
  }, "Finish")), /*#__PURE__*/React.createElement(TextField, {
    value: name,
    onChange: setName,
    placeholder: "Session name (optional)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 17,
      fontWeight: 500,
      margin: '20px 0 10px'
    }
  }, "What are you training?"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 10
    }
  }, sports.map(([s, g]) => {
    const sel = s === sport;
    return /*#__PURE__*/React.createElement("button", {
      key: s,
      onClick: () => setSport(s),
      style: {
        fontFamily: 'var(--font-sans)',
        fontSize: 15,
        color: 'var(--text-1)',
        padding: '22px 0',
        cursor: 'pointer',
        borderRadius: 'var(--radius-control)',
        border: sel ? '1px solid var(--text-1)' : '0.5px solid var(--divider-strong)',
        background: sel ? 'linear-gradient(var(--surface-el-2),var(--surface-el))' : 'var(--surface)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 6
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 14,
        color: sel ? 'var(--text-1)' : 'var(--text-3)'
      }
    }, g), s);
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(Card, {
    variant: "debossed",
    padding: "12px 16px"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      textTransform: 'uppercase',
      color: 'var(--text-3)'
    }
  }, "DURATION"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 26,
      fontVariantNumeric: 'tabular-nums'
    }
  }, "0", /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      color: 'var(--text-3)'
    }
  }, " MIN")))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 12
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement(TagChip, {
    label: "Import plan"
  }), /*#__PURE__*/React.createElement(TagChip, {
    label: "From template"
  }), /*#__PURE__*/React.createElement(TagChip, {
    label: "Repeat last"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), /*#__PURE__*/React.createElement(KeyRow, {
    keys: [{
      title: 'Adjust for readiness'
    }, {
      title: '+ Add exercise',
      role: 'cta'
    }]
  })));
}
window.TuwaWorkoutSheet = WorkoutSheet;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/ios-app/WorkoutSheet.jsx", error: String((e && e.message) || e) }); }

// ui_kits/website/motion.js
try { (() => {
/* Tuwa homepage motion — ported from tuwa-website homeMotion.ts (rAF scenes + reveal/count observers). */
(function () {
  'use strict';

  var RM = false;
  try {
    RM = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch (e) {}
  if (!RM) document.documentElement.classList.add('motion');
  /* hero line masks */
  var hl = document.getElementById('heroLines');
  if (hl) {
    if (RM) {
      hl.classList.add('played');
    } else {
      setTimeout(function () {
        hl.classList.add('played');
      }, 120);
    }
  }
  /* count-ups — markup carries final values */
  function runCount(el) {
    var target = parseFloat(el.getAttribute('data-count')) || 0;
    var comma = el.getAttribute('data-comma') === '1';
    function fmt(v) {
      return comma ? v.toLocaleString('en-US') : String(v);
    }
    if (RM) {
      el.textContent = fmt(target);
      return;
    }
    var start = null,
      dur = 500;
    function step(ts) {
      if (start === null) start = ts;
      var t = Math.min((ts - start) / dur, 1);
      var eased = 1 - Math.pow(1 - t, 3);
      el.textContent = fmt(Math.round(target * eased));
      if (t < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }
  /* hero readiness count on load */
  var hs = document.getElementById('heroScore');
  if (hs && !RM) {
    (function () {
      var start = null;
      function step(ts) {
        if (start === null) start = ts;
        var t = Math.min((ts - start) / 700, 1);
        hs.textContent = String(Math.round(82 * (1 - Math.pow(1 - t, 3))));
        if (t < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    })();
  }
  /* reveal + counter observer */
  var revealEls = Array.prototype.slice.call(document.querySelectorAll('[data-reveal]'));
  var countEls = Array.prototype.slice.call(document.querySelectorAll('[data-count]'));
  if (RM || typeof IntersectionObserver === 'undefined') {
    revealEls.forEach(function (el) {
      el.classList.add('in');
    });
    countEls.forEach(runCount);
  } else {
    var counted = new WeakSet();
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;
        io.unobserve(el);
        if (el.hasAttribute('data-reveal') && !el.classList.contains('in')) {
          var sibs = revealEls.filter(function (s) {
            return s.parentElement === el.parentElement && !s.classList.contains('in');
          });
          el.style.transitionDelay = Math.max(sibs.indexOf(el), 0) * 60 + 'ms';
          el.classList.add('in');
        }
        if (el.hasAttribute('data-count') && !counted.has(el)) {
          counted.add(el);
          runCount(el);
        }
      });
    }, {
      threshold: 0.2,
      rootMargin: '0px 0px -5% 0px'
    });
    revealEls.forEach(function (el) {
      io.observe(el);
    });
    countEls.forEach(function (el) {
      io.observe(el);
    });
  }
  /* self-drawing chart — reduced motion handled by CSS (html:not(.motion) shows final state) */
  var spark = document.getElementById('spark');
  if (spark && !RM && typeof IntersectionObserver !== 'undefined') {
    (function () {
      var line = spark.querySelector('path.line'),
        baseline = document.getElementById('baseline'),
        nowDot = document.getElementById('nowDot'),
        drawn = false;
      var cio = new IntersectionObserver(function (es) {
        es.forEach(function (en) {
          if (!en.isIntersecting || drawn) return;
          drawn = true;
          cio.disconnect();
          line.style.transition = 'stroke-dashoffset .9s cubic-bezier(.22,1,.36,1)';
          requestAnimationFrame(function () {
            line.style.strokeDashoffset = '0';
          });
          setTimeout(function () {
            if (baseline) {
              baseline.style.transition = 'opacity .4s';
              baseline.style.opacity = '1';
            }
          }, 700);
          setTimeout(function () {
            if (nowDot) {
              nowDot.style.transition = 'opacity .3s';
              nowDot.style.opacity = '1';
            }
          }, 1000);
        });
      }, {
        threshold: 0.4
      });
      cio.observe(spark);
    })();
  }
  if (RM) return;
  /* ---------- rAF scenes: pinned showcase, zone scrub, fans, ghosts ---------- */
  try {
    var vh = window.innerHeight || 800;
    var clamp01 = function (x) {
      return x < 0 ? 0 : x > 1 ? 1 : x;
    };
    var scenes = [];
    function progressOf(el) {
      var r = el.getBoundingClientRect();
      var span = r.height - vh;
      if (span <= 0) return r.top < 0 ? 1 : 0;
      return clamp01(-r.top / span);
    }
    /* scene: sticky 3-step showcase */
    (function () {
      var wrap = document.getElementById('showWrap');
      if (!wrap) return;
      var railFill = document.getElementById('railFill');
      var plates = Array.prototype.slice.call(wrap.querySelectorAll('.shot'));
      var steps = Array.prototype.slice.call(wrap.querySelectorAll('.sstep'));
      var cur = -1;
      scenes.push({
        el: wrap,
        p: -1,
        fn: function (p) {
          if (railFill) railFill.style.transform = 'scaleY(' + p.toFixed(4) + ')';
          var idx = Math.min(2, Math.floor(p * 3));
          if (idx !== cur) {
            cur = idx;
            plates.forEach(function (pl, i) {
              pl.classList.toggle('active', i === idx);
              pl.classList.toggle('prev', i < idx);
            });
            steps.forEach(function (st, i) {
              st.classList.toggle('active', i === idx);
            });
          }
        }
      });
    })();
    /* scene: pinned strike-zone scrub — ACWR 0.40→1.45, live zone label */
    (function () {
      var wrap = document.getElementById('zoneWrap'),
        bar = document.getElementById('zoneBar'),
        fill = document.getElementById('zoneFill'),
        needle = document.getElementById('zoneNeedle'),
        chip = document.getElementById('zoneChip'),
        label = document.getElementById('zoneLabel');
      if (!(wrap && bar && fill && needle && chip && label)) return;
      var barW = bar.getBoundingClientRect().width || 1;
      window.addEventListener('resize', function () {
        barW = bar.getBoundingClientRect().width || 1;
      });
      needle.style.left = '0';
      fill.style.transformOrigin = 'left';
      var zones = [['Undertraining — room to build', 'var(--zone-low)'], ['In the strike zone', 'var(--zone-optimal)'], ['Trending hot — time to modify', 'var(--zone-caution)'], ['Overreach risk — hold', 'var(--zone-danger)']];
      var curZ = -1;
      scenes.push({
        el: wrap,
        p: -1,
        fn: function (p) {
          var ac = 0.4 + 1.05 * p;
          var pos = ac / 2; /* bar axis runs 0.0–2.0 */
          fill.style.transform = 'scaleX(' + pos.toFixed(4) + ')';
          needle.style.transform = 'translateX(' + (pos * barW).toFixed(1) + 'px)';
          chip.textContent = 'NOW ' + ac.toFixed(2);
          var z = ac < 0.8 ? 0 : ac <= 1.3 ? 1 : ac <= 1.5 ? 2 : 3;
          if (z !== curZ) {
            curZ = z;
            label.textContent = zones[z][0];
            label.style.color = zones[z][1];
          }
        }
      });
    })();
    /* fans + ghost numerals, driven from the same loop */
    var spreads = Array.prototype.slice.call(document.querySelectorAll('[data-spread]'));
    var ghosts = Array.prototype.slice.call(document.querySelectorAll('[data-ghost]'));
    window.addEventListener('resize', function () {
      vh = window.innerHeight || 800;
    });
    function frame() {
      var i, s, p, r, raw, eased, off;
      for (i = 0; i < scenes.length; i++) {
        s = scenes[i];
        p = progressOf(s.el);
        if (Math.abs(p - s.p) > 0.0004) {
          s.p = p;
          s.fn(p);
        }
      }
      for (i = 0; i < spreads.length; i++) {
        r = spreads[i].getBoundingClientRect();
        if (r.bottom < -80 || r.top > vh + 80) continue;
        raw = (vh * 0.92 - r.top) / (vh * 0.55);
        eased = 1 - Math.pow(1 - clamp01(raw), 3);
        spreads[i].style.setProperty('--p', eased.toFixed(4));
      }
      for (i = 0; i < ghosts.length; i++) {
        r = ghosts[i].getBoundingClientRect();
        if (r.bottom < -200 || r.top > vh + 200) continue;
        off = (r.top + r.height / 2 - vh / 2) * -0.08;
        ghosts[i].style.transform = 'translateY(' + off.toFixed(1) + 'px)';
      }
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  } catch (e) {}
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/website/motion.js", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.KeyRow = __ds_scope.KeyRow;

__ds_ns.AttentionBanner = __ds_scope.AttentionBanner;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.DeltaIndicator = __ds_scope.DeltaIndicator;

__ds_ns.MetricRow = __ds_scope.MetricRow;

__ds_ns.MetricTile = __ds_scope.MetricTile;

__ds_ns.TagChip = __ds_scope.TagChip;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.ZoneBadge = __ds_scope.ZoneBadge;

__ds_ns.ReadoutWell = __ds_scope.ReadoutWell;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Stepper = __ds_scope.Stepper;

__ds_ns.TextField = __ds_scope.TextField;

__ds_ns.Toggle = __ds_scope.Toggle;

__ds_ns.SparkBar = __ds_scope.SparkBar;

__ds_ns.Sparkline = __ds_scope.Sparkline;

__ds_ns.SufficiencyRing = __ds_scope.SufficiencyRing;

__ds_ns.TickScale = __ds_scope.TickScale;

__ds_ns.ScreenHeader = __ds_scope.ScreenHeader;

__ds_ns.SectionHeader = __ds_scope.SectionHeader;

__ds_ns.TabBar = __ds_scope.TabBar;

})();
