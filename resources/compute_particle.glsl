#version 450
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_arrays_of_arrays : require

layout(local_size_x = 1, local_size_y = 1) in;											//local group of shaders
layout(rgba32f, binding = 0) uniform image2D img_input;									//input image
layout(rgba32f, binding = 1) uniform image2D img_output;								//output image

#define RESX 1920
#define RESY 1080
#define DIM_X 1920
#define DIM_Y 1080
#define XDIM 10
#define YDIM 5.625
#define XY_SCALE 192

#define NUM_S_PARTICLES 256

#define PI 3.14159265
#define MAX_SPHERE 100
#define RADIUS 0.02

#define VMUL 0.1

layout (std430, binding=2) volatile buffer grid_data
{ 
	// grid
	vec4 pos[DIM_X][DIM_Y];

	// properties
	vec4 vel[DIM_X][DIM_Y];
	vec4 pressure[DIM_X][DIM_Y];

	// streamline properties
	vec4 stream_pos[NUM_S_PARTICLES];

	// reserved for debugging
	vec4 temp[DIM_X];

	vec4 spos[MAX_SPHERE];
	vec4 svel[MAX_SPHERE];

};

layout(std430, binding = 3) volatile buffer sphere_data
{
	vec4 positionSphere[MAX_SPHERE];      // x: xpos, y: ypos z: mass
	vec2 velocitySphere[MAX_SPHERE];
	vec2 accelerationSphere[MAX_SPHERE];
	vec2 mouseVelocity;
	vec2 mousePressure;

	int mouse_x;
	int mouse_y;
	int numSphere;
};

uniform float dist;
uniform int num_sphere;


float l(float x) {
	return (0.0725 * x * x - 0.725 * x + 2.8125 - dist);
}
#define lneg(x) (-1 * l(x)) 
#define dldx(x) (0.145*x - 0.725)




int isWall(vec2 pos){

	if ( pos.y < lneg(pos.x) ){
		return 1;
	}

	if ( pos.y > l(pos.x) ){
		return 1;
	}

	return 0;
}



void addArrows(ivec2 pixel_coords, vec2 vel_slope){

	//ivec2 arrow_pixel_offset[8] = {ivec2(-2,0),ivec2(-1,0),ivec2(0,0),ivec2(1,0),ivec2(2,0),ivec2(2,1),ivec2(3,0),ivec2(2,-1)}; 
	//ivec2 arrow_pixel_offset[8] = {ivec2(-2,0),ivec2(-1,0),ivec2(0,0),ivec2(1,0),ivec2(2,0),ivec2(2,1),ivec2(3,0),ivec2(2,-1)}; 
	//ivec2 arrow_pos[8];
	//for (int i = 0; i < 8; i++){
	//	arrow_pos[i] = ivec2(arrow_pixel_offset[i] * normalize(vel_slope) ) * 5 + pixel_coords;
	//	imageStore(img_output, arrow_pos[i], vec4(0,0,0,0));
	//}

	for (int i = 0; i < 20; i++){
		ivec2 arrow_pos = ivec2(pixel_coords + normalize(vel_slope) * i); 
		imageStore(img_output, arrow_pos, vec4(0,0,0,0));
	}



	imageStore(img_output, pixel_coords, vec4(1,1,1,0));
	imageStore(img_output, pixel_coords + ivec2(1,0), vec4(1,1,1,0));
	imageStore(img_output, pixel_coords + ivec2(-1,0), vec4(1,1,1,0));
	imageStore(img_output, pixel_coords + ivec2(0,1), vec4(1,1,1,0));
	imageStore(img_output, pixel_coords + ivec2(0,-1), vec4(1,1,1,0));


}

// for particle collision

bool isCollide(vec4 v1, vec4 v2) {
	vec3 delta = vec3(v1.x, v1.y, 0) - vec3(v2.x, v2.y, 0);
	return length(delta) < RADIUS * v1.z + RADIUS * v2.z;

}

vec3 projectUonV(vec4 v1, vec4 v2) {
	vec3 r;
	vec3 u = vec3(v1.x, v1.y, 0);
	vec3 v = vec3(v2.x, v2.y, 0);
	r = v * (dot(u, v) / dot(u, v));
	return r;
}


void separate(uint A, int B) {
	vec2 between = normalize(positionSphere[A].xy - positionSphere[B].xy);
	between = between * (RADIUS * positionSphere[A].z + RADIUS * positionSphere[B].z - distance(positionSphere[A].xy, positionSphere[B].xy));
	positionSphere[A].xy = positionSphere[A].xy + between * 2;
}

void main(){

	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	int posx = pixel_coords.x; // addressable to pixel, may need change
	int posy = pixel_coords.y; // if grid coords are diff from RES

	if (posx % 50 == 0 && posy % 50 == 0 && isWall( pos[posx][posy].xy ) != 1){
		addArrows(pixel_coords, vel[posx][posy].xy);
	}


	uint index = pixel_coords.x;

	if (index > numSphere)
		return;


	// check for sphere-boundry collision
	ivec2 sphere_pixel_pos = ivec2((positionSphere[index].x + 1) / 2.0 * RESX, (positionSphere[index].y + 1) / 2.0 * RESY);
	if (isWall(pos[sphere_pixel_pos.x][sphere_pixel_pos.y].xy) == 1) {
		velocitySphere[index].xy = vec2(0, 0);
	}

	// sphere-sphere collision
	for (int i = 0; i < num_sphere; i++) {
		if (i != index && isCollide(positionSphere[i], positionSphere[index])) {
			vec4 a = vec4(vec2(positionSphere[index].xy - positionSphere[i].xy), 0, 0);
			vec4 b = vec4(vec2(positionSphere[i].xy - positionSphere[index].xy), 0, 0);

			
		//	velocitySphere[i].xy += projectUonV(vec4(velocitySphere[index], 0, 0), a).xy / positionSphere[i].z * VMUL;
		//	velocitySphere[i].xy -= projectUonV(vec4(velocitySphere[i], 0, 0), b).xy / positionSphere[i].z * VMUL;

			velocitySphere[index].xy += projectUonV(vec4(velocitySphere[i], 0, 0), a).xy / positionSphere[index].z * VMUL;
			velocitySphere[index].xy -= projectUonV(vec4(velocitySphere[index], 0, 0), b).xy / positionSphere[index].z * VMUL;

			separate(index, i);
		}
	}


}





