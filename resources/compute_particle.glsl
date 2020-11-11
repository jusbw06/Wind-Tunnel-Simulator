#version 450 
layout(local_size_x = 1, local_size_y = 1) in;											//local group of shaders
layout(rgba32f, binding = 0) uniform image2D img_input;									//input image
layout(rgba32f, binding = 1) uniform image2D img_output;									//output image

vec4 bilinearInterp(vec2 coords) {
	vec2 weight = fract(coords);
	ivec2 coordsfloor = ivec2(coords);

	vec4 bl = imageLoad(img_input, coordsfloor);
	vec4 br = imageLoad(img_input, coordsfloor+ivec2(1,0));
	vec4 tl = imageLoad(img_input, coordsfloor+ivec2(0,1));
	vec4 tr = imageLoad(img_input, coordsfloor+ivec2(1,1));
	vec2 to_bl = weight;
	vec2 to_br = vec2(-(1-weight.x), weight.y);
	vec2 to_tl = vec2(weight.x, -(1-weight.y));
	vec2 to_tr = vec2(-(1-weight.x), -(1-weight.y));

	vec4 bot = mix(bl, br, weight.x);
	vec4 top = mix(tl, tr, weight.x);

	vec4 newpos = mix(bot, top, weight.y);
//	newpos.xy += (to_bl*(bl.a-newpos.a) + to_br*(br.a-newpos.a) + to_tl*(tl.a-newpos.a) + to_tr*(tr.a-newpos.a));
	newpos.xyz = normalize(newpos.rgb - vec3(0.5,0.5,0.5)) * newpos.a;
	return newpos;
}

#define RESX 1920
#define RESY 1080

int isWithinBorders(ivec2 pixel_coords, int offset){
	
	if(pixel_coords.x < 0 + offset || pixel_coords.y < 0 + offset || pixel_coords.x >= (RESX - offset) || pixel_coords.y >= (RESY - offset))
		return 0;

	if(pixel_coords.x > 1063 - offset && pixel_coords.x < 1290 + offset && pixel_coords.y < 448 + offset && pixel_coords.y > 301 - offset)
		return 0;


	return 1;
}

#define EPS 0
#define CENTER 0
#define LEFT 1
#define RIGHT 2
#define UP 3
#define DOWN 4
#define MULT 0.8

void main() 
	{
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);	

	// center, left, right, up, down
	int x[5] = {0, -1, 1, 0, 0};
	int y[5] = {0, 0, 0, 1, -1};
	vec4 pixels[5];
	vec4 vel[5];
	int pixel_bool[5];

	if (isWithinBorders(pixel_coords,1) == 0){
		return;
	}

	ivec2 coors;
	for (int i = 0; i < 5; i++){
		coors = pixel_coords + ivec2(x[i],y[i]);
		// if pixel is valid
		if ( (isWithinBorders(coors , 1) == 1) ){
			pixels[i] = imageLoad(img_input, coors);
			pixel_bool[i] = 0; // not out of bounds
		}else{
			pixel_bool[i] = 1; // out of bounds or black
			pixels[i] = pixels[CENTER];
		}
		vel[i].xyz =  normalize(pixels[i].rgb - vec3(0.5,0.5,0.5)) * pixels[i].a;
		vel[i].a = pixels[i].a;
	}
	
	//Advection -- responsible for movement -- cannot advect through surface
	float p = length(vel[CENTER].xy);
	vec2 pos = pixel_coords - p * vel[CENTER].xy;
	if ( isWithinBorders(ivec2(pos),2) )
		vel[CENTER] = bilinearInterp(pos);

	
	
	//Diffusion
	float nei_a_sum = 0;
	vec3 nei_vel_sum = vec3(0);
	for (int i = 1; i < 5; i++){
		nei_vel_sum += vel[i].xyz;
		nei_a_sum += pixels[i].a;
	}

	float alpha = 3.;
	float beta = 4 + alpha;
	vel[CENTER].xyz = (nei_vel_sum + alpha*vel[CENTER].xyz)/beta;
	vel[CENTER].a = (nei_a_sum + alpha*vel[CENTER].a)/beta;
	
	

	//Pressure
	float hrdx = 0.25;// 1; //0.75;
	
	// handle collisions with surfaces
	if (pixel_bool[RIGHT] == 1){

		if (vel[LEFT].x > EPS){
			vel[CENTER].a += vel[LEFT].x * MULT;
			vel[CENTER].x = 0;
		}else if (vel[LEFT].x < -EPS){
			vel[CENTER].a -= abs(vel[LEFT].x) * MULT;
			vel[CENTER].x = 0;
		}

	} else if (pixel_bool[LEFT] == 1){

		if (vel[RIGHT].x < -EPS){
			vel[CENTER].a += abs(vel[RIGHT].x) * MULT;
			vel[CENTER].x = 0;
		}else if(vel[RIGHT].x > EPS){
			vel[CENTER].a -= vel[RIGHT].x * MULT;
			vel[CENTER].x = 0;
		}

	}else{
		vel[CENTER].x -= hrdx*(pixels[RIGHT].a - pixels[LEFT].a);
	}

	if (pixel_bool[UP] == 1){
		vel[CENTER].y = 0;
		if (vel[DOWN].y > EPS){
			vel[CENTER].a += vel[DOWN].y * MULT;
		}else if(vel[DOWN].y < -EPS){
			vel[CENTER].a -= abs(vel[DOWN].y) * MULT;
		}

	}else if (pixel_bool[DOWN] == 1){
		vel[CENTER].y = 0;
		if (vel[UP].y < -EPS){
			vel[CENTER].a += abs(vel[UP].y) * MULT;
		} else if(vel[UP].y > EPS){
			vel[CENTER].a -= vel[UP].y * MULT;
		}
		
	}else{
		vel[CENTER].y -= hrdx*(pixels[UP].a - pixels[DOWN].a);
	}
	
	vel[CENTER].a = clamp(vel[CENTER].a,0,10);

	pixels[CENTER].rgb = normalize(vel[CENTER].xyz)/2. + vec3(0.5,0.5,0.5);
	pixels[CENTER].a = vel[CENTER].a;
	
	imageStore(img_output, pixel_coords, pixels[CENTER]);
	}