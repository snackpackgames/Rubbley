// The placeholder glow on a Targetable body: an additive rim that brightens toward the
// silhouette, drawn over the body's own material.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform vec4 glow_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float rim_power = 2.5;
uniform float strength = 0.9;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = glow_color.rgb * rim * strength;
}
