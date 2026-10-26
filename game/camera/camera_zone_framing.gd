class_name CameraZoneFraming
extends Resource
## How a Camera Zone frames the view while Rubbley is inside it (ADR 0007). Read-only
## at runtime.

## Where zones overlap, the highest priority wins.
@export var priority := 0
## The least the screen's short side shows inside the zone, in metres. It only widens
## the view: Rubbley's size still wins when it calls for more. At most 1000 m, which
## keeps the camera (about 1.4 × extent away) inside the [Starfield] quad at 1800 m.
@export_range(1.0, 1000.0, 0.1) var extent_m := 100.0
