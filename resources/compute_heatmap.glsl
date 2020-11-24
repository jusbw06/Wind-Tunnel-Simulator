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
	int temp_sphere;

	ivec2 sphere_coords[MAX_SPHERE];
	float dP[MAX_SPHERE];
};

uniform float dist;
uniform int num_sphere;
uniform int heatmap_toggle;


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

vec3 getColor(int posx, int posy, int id) {

	float a;
	if (id == 0){ // velocity
		a = (1 - length(pressure[posx][posy].zw)) * 4;
	}else if (id == 1){ // pressure
		a = (.125 - abs(pressure[posx][posy].x)) * 32;
	}

	int colorCase = int(a);

	float remainder = a - colorCase;

	vec3 resultColor = vec3(0, 0, 0);

	switch (colorCase) {
		case 0:
			resultColor.r = 1;
			resultColor.g = remainder;
			resultColor.b = 0;
			break;
		case 1:
			resultColor.r = 1 - remainder;
			resultColor.g = 1;
			resultColor.b = 0;
			break;
		case 2:
			resultColor.r = 0;
			resultColor.g = 1;
			resultColor.b = remainder;
			break;
		case 3:
			resultColor.r = 0;
			resultColor.g = 1 - remainder;
			resultColor.b = 1;
			break;
		default:
			resultColor.r = 1;
			resultColor.g = 0;
			resultColor.b = 0;
			break;
	}

	resultColor.r = clamp(resultColor.r, 0, 1);
	resultColor.g = clamp(resultColor.g, 0, 1);
	resultColor.b = clamp(resultColor.b, 0, 1);

	return resultColor;

}


void main(){

	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
	
	vec4 pixel = imageLoad(img_output, pixel_coords);

	int posx = pixel_coords.x; // addressable to pixel, may need change
	int posy = pixel_coords.y; // if grid coords are diff from RES
	//pressure[posx][posy] = pixel;


	// black screen on working ssbo
	if ( isWall( pos[posx][posy].xy ) == 1 ){
		pixel = vec4(0);
	}else{

		if (pixel.w > 0){

			pixel.xyz *= 0.8;
			pixel.w -= 0.1;
		
		}else{
			pixel.xyz = getColor(posx, posy, heatmap_toggle);
			pixel.w = 0;

		}


	}
	
	imageStore(img_output, pixel_coords, pixel);

}