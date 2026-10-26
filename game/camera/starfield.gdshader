// The placeholder background (ADR 0008): points of light hashed from a grid on three
// layers, each scrolling at its own share of the CameraRig's motion for parallax.
// Drawn on a far quad that covers the camera's view, in screen space.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// The rig's focus on the Play Plane, as world (x, z) in metres.
uniform vec2 focus_m = vec2(0.0);
// How many metres the screen's short side shows.
uniform float extent_m = 80.0;
// The share of the rig's motion each layer scrolls by, far to near.
uniform vec3 layer_rates = vec3(0.05, 0.15, 0.35);
// The grid spacing of each layer, in metres; at most one star per cell.
uniform vec3 layer_cell_m = vec3(3.0, 5.0, 8.0);
// The brightest each layer's stars get, far to near.
uniform vec3 layer_brightness = vec3(0.45, 0.7, 1.0);
// The share of cells that hold a star.
uniform float density : hint_range(0.0, 1.0) = 0.15;
// A star's radius, in pixels.
uniform float star_radius_px = 1.4;
uniform vec4 space_colour : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform vec4 star_colour : source_color = vec4(0.9, 0.92, 1.0, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// The light at [p] metres on a layer whose cells are [cell_m] metres across.
float star(vec2 p, float cell_m, float radius_m, float seed) {
	vec2 cell = floor(p / cell_m);
	float h = hash(cell + seed);
	if (h > density) {
		return 0.0;
	}
	vec2 centre = (vec2(hash(cell + seed + 17.0), hash(cell + seed + 31.0)) * 0.8 + 0.1) * cell_m;
	float d = length(p - cell * cell_m - centre);
	// Dimmer stars for higher hashes, so brightness varies within a layer.
	return (1.0 - 0.6 * h / density) * smoothstep(radius_m, 0.0, d);
}

void fragment() {
	vec2 screen_px = VIEWPORT_SIZE;
	float short_px = min(screen_px.x, screen_px.y);
	// Screen down is world +Z, so screen offsets read straight onto the plane.
	// FRAGCOORD counts up from the bottom of the screen.
	vec2 frag_px = vec2(FRAGCOORD.x, screen_px.y - FRAGCOORD.y);
	vec2 offset_m = (frag_px - 0.5 * screen_px) / short_px * extent_m;
	float radius_m = star_radius_px * extent_m / short_px;
	float light = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 p = focus_m * layer_rates[i] + offset_m;
		light = max(light, layer_brightness[i] * star(p, layer_cell_m[i], radius_m, float(i) * 101.0));
	}
	ALBEDO = mix(space_colour, star_colour, light).rgb;
}
