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

	float dist;

};


#define RESX 1920
#define RESY 1080
//2.844 -1.976
#define XDIM 1920
#define XDIM_LEN 10

// l(x): y = 0.0725x^2 - 0.725x + 2.8125
#define MASS_FLOW 1.0

float l(float x) {
	return (0.0725 * x * x - 0.725 * x + 2.8125 - dist);
}

float lneg(float x) {
	return (-0.0725 * x * x + 0.725 * x + -2.8125 + dist);
}

void main(){

	uint index = gl_GlobalInvocationID.x;

	if (index >= XDIM){
		return;
	}

	// l(x)
	pos[index].w = (l(pos[index].x) - lneg(pos[index].x));

	// m_dot = rhoAv
	vel[index].x = MASS_FLOW/pos[index].w;

	// dynamic pressure
	// P = 1/2rhoV^2
	pressure[index].x = 0.5 * 1 * vel[index].x * vel[index].x;

}