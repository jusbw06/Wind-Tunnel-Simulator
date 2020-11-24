#version 450 
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_arrays_of_arrays : require

layout(local_size_x = 1, local_size_y = 1) in;	


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
	float drag[MAX_SPHERE];

	int mouse_x;
	int mouse_y;
	int numSphere;
};

uniform float dist;
uniform int num_sphere;


// 10m scale
// l(x): y = 0.0725x^2 - 0.725x + 2.8125
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

vec2 interpolate_velocity(float abs_vel, uint grid_x, uint grid_y, float L){

	float width, db, dc;
	vec2 resultant;

	//abs_vel = 1;

	width = (l(pos[grid_x][grid_y].x) - lneg(pos[grid_x][grid_y].x))/2;
	dc = pos[grid_x][grid_y].y; // distance to center
	if (dc < 0){
		dc *= -1;
		db = pos[grid_x][grid_y].y - lneg(pos[grid_x][grid_y].x);
		resultant = ( normalize(vec2(1, -dldx(pos[grid_x][grid_y].x))) * dc/L  + vec2(1, 0) * db/L )* abs_vel;
		//resultant = ( normalize(vec2(1, -dldx(pos[grid_x][grid_y].x)))  ) * abs_vel;


	}else{
		db = l(pos[grid_x][grid_y].x) - pos[grid_x][grid_y].y;
		resultant = ( normalize(vec2(1, dldx(pos[grid_x][grid_y].x))) * dc/L  + vec2(1, 0) * db/L )* abs_vel;
		//resultant = ( normalize(vec2(1, dldx(pos[grid_x][grid_y].x)))  ) * abs_vel;

	}

	resultant = resultant * abs_vel/resultant.x;

	return resultant;
}

vec2 getSpherePos(vec2 spherePos) {
	// SpherePos from 0 to 1
	spherePos = (spherePos + 1.0) / 2.0;

	spherePos.x = spherePos.x * RESX;
	spherePos.y = spherePos.y * RESY;

	return spherePos;
}


#define MASS_FLOW 1.0
void main(){

	uint posx = gl_GlobalInvocationID.x;
	uint posy = gl_GlobalInvocationID.y;
	

	if (posx == 0 && posy == 0) {
		mouseVelocity = vel[mouse_x][mouse_y].xy;
		mousePressure = pressure[mouse_x][mouse_y].xy;
	}

	if ( isWall(pos[posx][posy].xy) == 1 ){
		//isInvalid
		vel[posx][posy] = vec4(0);
		pressure[posx][posy] = vec4(0);
		pos[posx][posy].w = 1; //isWall
		return;
	}
	

	// l(x)
	float width = (l(pos[posx][posy].x) - lneg(pos[posx][posy].x));
	pos[posx][posy].w = width;

	// m_dot = rhoAv
	float vel_abs = MASS_FLOW/width;


	float b = l(pos[posx][posy].x);
	float a = lneg(pos[posx][posy].x);
	vel_abs = sin((pos[posx][posy].y - b) / (a - b) * PI) * vel_abs; // MAXVELOCITY 


	vel[posx][posy].xy = interpolate_velocity(vel_abs, posx, posy, width);

	// dynamic pressure
	// P = 1/2rhoV^2
	pressure[posx][posy].x = 0.5 * 1 * vel[posx][posy].x * vel[posx][posy].x;


	if (posy == 540 && posx < numSphere) {
		vec2 spherePos = getSpherePos(positionSphere[posx].xy);
		accelerationSphere[posx] = vel[int(spherePos.x)][int(spherePos.y)].xy / positionSphere[posx].z * 1.5;
	}


}