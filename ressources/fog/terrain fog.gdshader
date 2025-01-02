
// NOTE: Shader automatically converted from Godot Engine 4.3.stable's FogMaterial.

shader_type fog;

uniform sampler2D u_terrain_heightmap;
//uniform float density : hint_range(0, 1, 0.0001) = 1.0;
//uniform vec4 albedo : source_color = vec4(1.0);
//uniform vec4 emission : source_color = vec4(0, 0, 0, 1);
//uniform float height_falloff = 0.0;
//uniform float edge_fade = 0.1;
//uniform sampler3D density_texture: hint_default_white;

#include "res://addons/zylann.hterrain/shaders/include/heightmap.gdshaderinc"

uniform float base_density: hint_range(0, 1) = 0.8;
uniform vec3 base_color: source_color;
uniform float fade_out_height = 2.0;
uniform float fade_out_distance = 1.5;

uniform vec3 noise_amounts = vec3(0.4, 0.35, 0.25); // should add up to 1
uniform vec3 noise_scales = vec3(1.0, 2.0, 4.0);
uniform vec3 noise_velocity1 = vec3(0.5, 0.0, 0.0);
uniform vec3 noise_velocity2 = vec3(1, 0.0, -1);
uniform vec3 noise_velocity3 = vec3(0.0, 0.6, 0.3);

uniform float __terrain_amplitude = 0.1;
uniform float __terrain_ajuster = 10;
uniform vec2 u_terrain_heightmap_size = vec2(4096.0, 4096.0);


/* gradient_noise_3d.gdshaderinc */
// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// All noise functions here:
//
// https://www.shadertoy.com/playlist/fXlXzf&from=0&num=12

vec3 hash(vec3 p) {
	p = vec3(dot(p,vec3(127.1,311.7, 74.7)),
			 dot(p,vec3(269.5,183.3,246.1)),
			 dot(p,vec3(113.5,271.9,124.6)));

	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// 3D gradient noise function
float noise(in vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);

	vec3 u = f*f*(3.0-2.0*f);

    return mix( mix( mix( dot( hash( i + vec3(0.0,0.0,0.0) ), f - vec3(0.0,0.0,0.0) ),
                          dot( hash( i + vec3(1.0,0.0,0.0) ), f - vec3(1.0,0.0,0.0) ), u.x),
                     mix( dot( hash( i + vec3(0.0,1.0,0.0) ), f - vec3(0.0,1.0,0.0) ),
                          dot( hash( i + vec3(1.0,1.0,0.0) ), f - vec3(1.0,1.0,0.0) ), u.x), u.y),
                mix( mix( dot( hash( i + vec3(0.0,0.0,1.0) ), f - vec3(0.0,0.0,1.0) ),
                          dot( hash( i + vec3(1.0,0.0,1.0) ), f - vec3(1.0,0.0,1.0) ), u.x),
                     mix( dot( hash( i + vec3(0.0,1.0,1.0) ), f - vec3(0.0,1.0,1.0) ),
                          dot( hash( i + vec3(1.0,1.0,1.0) ), f - vec3(1.0,1.0,1.0) ), u.x), u.y), u.z );
}

float get_height(vec2 pos) {
	pos += u_terrain_heightmap_size * 0.5;
	pos /= u_terrain_heightmap_size;
	//if(pos.x > 0.0 || pos.x < __terrain_ajuster) return 0.0;
	//if(pos.y > 0.0 || pos.y < __terrain_ajuster) return 0.0;
	return __terrain_amplitude * texture(u_terrain_heightmap, pos).r;
}

void fog() {
	vec3 base_pos = WORLD_POSITION ;//* vec3(0.1, 0.5, 0.1);
	vec3 pos = base_pos - OBJECT_POSITION;
	//pos = pos + (4096.0 * 0.5);
	//pos += (4096.0 * 0.5);
	//pos /= 4096.0;
	//*_texture_uv_multiplier/map_multiplier
	//float h = texture(u_terrain_heightmap, pos.xz * noise_scales.z).r;// * texture(u_terrain_heightmap, pos.xz).r;//+ 150.0;
	//float h = sample_heightmap(u_terrain_heightmap, pos.xy);
	float h = get_height(pos.xz);

	DENSITY = base_density;
	float noise1 = noise(base_pos * noise_scales.x + TIME * noise_velocity1) * noise_amounts.x;
	float noise2 = noise(base_pos * noise_scales.y + TIME * noise_velocity2) * noise_amounts.y;
	float noise3 = noise(base_pos * noise_scales.z + TIME * noise_velocity3) * noise_amounts.z;
	DENSITY *= smoothstep(-0.1, 0.0, noise1 + noise2 + noise3);
	DENSITY *= 1.0 - smoothstep(0.0, h+10.0, WORLD_POSITION.y); //WORLD_POSITION.y
	//DENSITY *= 1.0 - smoothstep(fade_out_height, fade_out_height + fade_out_distance, WORLD_POSITION.y);
	ALBEDO = base_color;// + noise(base_pos * noise_scales.x + TIME * noise_velocity1) * noise_amounts.x;
}

//void fog() {
	//float h = sample_heightmap(u_terrain_heightmap, UVW.xy);
    //DENSITY = density * clamp(exp2(-height_falloff * (WORLD_POSITION.y - OBJECT_POSITION.y)), 0.0, 1.0);
    //DENSITY *= texture(density_texture, UVW).r;
    //DENSITY *= pow(clamp(-2.0 * SDF / min(min(SIZE.x, SIZE.y), SIZE.z), 0.0, 1.0), edge_fade);
    //DENSITY *= 1.0 - smoothstep(h, h + 10.0, WORLD_POSITION.y);
	//ALBEDO = albedo.rgb;
    //EMISSION = emission.rgb;
//}