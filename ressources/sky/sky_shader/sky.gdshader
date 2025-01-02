shader_type sky;
render_mode use_quarter_res_pass;
uniform sampler2D star_sky;
uniform sampler2D moon;
uniform sampler2D cloud_sky_up: filter_linear, source_color, hint_default_black;
uniform sampler2D cloud_sky_down: filter_linear, source_color, hint_default_black;
uniform sampler2D cloud_sky_2: filter_linear, source_color, hint_default_black;
uniform vec4 sky_color: source_color; // vec3(0.245535, 0.580357, 1.0);
uniform vec4 sun_color: source_color;
uniform vec4 moon_tint: source_color;
uniform vec4 clouds_tint: source_color;
uniform bool SCATERRING;
uniform vec3 SUN_POS; //normalize this vector in script!
uniform vec3 MOON_POS; //normalize this vector in script
uniform vec3 MOON_TEX_POS; //normalize this vector in script!!
uniform vec3 LIGHTING_POS;//normalize this vector in script!!
uniform float lighting_strength;

uniform float MOON_PHASE:hint_range(-1.1,1.1);
uniform float moon_size:hint_range(0.0,0.5);
uniform float attenuation:hint_range(0.0,1.0);
uniform float clouds_speed : hint_range(0, 128) = 0.8;

lowp vec3 extra_cheap_atmosphere(vec3 raydir, vec3 sundir, vec2 uv) //https://www.shadertoy.com/view/MtBcz1
{
	sundir.y = max(sundir.y, -0.07);
	bool isNight = sundir.y < 0.0;
	lowp float special_trick = 1.0 / (raydir.y + 0.8);//special_trick = 1.0 / (raydir.y * 1.0 + 0.1);//original code
	lowp vec3 magic_sky_color = sky_color.rgb; //vec3(0.245535, 0.580357, 1.0);
	lowp float sun_dist = max(0.0,dot(sundir, raydir));
	lowp float mymie = pow(sun_dist, 8.0) * special_trick * 0.3;//original 0.2
	//lowp vec3 suncolor = mix(vec3(1.0), max(vec3(0.0), vec3(1.0) - magic_sky_color), special_trick2);
	lowp vec3 sky = max(vec3(0.0), magic_sky_color * sun_color.rgb - magic_sky_color * 0.0896 * (special_trick + -6.0 * sundir.y * sundir.y));
	//sky *= special_trick * (0.24 + pow(sun_dist, 2.0) * 0.24);
	sky = sky + (mymie * sun_color.rgb * 0.2);
	sky += vec3(1.0 * smoothstep(0.1,0.02, acos(sun_dist)))*moon_tint.rgb;
	sky += vec3(1.0 * smoothstep(0.0958,0.08, acos(sun_dist)))*moon_tint.rgb * 0.5;
	lowp float sun =0.0;
	sun=pow(sun_dist,1024.0);//smoothstep(0.998, 0.99999, sun_dist);//sun_disk
	sky += moon_tint.rgb*sun;// * sun_color.rgb;

	if(isNight) sky = sky * 0.1;
	return clamp(sky,0.0,1.0);
}

lowp vec3 draw_clouds(vec3 raydir, vec3 sundir_real, vec2 uv, bool isNight)
{
	vec3 sundir = mix(vec3(0.0, 1.0, 0.0), sundir_real, 0.5);
	//bool isNight = sundir.y < 0.0;
	lowp float special_trick = 1.0 / (raydir.y + 0.2);
	lowp vec3 magic_sky_color = sky_color.rgb; //vec3(0.245535, 0.580357, 1.0);
	lowp float sun_dist = max(0.0,dot(sundir, raydir));
	lowp float sun_dist_real = max(0.0,dot(sundir_real, raydir));
	lowp float mymie = pow(sun_dist, 8.0) * special_trick * 0.1;//original 0.2
	float clouds_movement = TIME * clouds_speed / 128.0 * 0.1;
	float clouds_movement2 = (sin(TIME)+cos(TIME*0.2)) * clouds_speed / 28.0 * 0.1;
	float clouds_movement3 = cos(TIME) * clouds_speed / 28.0 * 0.2;
	vec3 sky_image = texture(cloud_sky_up, vec2(uv.x+clouds_movement-(clouds_movement2-clouds_movement3)*0.1, uv.y+ clouds_movement3*0.01)).rgb;
	vec3 sky_image2 = texture(cloud_sky_2, vec2(uv.x+clouds_movement2*0.1+(clouds_movement)*0.4, uv.y+ clouds_movement3*0.01)).rgb;
	vec3 sky_image_bottom = texture(cloud_sky_down, vec2(uv.x+clouds_movement*2.0-(clouds_movement2+clouds_movement3)*0.1, uv.y + clouds_movement2*0.1)).rgb;
	sky_image += sky_image2 * 0.5 + (sky_image*0.5 + sky_image2)*0.5;
	sky_image = mix(vec3(0.0), sky_image*0.5 + sky_image*mymie*1.0, max(0.3, min(0.5, pow(sun_dist, 2.0))));//*sky + sky * sky_image*0.9;
	sky_image += sky_image_bottom*0.05 + sky_image_bottom*mymie*1.0;
	//sky_image += sky_image2 * 0.2 + sky_image * sky_image2;
	
	sky_image *= clouds_tint.rgb;
	return clamp(sky_image,0.0,1.0);
}

