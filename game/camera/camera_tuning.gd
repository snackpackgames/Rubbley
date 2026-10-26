class_name CameraTuning
extends Resource
## How the CameraRig follows, frames and zooms on Rubbley (ADRs 0007, 0017). Read-only
## at runtime. Lengths on screen are fractions of the screen's short side.

## Seconds for the camera to close half its gap to Rubbley. 0 is a hard lock.
@export_range(0.0, 2.0, 0.01, "or_greater") var follow_half_life_s := 0.15
## The furthest Rubbley may sit from the centre of the screen, follow lag and Nudge
## together, as a fraction of the short side. At 0.5 his centre reaches the edge of the
## screen, so keep it well under that for all of him to stay on screen.
@export_range(0.0, 0.5, 0.01) var max_offset := 0.3
## How far a full Nudge peeks, as a fraction of the short side. Capped by max offset.
@export_range(0.0, 0.5, 0.01) var nudge_radius := 0.25
## Seconds for a Nudge to close half its gap to where the input points, and to spring
## half the way back once released.
@export_range(0.0, 2.0, 0.01, "or_greater") var nudge_half_life_s := 0.12
## The camera's angle from looking straight down, in degrees, leaning back toward +Z.
@export_range(0.0, 60.0, 0.1) var tilt_deg := 15.0
## The camera's vertical field of view, in degrees, held on the short side (ADR 0007).
@export_range(30.0, 40.0, 0.1) var fov_deg := 40.0
## Rubbley's radius as a fraction of the short side, so the view zooms out as he grows.
## The controller-aim prototype shows about 80 m of short side round his 1 m radius.
@export_range(0.001, 0.5, 0.0001) var rubbley_screen_fraction := 0.0125
## The least the short side shows, in metres, however small Rubbley is.
@export_range(1.0, 1000.0, 0.1) var min_extent_m := 40.0
## The most the short side shows from Rubbley's size alone, in metres. Camera Zones may
## show more. Capped like [member CameraZoneFraming.extent_m].
@export_range(1.0, 1000.0, 0.1) var max_extent_m := 300.0
## Seconds for the zoom to close half its gap to the extent it is heading for.
@export_range(0.0, 5.0, 0.01, "or_greater") var zoom_half_life_s := 0.5
