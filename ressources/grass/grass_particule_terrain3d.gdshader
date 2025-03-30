shader_type particles;
render_mode disable_velocity, disable_force;

group_uniforms instancing;
// Consider instance_rows * instance_spacing to be the total side length of
// the particle grid. Set instance_rows first, and then set Ammount
// to instance_rows * instance_rows - this could be handled in gdscript, but
// needs to be set manually for this example.
uniform uint instance_rows;
uniform float instance_spacing : hint_range(0.03125, 10.0, 0.03125) = 0.125 ;
uniform bool align_to_normal = true;

group_uniforms randomization;
uniform bool random_rotation = true;
uniform float random_spacing : hint_range(0.0, 1.0, 0.01);
uniform vec3 min_scale = vec3(1.0);
uniform vec3 max_scale = vec3(1.0);

group_uniforms filtering;
uniform float condition_dither_range : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float surface_slope_min : hint_range(0.0, 1.0, 0.01) = 0.87;

group_uniforms maps;
uniform uint _background_mode = 0u;
uniform float _vertex_spacing = 1.0;
uniform float _vertex_density = 1.0; // = 1/_vertex_spacing
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625; // = 1/1024
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform vec2 _region_locations[1024];
uniform highp sampler2DArray _height_maps : repeat_disable;
// Not used in this example, but could be read from, decoded
// and used to filter based on base/over/blend data etc.
uniform highp usampler2DArray _control_maps : repeat_disable;

uniform mat4 camera_transform;

// Defined Constants
#define SKIP_PASS 0
#define VERTEX_PASS 1
#define FRAGMENT_PASS 2

// Takes in world space XZ (UV) coordinates & search depth (only applicable for background mode none)
// Returns ivec3 with:
// XY: (0 to _region_size - 1) coordinates within a region
// Z: layer index used for texturearrays, -1 if not in a region
ivec3 get_index_coord(const vec2 uv, const int search) {
	vec2 r_uv = round(uv);
	vec2 o_uv = mod(r_uv,_region_size);
	ivec2 pos;
	int bounds, layer_index = -1;
	for (int i = -1; i < 0; i++) {
		if ((layer_index == -1 && _background_mode == 0u) || i < 0) {
			r_uv -= i == -1 ? vec2(0.0) : vec2(float(o_uv.x <= o_uv.y), float(o_uv.y <= o_uv.x));
			pos = ivec2(floor((r_uv) * _region_texel_size)) + (_region_map_size / 2);
			bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
			layer_index = (_region_map[ pos.y * _region_map_size + pos.x ] * bounds - 1);
		}
	}
	return ivec3(ivec2(mod(r_uv,_region_size)), layer_index);
}

float random (vec2 uv) {
		float rf = fract(sin(dot(uv.xy,
		vec2(12.9898,78.233))) * 43758.5453123);
	return rf;
}

mat3 rotation_matrix(vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	float t = 1.0 - c;
	vec3 n = normalize(axis);
	float x = n.x;
	float y = n.y;
	float z = n.z;

	return mat3(
		vec3(t * x * x + c, t * x * y - z * s, t * x * z + y * s),
		vec3(t * x * y + z * s, t * y * y + c, t * y * z - x * s),
		vec3(t * x * z - y * s, t * y * z + x * s, t * z * z + c));
}

mat3 align_to_vector(vec3 normal) {
	vec3 up = vec3(0.0, 1.0, 0.0);
	if (abs(dot(normal, up)) > 0.99) { // Avoid singularity
		up = vec3(1.0, 0.0, 0.0);
	}
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = normalize(cross(tangent, normal));
	return mat3(tangent, normal, bitangent);
}

