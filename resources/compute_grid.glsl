#version 450 
layout(local_size_x = 1, local_size_y = 2) in;	


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

	width = (l(pos[grid_x][grid_y].x) - lneg(pos[grid_x][grid_y].x));
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

	//pos[posx][posy].z = l(pos[posx][posy].x);
	//pos[posx][posy].w = lneg(pos[posx][posy].x);

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

	if (posy == 0 && posx < num_sphere) {
		vec2 spherePos = getSpherePos(positionSphere[posx]);
		accelerationSphere[posx] = vel[int(spherePos.x)][int(spherePos.y)].xy;
	}

}

/*

#define rho 1
#define mu 1
#define Re(v,x) sqrt(rho*v*x/mu)
#define delta99(x,v,L) 0
#define u(x,y) ( sqrt(mu/rho/x)*5.0*x/y ) * ( sqrt(mu/rho/x)*5.0*x/y )
	float b = (540 + lneg(float(pixel_coords.x) / 192) * 192);
	float a = (540 + l(float(pixel_coords.x) / 192) * 192);

	//float pixelVelocity = sin((pixel_coords.y - b) / (a - b) * PI) * vel[pos_index].x; // MAXVELOCITY 

	float pixelVelocity;

	float delta99 = 5.0 * pixel_coords.x /Re(vel[pos_index].x,pixel_coords.x);
	if (pixel_coords.y > delta99){
		pixelVelocity = vel[pos_index].x;
	}else{
		pixelVelocity = u(pixel_coords.x, pixel_coords.y);
	}
*/