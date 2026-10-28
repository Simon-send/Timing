---
title: "Physical pointer checks for Flutter web charts"
date: "2026-10-28"
category: developer-experience
module: Results browser verification
problem_type: developer_experience
component: testing_framework
severity: low
applies_when:
  - "A synthetic Flutter web test scrolls a canvas view and then clicks chart controls."
tags: ["flutter-web", "playwright", "canvas", "browser-testing"]
---

# Physical pointer checks for Flutter web charts

## Context

During verification of [Timing PR #10](https://github.com/Simon-send/Timing/pull/10),
accessibility locators remained available after scrolling while their DOM boxes
did not reliably identify the control's painted position. A metric selector
could be above the visible viewport although the browser locator suggested it
was clickable. Forcing a locator click would not establish that the painted control was reachable.

## Guidance

Keep domain/widget checks, then test physical pointer input in a synthetic web
entry point. When accessibility coordinates diverge from the picture, expose
read-only geometry from the Flutter element tree, located by the control's key:

```dart
final box = element.findRenderObject() as RenderBox;
final origin = box.localToGlobal(Offset.zero);
final geometry = {
  'x': origin.dx,
  'y': origin.dy,
  'width': box.size.width,
  'height': box.size.height,
};
```

Publish that geometry through a JS-interop callback in the test entry point.
Scroll the actual Flutter view until the rectangle is visible, read it again,
then send a real browser mouse click at its centre. Scope keys to the intended
pane when two charts have identical descendants. Verify the resulting visible
state, contributing rows and destination URI; do not call application callbacks
or change widget state from JavaScript to make the test pass.

Accessibility assertions still matter. A dialog heading may be represented by
a named group rather than a standalone text node. Inspect the accessibility
tree and the screenshot before treating a missing locator as an app defect.

## Applicability

This is a fallback for canvas-browser verification after scrolling, not a reason
to replace ordinary locators that work. The geometry bridge belongs only in a
synthetic test entry point. Keep authentication and production data out of that
entry point, and block non-local requests during the probe. Confirm both narrow
and wide layouts visually as well as checking interaction results.

The verified probe used physical clicks through bar selection, source-result
navigation, table mode, metric/season changes and empty states at 320 and 1280
pixels. Reading geometry made the check reproducible without changing the app's
input handlers or weakening those assertions.
