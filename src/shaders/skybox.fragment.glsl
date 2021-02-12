// [1] Banding in games http://loopit.dk/banding_in_games.pdf

varying lowp vec3 v_uv;

uniform lowp samplerCube u_cubemap;
uniform lowp float u_opacity;
uniform highp float u_temporal_offset;
uniform highp vec3 u_sun_direction;

highp vec3 hash(highp vec2 p) {
    highp vec3 p3 = fract(vec3(p.xyx) * vec3(443.8975, 397.2973, 491.1871));
    p3 += dot(p3, p3.yxz + 19.19);
    return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

vec3 dither(vec3 color, highp vec2 seed) {
    vec3 rnd = hash(seed) + hash(seed + 0.59374) - 0.5;
    color.rgb += rnd / 255.0;
    return color;
}

float sun_disk(highp vec3 ray_direction, highp vec3 sun_direction) {
    highp float cos_angle = dot(normalize(ray_direction), sun_direction);

    // Sun angular angle is ~0.5°
    const highp float cos_sun_angular_diameter = 0.99996192306;
    const highp float smoothstep_delta = 1e-5;

    return smoothstep(
        cos_sun_angular_diameter - smoothstep_delta,
        cos_sun_angular_diameter + smoothstep_delta,
        cos_angle);
}

float map(float value, float start, float end, float new_start, float new_end) {
    return ((value - start) * (new_end - new_start)) / (end - start) + new_start;
}

void main() {
    vec3 uv = v_uv;

    // Add a small offset to prevent black bands around areas where
    // the scattering algorithm does not manage to gather lighting
    //const float y_bias = 0.015;
    //uv.y += y_bias;

    // Inverse of the operation applied for non-linear UV parameterization
    //uv.y = pow(abs(uv.y), 1.0 / 5.0);

    // To make better utilization of the visible range (e.g. over the horizon, UVs
    // from 0.0 to 1.0 on the Y-axis in cubemap space), the UV range is remapped from
    // (0.0,1.0) to (-1.0,1.0) on y. The inverse operation is applied when generating.
    //uv.y = map(uv.y, 0.0, 1.0, -1.0, 1.0);

    vec3 sky_color = textureCube(u_cubemap, uv).rgb;

    // Dither [1]
    sky_color.rgb = dither(sky_color.rgb, gl_FragCoord.xy + u_temporal_offset);
    // Add sun disk
    sky_color += sun_disk(v_uv, u_sun_direction);

    vec3 camera_ray = normalize(v_uv);
    const float sun_halo_intensity = .2;
    const float sun_halo_depth_range = 50.0;
    const vec3  sun_halo_color = vec3(1.0, 0.0, 0.0);
    const float fog_depth_range = 50.0;
    const float fog_intensity = 0.5;
    const vec3  fog_color = vec3(1.0, 1.0, 1.0);
    float sun_dot_camera_ray = clamp(dot(camera_ray, u_sun_direction), 0.0, 1.0);

    // fog
    float fogFactor = 1.0 - smoothstep(0.0, 0.08, dot(camera_ray, vec3(0.0, 1.0, 0.0)));
    vec4 fog = vec4(fog_color * fog_intensity, fog_intensity) * fogFactor;
    vec4 halo = vec4(sun_halo_color * sun_halo_intensity, sun_halo_intensity);
    vec4 fog_combined = mix(fog, halo, sun_dot_camera_ray * sun_dot_camera_ray * sun_halo_intensity);

    // sun scattering
    float sun_halo = pow(sun_dot_camera_ray, 16.0);
    fog += halo * sun_halo;

    gl_FragColor = mix(vec4(sky_color, 1.0), fog_combined, fog_combined.a); //vec4(sky_color * u_opacity, u_opacity);
    // gl_FragColor = vec4(fogFactor, fogFactor, fogFactor)
#ifdef OVERDRAW_INSPECTOR
    gl_FragColor = vec4(1.0);
#endif
}