float _sign (vec2 p1, vec2 p2, vec2 p3) {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

bool PointInRectangle (vec2 pt, vec2 v1, vec2 v2, vec2 v3, vec2 v4) {
    float d1, d2, d3, d4;
    bool has_neg, has_pos;

    d1 = _sign(pt, v1, v2);
    d2 = _sign(pt, v2, v3);
    d3 = _sign(pt, v3, v4);
	d4 = _sign(pt, v4, v1);

    has_neg = (d1 < 0.0) || (d2 < 0.0) || (d3 < 0.0) || (d4 < 0.0);
    has_pos = (d1 > 0.0) || (d2 > 0.0) || (d3 > 0.0) || (d4 > 0.0);

    return !(has_neg && has_pos);
}

mat2 rotate2d(float _angle) {
    return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

void start() {
	// Create centered a grid
    vec3 pos = vec3(float(INDEX % instance_rows), 0.0, float(INDEX / instance_rows));
    pos.xz -= float(instance_rows >> 1u) + round(camera_transform[2].xz * float(instance_rows >> 1u));
    // Apply spcaing
    pos *= instance_spacing;
    // Move the grid to the emitter, maintain snapping.
    pos.x += EMISSION_TRANSFORM[3][0] - mod(EMISSION_TRANSFORM[3][0], instance_spacing);
    pos.z += EMISSION_TRANSFORM[3][2] - mod(EMISSION_TRANSFORM[3][2], instance_spacing);

    // Create a random value per-instance
    vec3 r = vec3(random(pos.xz), random(pos.xz + vec2(0.5)), random(pos.xz - vec2(0.5)));

    // Randomize instance spacing
    pos.x += ((r.x * 2.0) - 1.0) * random_spacing * instance_spacing;
    pos.z += ((r.y * 2.0) - 1.0) * random_spacing * instance_spacing;

	// Lookup offsets, ID and blend weight
	const vec3 offsets = vec3(0, 1, 2);
	vec2 index_id = floor(pos.xz * _vertex_density);
	vec2 weight = fract(pos.xz * _vertex_density);
	vec2 invert = 1.0 - weight;
	vec4 weights = vec4(
		invert.x * weight.y, // 0
		weight.x * weight.y, // 1
		weight.x * invert.y, // 2
		invert.x * invert.y  // 3
	);

	ivec3 indexUV[4];
	// map lookups
	indexUV[0] = get_index_coord(index_id + offsets.xy, FRAGMENT_PASS);
	indexUV[1] = get_index_coord(index_id + offsets.yy, FRAGMENT_PASS);
	indexUV[2] = get_index_coord(index_id + offsets.yx, FRAGMENT_PASS);
	indexUV[3] = get_index_coord(index_id + offsets.xx, FRAGMENT_PASS);

	float h[8];
	h[0] = texelFetch(_height_maps, indexUV[0], 0).r; // 0 (0,1)
	h[1] = texelFetch(_height_maps, indexUV[1], 0).r; // 1 (1,1)
	h[2] = texelFetch(_height_maps, indexUV[2], 0).r; // 2 (1,0)
	h[3] = texelFetch(_height_maps, indexUV[3], 0).r; // 3 (0,0)
	h[4] = texelFetch(_height_maps, get_index_coord(index_id + offsets.yz, VERTEX_PASS), 0).r; // 4 (1,2)
	h[5] = texelFetch(_height_maps, get_index_coord(index_id + offsets.zy, VERTEX_PASS), 0).r; // 5 (2,1)
	h[6] = texelFetch(_height_maps, get_index_coord(index_id + offsets.zx, VERTEX_PASS), 0).r; // 6 (2,0)
	h[7] = texelFetch(_height_maps, get_index_coord(index_id + offsets.xz, VERTEX_PASS), 0).r; // 7 (0,2)
	vec3 index_normal[4];
	index_normal[0] = vec3(h[0] - h[1], _vertex_spacing, h[0] - h[7]);
	index_normal[1] = vec3(h[1] - h[5], _vertex_spacing, h[1] - h[4]);
	index_normal[2] = vec3(h[2] - h[6], _vertex_spacing, h[2] - h[1]);
	index_normal[3] = vec3(h[3] - h[2], _vertex_spacing, h[3] - h[0]);
	vec3 w_normal = normalize(
		index_normal[0] * weights[0] +
		index_normal[1] * weights[1] +
		index_normal[2] * weights[2] +
		index_normal[3] * weights[3]);

	// set the height according to the heightmap data
	pos.y =
		h[0] * weights[0] +
		h[1] * weights[1] +
		h[2] * weights[2] +
		h[3] * weights[3] ;

	// Set base Transform
	TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
	// Note: this section and related functions may not be 100% correct.
	{
		// Base orientation vector
		vec3 orientation = vec3(0., 1., 0.);
		// Apply normal orientation
		if (align_to_normal) {
			orientation = w_normal;
			mat3 alignment = align_to_vector(orientation);
			TRANSFORM = mat4(alignment);
		}
		// Apply rotation around orientation
		if (random_rotation) {
			mat3 rotation = rotation_matrix(orientation, r.x * TAU);
			TRANSFORM = mat4(rotation) * TRANSFORM;
		}
	}

	// calculate and apply the scale after rotating
	vec3 scale = vec3(
		mix(min_scale.x, max_scale.x, r.x),
		mix(min_scale.y, max_scale.y, r.y),
		mix(min_scale.z, max_scale.z, r.z));
	TRANSFORM[0] *= scale.x;
	TRANSFORM[1] *= scale.y;
	TRANSFORM[2] *= scale.z;

	// Surface slope filtering
	if (surface_slope_min > w_normal.y + (r.y - 0.5) * condition_dither_range) {
		pos.z = 0. / 0.;
	}

	// apply the position
	TRANSFORM[3].xyz = pos.xyz;
}
