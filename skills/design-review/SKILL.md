---
name: design-review
description: Perform visual design audits to ensure clean, polished, Apple-like interfaces with neutral colors and exceptional attention to detail. Use when reviewing UI/UX, frontend implementations, design systems, or visual polish before shipping.
---

# Design Review

Audit visual design for Apple-level quality: clean, polished, neutral, and purposeful. Every element should earn its place.

## Core Principles

**Apple Design Ethos:**
- Content first, chrome minimal
- Neutral palette with purposeful accents
- Generous whitespace breathes
- Typography creates hierarchy
- Motion serves meaning
- Consistency builds trust
- Accessibility is non-negotiable

## Review Checklist

### 1. Color & Palette

**Neutral Foundation:**
- [ ] Primary backgrounds: Pure white (#FFFFFF) or soft gray (#F5F5F7)
- [ ] Secondary surfaces: Light grays (#FAFAFA, #F0F0F0)
- [ ] Text hierarchy: Black (#000000), secondary gray (#6E6E73), tertiary gray (#86868B)
- [ ] Borders/dividers: Ultra-light gray (#E5E5E5, #D2D2D7)
- [ ] Accent color used sparingly (one primary brand color, 10% of UI max)

**Avoid:**
- Multiple accent colors competing
- Saturated backgrounds
- Pure black backgrounds (unless OLED-optimized dark mode)
- Color overload — gradients should be subtle or absent

**Dark Mode (if applicable):**
- [ ] Background: True black (#000000) or system gray (#1C1C1E)
- [ ] Elevated surfaces: #2C2C2E, #3A3A3C
- [ ] Text: White (#FFFFFF), secondary (#98989D), tertiary (#6E6E73)

### 2. Typography

**Hierarchy & Scale:**
- [ ] Large Title: 34px, bold (SF Pro Display)
- [ ] Title 1: 28px, bold
- [ ] Title 2: 22px, bold
- [ ] Title 3: 20px, semibold
- [ ] Headline: 17px, semibold
- [ ] Body: 17px, regular (primary reading)
- [ ] Callout: 16px, semibold
- [ ] Subheadline: 15px, regular
- [ ] Footnote: 13px, regular
- [ ] Caption: 12px, regular

**Rules:**
- [ ] Maximum 3 type sizes per screen
- [ ] Line height 1.4-1.5 for body text
- [ ] Letter-spacing: -0.4px for large titles, 0 for body
- [ ] Font weights: Regular (400), Medium (500), Semibold (600), Bold (700)
- [ ] System fonts preferred (SF Pro, -apple-system, Segoe UI, Roboto)

### 3. Spacing & Layout

**Grid & Rhythm:**
- [ ] Base unit: 8px (multiples: 8, 16, 24, 32, 48, 64)
- [ ] Screen edge padding: 16-20px mobile, 24-48px desktop
- [ ] Card padding: 16-24px
- [ ] Section spacing: 32-64px
- [ ] Element spacing: 8-16px

**Whitespace:**
- [ ] Content never touches screen edges
- [ ] Breathing room around every element
- [ ] Group related items (proximity principle)
- [ ] Separate distinct sections clearly

### 4. Shape & Depth

**Corners:**
- [ ] Cards/containers: 8-12px radius
- [ ] Buttons: 8px (filled) or full-round (outlined)
- [ ] Modals: 12-16px radius
- [ ] Avatars: 50% (circular) or 8px (squircle)

**Shadows (use sparingly):**
- [ ] Cards: 0 1px 3px rgba(0,0,0,0.08)
- [ ] Modals: 0 4px 20px rgba(0,0,0,0.15)
- [ ] No shadows on flat backgrounds (use borders instead)

**Borders:**
- [ ] 1px solid rgba(0,0,0,0.08) for subtle separation
- [ ] Prefer borders over shadows for static elements

### 5. Components

**Buttons:**
- [ ] Primary: Filled, 8px radius, 44px min height
- [ ] Secondary: Outlined or ghost
- [ ] Destructive: Red accent, used sparingly
- [ ] Disabled: 50% opacity, not grayed out

**Inputs:**
- [ ] 44px min height (touch target)
- [ ] 12px horizontal padding
- [ ] 1px border, 8px radius
- [ ] Focus state: Accent color border (2px)
- [ ] Placeholder: Tertiary text color

**Cards:**
- [ ] White/elevated background
- [ ] 8-12px radius
- [ ] Subtle border OR shadow, never both heavy
- [ ] 16-24px internal padding

**Navigation:**
- [ ] Tab bar: 49px height, icon + label
- [ ] Nav bar: 44px height, clear title
- [ ] Back button: Chevron + text, never just "Back"

### 6. Motion & Interaction

**Purposeful Animation:**
- [ ] Transitions: 200-300ms ease-out
- [ ] Micro-interactions: 100-150ms
- [ ] Page transitions: 300-400ms
- [ ] Use transform/opacity (GPU-accelerated)
- [ ] Respect prefers-reduced-motion

**Feedback:**
- [ ] Buttons: Active state opacity 0.8
- [ ] Touch targets: 44px minimum
- [ ] Loading: Skeleton screens over spinners
- [ ] Success: Subtle checkmark animation

### 7. Imagery & Icons

**Images:**
- [ ] High resolution (2x minimum, 3x preferred)
- [ ] Consistent aspect ratios
- [ ] Rounded corners match container
- [ ] No clip art or generic stock photos
- [ ] Prefer photography over illustration

**Icons:**
- [ ] Consistent set (SF Symbols, Lucide, or custom)
- [ ] Stroke width consistent (1.5-2px)
- [ ] 24px default, 20px compact
- [ ] Filled for active states
- [ ] Clear metaphors, no ambiguity

### 8. Accessibility

**Non-negotiable:**
- [ ] Color contrast 4.5:1 minimum (7:1 preferred)
- [ ] Touch targets 44x44px minimum
- [ ] Focus indicators visible
- [ ] Screen reader labels present
- [ ] No information conveyed by color alone
- [ ] Scalable text (200% without breaking)
- [ ] Reduced motion respected

## Review Output

Structure findings:

```markdown
## Design Review Summary
**Verdict:** [✅ APPROVED / ⚠️ APPROVED WITH NOTES / ❌ NEEDS WORK]

---

## 🔴 Critical

### 1. [Element] — [Issue]
**Problem:** [Description]
**Apple Standard:** [Reference principle]
**Fix:** [Specific guidance]

---

## 🟠 Improvements

### 2. [Element] — [Issue]
**Current:** [What exists]
**Suggested:** [Apple-inspired alternative]
**Rationale:** [Why it matters]

---

## 🟡 Polish

[List of minor refinements]

---

## ✅ Strengths

[What's working well]
```

## Code-Level Checks

For CSS/Tailwind/Styled Components:

```css
/* ✅ Apple-like */
.card {
  background: #ffffff;
  border-radius: 12px;
  padding: 24px;
  border: 1px solid rgba(0, 0, 0, 0.08);
}

.text-secondary {
  color: #6e6e73;
  font-size: 15px;
  line-height: 1.4;
}

/* ❌ Avoid */
.card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 4px;
  padding: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.3);
}
```

## Platform Notes

**iOS/macOS:**
- Use SF Pro font family
- Follow Human Interface Guidelines
- Support Dynamic Type

**Web:**
- System font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI"`
- Smooth scrolling: `scroll-behavior: smooth`
- Touch action optimization

**Android:**
- Material You with neutral palette
- Roboto font family
- 48dp touch targets
