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
	float svel[MAX_SPHERE];

};

layout(std430, binding = 3) volatile buffer sphere_data
{
	vec4 positionSphere[MAX_SPHERE];      // x: xpos; y: ypos; z: mass
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
uniform int source_sink_toggle;


// 10m scale
// l(x): y = 0.0725x^2 - 0.725x + 2.8125
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

#define rho 1.225
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

	pressure[posx][posy].zw = vel[posx][posy].xy;

	// dynamic pressure
	// P = 1/2rhoV^2
	pressure[posx][posy].x = -0.5 * 1 * vel[posx][posy].x * vel[posx][posy].x;


	if (posy == 540 && posx < num_sphere) {
		vec2 spherePos = getSpherePos(positionSphere[posx].xy);
		accelerationSphere[posx] = vel[int(spherePos.x)][int(spherePos.y)].xy / positionSphere[posx].z * 1.5;

	}




	for (int i = 0; i < num_sphere && source_sink_toggle > 0; i++){

		//ivec2 sphere_coords[];
		//vec2 dP[];


		/* Source & Sink Positions */
		vec2 sphere_pos = vec2(sphere_coords[i]);
		sphere_pos /= XY_SCALE;
		sphere_pos.y -= float(RESY) / 2 / 192; // in real world coordinates

		float radius = positionSphere[i].z * 0.02 * 800 / 192; // in real world coordinates


		vec2 velocity = vel[sphere_coords[i].x][sphere_coords[i].y].xy;

		vec2 front = sphere_pos - vec2(normalize(velocity) * radius);
		vec2 rear = sphere_pos + vec2(normalize(velocity) * radius);

		float temp = velocity.x;
		velocity.x = velocity.y;
		velocity.y = temp;

		vec2 top = sphere_pos + vec2(normalize(velocity) * radius);
		vec2 bot = sphere_pos - vec2(normalize(velocity) * radius);


		// Rear
		//pressure[posx][posy].x -= dP[i] * 1 / pow( distance(pos[posx][posy].xy,rear) + 1, 3);

		float dist = sqrt(pow(abs(pos[posx][posy].x - rear.x), 2) + pow(abs(pos[posx][posy].y - rear.y) * 2, 2));
		pressure[posx][posy].x -= 0.25 * 0.1 / pow(dist + 1, 6);


		// Front
		//pressure[posx][posy].x += 1/2 * rho * pow(  length(vel[sphere_coords[i].x][sphere_coords[i].y].xy ) , 2) * 1 / pow( distance(pos[posx][posy].xy,front) + 1, 2);
		//vel[posx][posy].xy -= vel[sphere_coords[i].x][sphere_coords[i].y].xy * 1 / pow( distance(pos[posx][posy].xy,front) + 1, 2);

		dist = sqrt(pow(abs(pos[posx][posy].x - front.x) * 2, 2) + pow(abs(pos[posx][posy].y - front.y), 2));

		pressure[posx][posy].x += abs(pressure[posx][posy].x) * 1 / pow(dist + 1, 6);
		pressure[posx][posy].zw -= pressure[posx][posy].zw * 1 / pow(dist + 1, 6);

		//top
		//pressure[posx][posy].zw  += velocity*2  * 1 / pow( distance(pos[posx][posy].xy,front) + 1, 4);

		//bottom
		//pressure[posx][posy].zw  += velocity*2  * 1 / pow( distance(pos[posx][posy].xy,front) + 1, 4);



	}

}