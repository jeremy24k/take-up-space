shader_type canvas_item;

// Dark edges that close in as the time runs out. Drawn in chunky blocks and a
// few flat steps, so it stays pixel art instead of a smooth gradient.
uniform float pressure : hint_range(0.0, 1.0) = 0.0;
uniform float block_size = 6.0;
uniform vec4 tint : source_color = vec4(0.05, 0.0, 0.08, 1.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / block_size) * block_size;
	vec2 centered = (cell / screen_size - 0.5) * vec2(screen_size.x / screen_size.y, 1.0);
	float edge = mix(0.9, 0.3, pressure);
	float alpha = smoothstep(edge, edge + 0.3, length(centered));
	alpha = floor(alpha * 4.0) / 4.0;
	COLOR = vec4(tint.rgb, alpha * 0.92);
}
