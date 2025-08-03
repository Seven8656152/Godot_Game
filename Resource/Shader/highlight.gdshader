shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.5, 1.0);
uniform float highlight_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec3 highlight = highlight_color.rgb * highlight_intensity;
    
    // 混合原始颜色和高亮颜色
    vec3 final_color = mix(tex_color.rgb, highlight, highlight_intensity);
    
    // 增强发光效果
    float glow = length(tex_color.rgb) * highlight_intensity;
    final_color += highlight * glow * 0.5;
    
    // 边缘发光效果
    vec2 size = TEXTURE_PIXEL_SIZE * 2.0;
    float alpha = 0.0;
    for (float x = -size.x; x <= size.x; x += size.x) {
        for (float y = -size.y; y <= size.y; y += size.y) {
            alpha = max(alpha, texture(TEXTURE, UV + vec2(x, y)).a);
        }
    }
    float outline = clamp(alpha - tex_color.a, 0.0, 1.0) * highlight_intensity;
    final_color = mix(final_color, highlight_color.rgb, outline);
    
    COLOR = vec4(final_color, tex_color.a);
}