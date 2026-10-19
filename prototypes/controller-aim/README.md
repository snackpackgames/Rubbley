# PROTOTYPE: controller aim (throwaway, never merged)

Answers [How should controller aim feel?](https://github.com/snackpackgames/Rubbley/issues/73).
A 2D stand-in for the Play Plane, built for Godot 4.5.1 (the game pins 4.7; this code is throwaway).

Run: `"C:/Program Files/Godot/Godot_v4.5.1-stable_win64.exe" --path prototypes/controller-aim`

Three aim models, switched with LB/RB (or Back, or keys 1/2/3):

- **Hybrid**: stick direction picks a glowing body in a cone; otherwise the point is Rubbley + direction x tilt x range. Rest = self.
- **Directional lock-on**: same cone pick; otherwise the point sits at a fixed distance in the stick direction.
- **Absolute offset + snap**: the point is Rubbley + stick x range, snapping to a glowing body within a radius.

LT Attract (held), RT Repel, A/B Spin, right stick Nudge, D-pad to pick and tune parameters, X for a new layout, Y to make Rubbley drift, Start to reset, P to print the current params. Resize the window to portrait to check the range circle against the short side.
