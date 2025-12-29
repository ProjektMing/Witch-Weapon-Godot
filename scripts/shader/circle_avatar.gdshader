shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);

	// 保存父节点的透明度
	float parent_alpha = COLOR.a;

	// 圆形裁剪
	if (dist > 0.5) {
		COLOR.a = 0.0;
	} else {
		COLOR = texture(TEXTURE, UV);
		// 边缘柔化
		float edge = smoothstep(0.5, 0.48, dist);
		COLOR.a *= edge;
		// 应用父节点的透明度，使头像能跟随界面一起渐变
		COLOR.a *= parent_alpha;
	}
}
