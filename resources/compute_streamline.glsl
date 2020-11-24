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


uniform float dist;
uniform int num_sphere;
uniform int frame_num;
uniform int display_particles;

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




#define dt 0.1
#define PARTICLE_RATE 25
void main(){


	if (display_particles == 0){
		return;
	}

	int index = int(gl_GlobalInvocationID.x);

	// spawn particles
	int spawn_interval = frame_num % PARTICLE_RATE; // [0 ... inf) spawn counter
	int group_number = (frame_num / PARTICLE_RATE) % 8; //[0 ... 8) 8 groups
	if (spawn_interval == 0){ // spawn after so many frames
		if (index >= group_number * 32 && index < (group_number + 1) * 32){ // groups of 32 in size
			int offset = index % 32 - 16; // [0 ... 32) -> [-16 ... 32)
			stream_pos[index] = vec4(0, float(offset) * 0.17578125 + 0.17578125/2,0,1);
		}
	}

	if (stream_pos[index].w == 1){
	
		if ( isWall(stream_pos[index].xy) == 1 || stream_pos[index].x > 10){
			//delete particle
			stream_pos[index] = vec4(0);
			return;
		}


		int posx = int(stream_pos[index].x*192);
		int posy = int(stream_pos[index].y*192 + 540);

		stream_pos[index].xy += normalize(vel[posx][posy].xy) * dt;

		posx = int(stream_pos[index].x*192);
		posy = int(stream_pos[index].y*192 + 540);

		//temp[index].xy = vec2(posx,posy);

		imageStore(img_output, ivec2(posx,posy), vec4(1) );
		imageStore(img_output, ivec2(posx+1,posy), vec4(1) );
		imageStore(img_output, ivec2(posx-1,posy), vec4(1) );
		imageStore(img_output, ivec2(posx,posy+1), vec4(1) );
		imageStore(img_output, ivec2(posx,posy-1), vec4(1) );


	}



}





