#version 450 
layout(local_size_x = 1, local_size_y = 1) in;											//local group of shaders
layout(rgba32f, binding = 0) uniform image2D img_input;									//input image
layout(rgba32f, binding = 1) uniform image2D img_output;								//output image



#define RESX 1920
#define RESY 1080
#define DIM_X 1920
#define DIM_Y 1080
#define XDIM 10
#define YDIM 5.625
#define XY_SCALE DIM_X/XDIM

#define PI 3.14159265
#define MAX_SPHERE 100

layout (std430, binding=2) volatile buffer grid_data
{ 
	// grid
	vec4 pos[DIM_X][DIM_Y];

	// properties
	vec4 vel[DIM_X][DIM_Y];
	vec4 pressure[DIM_X][DIM_Y];

	// reserved for debugging
	vec4 temp[DIM_X];

	vec4 spos[MAX_SPHERE];
	vec4 svel[MAX_SPHERE];

};

layout(std430, binding = 3) volatile buffer sphere_data
{
	vec4 positionSphere[MAX_SPHERE];
	vec2 velocitySphere[MAX_SPHERE];
	vec2 accelerationSphere[MAX_SPHERE];
	vec2 mouseVelocity;
	vec2 mousePressure;

	int mouse_x;
	int mouse_y;
	int numSphereTest;
};


uniform float dist;


float l(float x) {
	return (0.0725 * x * x - 0.725 * x + 2.8125 - dist);
}
#define lneg(x) (-1 * l(x)) 
#define dldx(x) (0.145*x - 0.725)


/* NEEDS UPDATE */
// in radius
// in vec2 particle position
int isWallCollision(ivec2 particle_coords, float radius){

	if ( particle_coords.y > (540 + l(float(particle_coords.x)/192)*192) - radius ){
		return 1;
	}

	return 0;

}
/* NEEDS UPDATE */
// in vel particle
// out new vel vector
vec2 collision(ivec2 particle_coords, vec2 particle_velocity){

	vec2 resultant = particle_velocity;

	float radius = 25; // in pixels
	if (isWallCollision(particle_coords, radius) == 1){
	
		float dydx = dldx(particle_coords.x);
		vec2 normal = normalize(vec2(-1, dydx));

		// r = d - 2(d dot n)n
		resultant = particle_velocity - 2*dot(particle_velocity, normal) * normal;

	}

	return resultant;

}

int isWall(vec2 pos){

	if ( pos.y < lneg(pos.x) ){
		return 1;
	}

	if ( pos.y > l(pos.x) ){
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

#define rho 1
#define mu 1
#define Re(v,x) sqrt(rho*v*x/mu)
#define delta99(x,v,L) 0
#define u(x,y) ( sqrt(mu/rho/x)*5.0*x/y ) * ( sqrt(mu/rho/x)*5.0*x/y )
void main(){

	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	int posx = pixel_coords.x; // addressable to pixel, may need change
	int posy = pixel_coords.y; // if grid coords are diff from RES

	vec4 pixel = vec4(0);

	// black screen on working ssbo
	if ( isWall( pos[posx][posy].xy ) == 1 ){

	}else{
		pixel.xyz = getColor(vel[posx][posy].x);
	}
	
	
	imageStore(img_output, pixel_coords, pixel);

}