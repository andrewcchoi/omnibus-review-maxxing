# Omnibus Review Color Palette

These colors match the CSS variables defined in the HTML documentation.
Use these exact hex values in D2 files for consistency.

| Purpose | CSS Variable | Hex Value | D2 Usage |
|---------|--------------|-----------|----------|
| Phases/Normal | `--low` | `#0d6efd` | `style.fill: "#0d6efd"` |
| Critical/Error | `--critical` | `#dc3545` | `style.fill: "#dc3545"` |
| High/Warning | `--high` | `#fd7e14` | `style.fill: "#fd7e14"` |
| Decision points | `--medium` | `#ffc107` | `style.fill: "#ffc107"` |
| Success/Complete | `--success` | `#198754` | `style.fill: "#198754"` |
| Background | `--background` | `#f8f9fa` | `style.fill: "#f8f9fa"` |
| Text | `--text` | `#212529` | `style.font-color: "#212529"` |
| Border | `--border` | `#dee2e6` | `style.stroke: "#dee2e6"` |

## D2 Theme Note

D2 themes are applied via CLI flags, not in the .d2 file. We use inline
styles instead of themes to maintain exact color matching with the HTML docs.

The build script uses `--theme=0` (neutral) to avoid theme color conflicts.

## Common Patterns

### Phase Box (blue)
```d2
phase1: Phase 1: SCOPE {
  style.fill: "#0d6efd"
  style.font-color: white
  style.border-radius: 8
}
```

### Decision Diamond (yellow)
```d2
check: Staged changes? {
  shape: diamond
  style.fill: "#ffc107"
  style.font-color: "#212529"
}
```

### Success State (green)
```d2
complete: SUCCESS {
  style.fill: "#198754"
  style.font-color: white
  style.border-radius: 8
}
```

### Error State (red)
```d2
error: ERROR {
  style.fill: "#dc3545"
  style.font-color: white
  style.border-radius: 8
}
```

### Container Group
```d2
group: "Group Label" {
  style.fill: "#f8f9fa"
  style.stroke: "#dee2e6"
}
```
