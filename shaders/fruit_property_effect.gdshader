shader_type canvas_item;

// Frenzy property look for pixel-art fruit sprites: a colour filter over the fruit plus a
// 1-texel outline drawn in the transparent margin around it. One shared ShaderMaterial per
// property keeps all fruits with the same property in a single draw batch.

uniform vec4 outline_color : source_color = vec4(0.18, 0.5, 1.0, 1.0);
uniform vec4 tint_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;

// Fragment COLOR already includes the texture sample, so keep the vertex colour (modulate) aside.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float neighbor = max(
		max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a)
	);

	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 filtered = mix(base.rgb, tint_color.rgb * (0.35 + luma * 0.9), tint_strength);

	vec4 result = vec4(filtered, base.a);
	if (base.a < 0.5) {
		result = vec4(outline_color.rgb, outline_color.a * step(0.5, neighbor));
	}
	COLOR = result * v_modulate;
}
