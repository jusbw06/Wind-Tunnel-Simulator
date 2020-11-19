#version 450 
layout(local_size_x = 1, local_size_y = 2) in;	


#define ARRAY_LEN 1920


layout (std430, binding=2) volatile buffer grid_data
{ 
	// grid
	vec4 pos[ARRAY_LEN];

	// properties
	vec4 vel[ARRAY_LEN];
	vec4 pressure[ARRAY_LEN];

	// reserved for debugging
	vec4 temp[ARRAY_LEN];

	//{[1,1,1,1], [1,12,3,0] }

	float temp1;

};


#define RESX 1920
#define RESY 1080
//2.844 -1.976
#define XDIM 1920
#define XDIM_LEN 10

// l(x): y = 0.0725x^2 - 0.725x + 2.8125
#define MASS_FLOW 1.0


uniform float dist;

float l(float x) {
	return (0.0725 * x * x - 0.725 * x + 2.8125 - dist);
}

float dldx(float x){
	return (0.145*x - 0.725);
}

// in radius
// in vec2 particle position
int isWallCollision(ivec2 particle_coords, float radius){

	if ( particle_coords.y > (540 + l(float(particle_coords.x)/192)*192) - radius ){
		return 1;
	}

	return 0;

}

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

void main(){

	uint index = gl_GlobalInvocationID.x;

	if (index >= XDIM){
		return;
	}

	// l(x)
	pos[index].w = (l(pos[index].x) - (-l(pos[index].x)));

	// m_dot = rhoAv
	vel[index].x = MASS_FLOW/pos[index].w;

	// dynamic pressure
	// P = 1/2rhoV^2
	pressure[index].x = 0.5 * 1 * vel[index].x * vel[index].x;

}