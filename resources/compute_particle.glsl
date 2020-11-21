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
	int mouse_x;
	int mouse_y;

};

layout(std430, binding = 3) volatile buffer sphere_data
{
	vec2 positionSphere[MAX_SPHERE];
	vec2 velocitySphere[MAX_SPHERE];
	vec2 accelerationSphere[MAX_SPHERE];
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

void main(){

	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	int posx = pixel_coords.x; // addressable to pixel, may need change
	int posy = pixel_coords.y; // if grid coords are diff from RES

	if (posx % 50 == 0 && posy % 50 == 0 && isWall( pos[posx][posy].xy ) != 1){
		addArrows(pixel_coords, vel[posx][posy].xy);
	}

}





