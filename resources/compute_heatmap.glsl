#version 450 
layout(local_size_x = 1, local_size_y = 1) in;											//local group of shaders
layout(rgba32f, binding = 0) uniform image2D img_input;									//input image
layout(rgba32f, binding = 1) uniform image2D img_output;								//output image

#define ARRAY_LEN 1920
#define PI 3.14159265

layout (std430, binding=2) volatile buffer grid_data
{ 
	// grid
	vec4 pos[ARRAY_LEN];

	// properties
	vec4 vel[ARRAY_LEN];
	vec4 pressure[ARRAY_LEN];

	// reserved for debugging
	vec4 temp[ARRAY_LEN];

	float dist;

};

#define RESX 1920
#define RESY 1080

float l(float x) {
	return (0.0725 * x * x - 0.725 * x + 2.8125 - dist);
}

float lneg(float x) {
	return (-0.0725 * x * x + 0.725 * x + -2.8125 + dist);
}

int isWall(ivec2 pixel_coords){

	if (pixel_coords.y < (540 + lneg(float(pixel_coords.x) / 192) * 192)){
		return 1;
	}

	if ( pixel_coords.y > (540 + l(float(pixel_coords.x)/192)*192) ){
		return 1;
	}

	return 0;
}

vec3 getColor(float v) {

	float a = (1 - v) / 0.25;

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
	vec4 pixel;

	// black screen on working ssbo
	if ( isWall(pixel_coords) == 1 ){
		pixel = vec4(0);
	}else{
	
		uint pos_index = uint(pixel_coords.x);

		float b = (540 + lneg(float(pixel_coords.x) / 192) * 192);
		float a = (540 + l(float(pixel_coords.x) / 192) * 192);

		float pixelVelocity = sin((pixel_coords.y - b) / (a - b) * PI) * vel[pos_index].x; // MAXVELOCITY 

		vec3 color = getColor(pixelVelocity);
		pixel = vec4(color.r, color.g, color.b, 0);

	}
	
	imageStore(img_output, pixel_coords, pixel);
	
	}