lowp vec2 uv_sphere(lowp vec3 rd, lowp vec3 pos, lowp float scale) //someone else's code, there are problems with the movement of the moon on y-axis
{
	lowp vec3 ord = normalize(rd + 2.0*cross(pos, cross(pos, rd)));
	vec2 uv =vec2(atan(ord.x,ord.y),acos(ord.z));
	//if (uv.x<0.0) uv.x+=3.1415926536*2.0
	uv.x+=PI*2.0*float(uv.x<0.0);
	uv /= vec2(PI*2.0, PI);
	uv=(uv-0.5)/scale+0.5;
	uv.x*=2.0;uv.x-=0.5;
	return uv;
}

lowp vec2 draw_moon(lowp vec3 rd)
{
	lowp vec2 uv=uv_sphere(rd,MOON_TEX_POS,moon_size);
	lowp float moon_amount = texture(moon,uv).r;
	moon_amount *= 1.0-smoothstep(moon_size*1.0,moon_size*1.4,length(MOON_POS-rd));//+min(pow(max(dot(rd, MOON_POS), 0.0), 500.0/moon_radius) * 100.0, 1.0);
	lowp float moon_mask = moon_amount;
	moon_amount*=1.0 - attenuation; //attenuation of the brightness of the moon (for sunrise and sunset).
	moon_amount = clamp(mix (0.0,moon_amount,smoothstep(0.9,1.0,(1.0-moon_size)*0.5+length(MOON_POS-rd+MOON_PHASE)*(1.0-moon_size*0.75))),0.001,1.0);//here we cast a shadow on the moon. moon phase.
	return vec2(moon_amount,moon_mask) * 1.5;
}

lowp vec3 draw_night_sky (lowp float sky_amount, lowp vec3 rd, lowp vec2 sky_coords, float cloud_alpha, bool isNight)
{
	lowp vec2 moon_amount = draw_moon(rd);
	lowp float stars = texture(star_sky,sky_coords).r; // mipmap off for correct steching; starfield texture from this https://opengameart.org/content/night-sky-skybox-generator ande convert to panorama with this https://danilw.github.io/GLSL-howto/cubemap_to_panorama_js/cubemap_to_panorama.html
	lowp vec3 star_vec = stars*0.1 + moon_tint.rgb * moon_amount.x;//Here we mix with the clouds so that there is no black border. But so that the Moon does not Shine through the clouds.
	
	lowp float sun_dist = max(0.0,dot(vec3(0.0,1.0,0.0), rd));

	float movement = 52.0 + TIME * 0.1 / 128.0 * 0.6;
	star_vec += textureLod(star_sky, vec2(sky_coords.x + movement, sky_coords.y), 1.0).g * max(0.,(1.0-(cloud_alpha*10.0)));
	if(moon_amount.x > 0.1) star_vec = vec3(moon_amount.x) + vec3(moon_amount.x) * moon_tint.rgb * 0.8;
	if(!isNight) star_vec *= 0.2;
	return star_vec ;
}

void sky() {
	vec3 rd = EYEDIR;
	rd.x*=-1.0; //The x-axis is inverted on the godot scene for unknown reasons
	lowp vec3 sky;
	lowp float sun_dist_real = max(0.15, dot(SUN_POS, rd));
	bool isNight = SUN_POS.y < 0.0;
	//sun_dist_real = sun_dist_real * normalize(SUN_POS.y);
	sky = extra_cheap_atmosphere(rd, SUN_POS, SKY_COORDS);
	vec3 top_clouds = draw_clouds(rd, SUN_POS, SKY_COORDS, isNight) ;//* sun_dist_real;
	sky = max(sky, top_clouds*sky + top_clouds);
	sky = mix(vec3(0.0), sky, smoothstep(-0.1,0.0,rd.y));
	if(SUN_POS.y < 0.0) sky = sky / normalize(abs(SUN_POS.y))*0.2;
	sky = mix(sky, draw_night_sky(max(max(sky.b, sky.r), sky.g), rd, SKY_COORDS, top_clouds.r, isNight), 0.4);
	lowp float lighting = clamp(0.5+texture(moon,LIGHTING_POS.xz-rd.xz+0.5).g*smoothstep(0.6,0.3,length(LIGHTING_POS-rd)),0.0,1.0);
	sky = mix(sky.rgb, vec3(lighting),lighting_strength); //flash of light in the sky simulates a lightning strike

	COLOR = sky;
}