#version 450 
layout(local_size_x = 1, local_size_y = 1) in;											//local group of shaders
layout(rgba32f, binding = 0) uniform image2D img_input;									//input image
layout(rgba32f, binding = 1) uniform image2D img_output;									//output image

#define ARRAY_LEN 100


layout (std430, binding=2) volatile buffer grid_data
{ 
	// grid
	vec4 pos[ARRAY_LEN];

	// properties
	vec4 vel[ARRAY_LEN];
	vec4 pressure[ARRAY_LEN];

	// reserved for debugging
	vec4 temp[ARRAY_LEN];

};

#define RESX 1920
#define RESY 1080

#define l(x) (0.0725*x*x -0.725*x + 2.8125)

int isWall(ivec2 pixel_coords){

	if (pixel_coords.y < RESY/2){
		return 1;
	}

	if ( pixel_coords.y > (540 + l(pixel_coords.x/192)*192) ){
		return 1;
	}

	return 0;
}

float map(float value, float min1, float max1, float min2, float max2) {

	return min2 + (value - min1) * (max2 - min2) / (max1 - min1);

}

void main(){

	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);	
	vec4 pixel = imageLoad(img_input, pixel_coords);

	// black screen on working ssbo
	if ( isWall(pixel_coords) ){
		pixel = vec4(0);
	}else{
	
		uint pos_index = uint(pixel_coords.x / 192 * 10);
		float green = map(vel[pos_index].x, .355, 1, 0.1, 1);
		pixel = vec4(0,green,green,0);
	
	}

	
	imageStore(img_output, pixel_coords, pixel);
	}