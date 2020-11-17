/*
CPE/CSC 471 Lab base code Wood/Dunn/Eckhardt
*/

#include <iostream>
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include "GLSL.h"
#include "Program.h"
#include "MatrixStack.h"

#include "WindowManager.h"
#include "Shape.h"
// value_ptr for glm
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/matrix_transform.hpp>
using namespace std;
using namespace glm;

#define RESX 1920
#define RESY 1080


shared_ptr<Shape> sphere;
std::vector<float> bufInstance(RESX * RESY * 4);
std::vector<unsigned char> buffer(RESX * RESY * 4);
std::vector<unsigned char> buffer2(RESX * RESY * 4);

GLuint computeGridProgram, computeHeatMapProgram, computeParticleProgram;

#define ARRAY_LEN 100
#define NUM_SPHERE 100

class ssbo_data
{
public:
	// grid
	vec4 pos[ARRAY_LEN]; // w = 1, unused
	vec4 vel[ARRAY_LEN];

	// properties
	vec4 pressure[ARRAY_LEN];

	// reserved for debugging
	vec4 temp[ARRAY_LEN];
};


double get_last_elapsed_time()
{
	static double lasttime = glfwGetTime();
	double actualtime =glfwGetTime();
	double difference = actualtime- lasttime;
	lasttime = actualtime;
	return difference;
}

class Camera
{
public:
	glm::vec3 pos, rot;
	int w, a, s, d;
	Camera()
	{
		w = a = s = d = 0;
		pos = rot = glm::vec3(0, 0, 0);
	}
	glm::mat4 process(double ftime)
	{
		float speed = 0;
		if (w == 1)
		{
			speed = 10 * ftime;
		}
		else if (s == 1)
		{
			speed = -10 * ftime;
		}
		float yangle = 0;
		if (a == 1)
			yangle = -3 * ftime;
		else if (d == 1)
			yangle = 3 * ftime;
		rot.y += yangle;
		glm::mat4 R = glm::rotate(glm::mat4(1), rot.y, glm::vec3(0, 1, 0));
		glm::vec4 dir = glm::vec4(0, 0, speed, 1);
		dir = dir * R;
		pos += glm::vec3(dir.x, dir.y, dir.z);
		glm::mat4 T = glm::translate(glm::mat4(1), pos);
		return R * T;
	}
};


class Object {
	public:
		vec4 position[NUM_SPHERE];
		vec3 velocity[NUM_SPHERE];
};

class Application : public EventCallbacks
{

public:

	WindowManager * windowManager = nullptr;

	// Our shader program
	std::shared_ptr<Program> postproc;
	std::shared_ptr<Program> prog;

	// Contains vertex information for OpenGL
	GLuint VertexArrayID, VertexArrayIDScreen;

	// Data necessary to give our box to OpenGL
	GLuint VertexBufferID, VertexBufferTexScreen, VertexBufferIDScreen,VertexNormDBox, VertexTexBox, IndexBufferIDBox, InstanceBuffer;

	//framebufferstuff
	GLuint fb, depth_fb, FBOtex;
	//texture data
	GLuint Texture, Texture2;
	GLuint CS_tex_A, CS_tex_B, ssbo_GPU_id;
	ssbo_data ssbo;

	int tex_w, tex_h;
	GLuint SphereTexture;
	Camera camera;
	Object sphereObj;

	void keyCallback(GLFWwindow *window, int key, int scancode, int action, int mods)
	{
		if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
		{
			glfwSetWindowShouldClose(window, GL_TRUE);
		}
		
	}

	// callback for the mouse when clicked move the triangle when helper functions
	// written
	bool mousepressed = false;
	int mouse_current_x = 0;
	int mouse_current_y = 0;
	void mouseCallback(GLFWwindow* window, int button, int action, int mods)
	{
		double posX, posY;
		glfwGetCursorPos(window, &posX, &posY);
		static double LposX = posX, LposY = posY;

		float newPt[2];
		mousepressed = false;
		if (action == GLFW_PRESS)
		{
			mousepressed = true;
			double dx = posX - LposX;
			double dy = posY - LposY;
			std::cout << "Pos X " << dx << " Pos Y " << dy << std::endl;

		}
		if (action == GLFW_RELEASE) {
			mousepressed = false;
		}
		LposX = posX;
		LposY = posY;
	}

	//if the window is resized, capture the new size and reset the viewport
	void resizeCallback(GLFWwindow *window, int in_width, int in_height)
	{
		//get the window size - may be different then pixels for retina
		int width, height;
		glfwGetFramebufferSize(window, &width, &height);
		glViewport(0, 0, width, height);
	}
#define XDIM 100
	void initGrid() {

		// initialize the grid
		for (int i = 0; i < XDIM; i++) {

			ssbo.pos[i] = vec4( ((float) i) / 10.0f, 0, 0, 0);

		}

	}

	/*Note that any gl calls must always happen after a GL state is initialized */
	void initGeom()
	{

		string resourceDirectory = "../resources";


		// load in sphere 
		sphere = make_shared<Shape>();
		sphere->loadMesh(resourceDirectory + "/sphere.obj");
		sphere->resize();
		sphere->init();
	

		//screen plane
		glGenVertexArrays(1, &VertexArrayIDScreen);
		glBindVertexArray(VertexArrayIDScreen);
		//generate vertex buffer to hand off to OGL
		glGenBuffers(1, &VertexBufferIDScreen);
		//set the current state to focus on our vertex buffer
		glBindBuffer(GL_ARRAY_BUFFER, VertexBufferIDScreen);
		vec3 vertices[6];
		vertices[0] = vec3(-1,-1,0);
		vertices[1] = vec3(1, -1, 0);
		vertices[2] = vec3(1, 1, 0);
		vertices[3] = vec3(-1, -1, 0);
		vertices[4] = vec3(1, 1, 0);
		vertices[5] = vec3(-1, 1, 0);
		//actually memcopy the data - only do this once
		glBufferData(GL_ARRAY_BUFFER, 6 * sizeof(vec3), vertices, GL_STATIC_DRAW);
		//we need to set up the vertex array
		glEnableVertexAttribArray(0);
		//key function to get up how many elements to pull out at a time (3)
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, (void*)0);
		//generate vertex buffer to hand off to OGL
		glGenBuffers(1, &VertexBufferTexScreen);
		//set the current state to focus on our vertex buffer
		glBindBuffer(GL_ARRAY_BUFFER, VertexBufferTexScreen);
		vec2 texscreen[6];
		texscreen[0] = vec2(0, 0);
		texscreen[1] = vec2(1, 0);
		texscreen[2] = vec2(1, 1);
		texscreen[3] = vec2(0, 0);
		texscreen[4] = vec2(1, 1);
		texscreen[5] = vec2(0, 1);
		//actually memcopy the data - only do this once
		glBufferData(GL_ARRAY_BUFFER, 6 * sizeof(vec2), texscreen, GL_STATIC_DRAW);
		//we need to set up the vertex array
		glEnableVertexAttribArray(1);
		//key function to get up how many elements to pull out at a time (3)
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
		glBindVertexArray(0);
		


	

		int width, height, channels;
		

		//texture 1
	
		//[TWOTEXTURES]
		//set the 2 textures to the correct samplers in the fragment shader:
		GLuint Tex1Location;

		Tex1Location = glGetUniformLocation(postproc->pid, "tex");//tex, tex2... sampler in the fragment shader
		glUseProgram(postproc->pid);
		glUniform1i(Tex1Location, 0);


		glfwGetFramebufferSize(windowManager->getHandle(), &width, &height);
		//RGBA8 2D texture, 24 bit depth texture, 256x256
		//-------------------------
		//Does the GPU support current FBO configuration?
		GLenum status;
		status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		switch (status)
		{
		case GL_FRAMEBUFFER_COMPLETE:
			cout << "status framebuffer: good";
			break;
		default:
			cout << "status framebuffer: bad!!!!!!!!!!!!!!!!!!!!!!!!!";
		}
		glBindFramebuffer(GL_FRAMEBUFFER, 0);


		//load input image
		unsigned char* pic_data = stbi_load("../resources/testflow2.png", &width, &height, &channels, 4); //store the input data on the CPU memory and get the address
		float* temp;
		temp = (float*)malloc(RESX * RESY * 4 * sizeof(float));
		for (int i = 0; i < RESX * RESY * 4; i++)
			temp[i] = (float)pic_data[i] / 256;

		//make a texture (buffer) on the GPU to store the input image
		tex_w = width, tex_h = height;		//size
		glGenTextures(1, &CS_tex_A);		//Generate texture and store context number
		glActiveTexture(GL_TEXTURE0);		//since we have 2 textures in this program, we need to associate the input texture with "0" meaning first texture
		glBindTexture(GL_TEXTURE_2D, CS_tex_A);	//highlight input texture
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);	//texture sampler parameter
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);	//texture sampler parameter
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);		//texture sampler parameter
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);		//texture sampler parameter
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, tex_w, tex_h, 0, GL_RGBA, GL_FLOAT, temp);	//copy image data to texture
		glBindImageTexture(0, CS_tex_A, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);	//enable texture in shader

		//make a texture (buffer) on the GPU to store the output image
		glGenTextures(1, &CS_tex_B);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, CS_tex_B);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, tex_w, tex_h, 0, GL_RGBA, GL_FLOAT, NULL);
		glBindImageTexture(1, CS_tex_B, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);
		
		stbi_image_free(temp);

		// load in sphere texture
		char filepath[1000];
		string img = resourceDirectory + "/Winslow_nebula.jpg";
		strcpy(filepath, img.c_str());
		unsigned char* data = stbi_load(filepath, &width, &height, &channels, 4);
		glGenTextures(1, &SphereTexture);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, SphereTexture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
		glGenerateMipmap(GL_TEXTURE_2D);

		GLuint l1 = glGetUniformLocation(prog->pid, "tex");//tex, tex2... sampler in the fragment shader
		GLuint l2 = glGetUniformLocation(prog->pid, "tex2");
		// Then bind the uniform samplers to texture units:
		glUseProgram(prog->pid);
		glUniform1i(l1, 0);
		glUniform1i(l2, 1);


		// init sphere objs
		for (int i = 0; i < NUM_SPHERE; i++) {
			sphereObj.position[i] = vec4(rand() % 8 - 4, rand() % 8 - 4, -(rand() % 10 + 15), 0.1);
			sphereObj.velocity[i] = vec4(0, -1 * randf(), 0, 1);
		}

	}

	float randf(float shift = 0)
	{
		return (float)(rand() / (float)RAND_MAX) + shift;
	}
	void createComputeShader(GLuint* compute_program, std::string filename) {

		std::string full_path = "../resources/" + filename + ".glsl";
		//load compute shader 1
		std::string ShaderString = readFileAsString(full_path);
		const char* shader = ShaderString.c_str();
		GLuint computeShader = glCreateShader(GL_COMPUTE_SHADER);
		glShaderSource(computeShader, 1, &shader, nullptr);

		GLint rc;
		CHECKED_GL_CALL(glCompileShader(computeShader));
		CHECKED_GL_CALL(glGetShaderiv(computeShader, GL_COMPILE_STATUS, &rc));
		if (!rc)	//error compiling the shader file
		{
			GLSL::printShaderInfoLog(computeShader);
			std::cout << "Error compiling [" << filename << "] compute shader " << std::endl;
			cin.get();
			exit(1);
		}

		*compute_program = glCreateProgram();
		glAttachShader(*compute_program, computeShader);
		glLinkProgram(*compute_program);
		glUseProgram(*compute_program);

	}

	//General OGL initialization - set OGL state here
	void init(const std::string& resourceDirectory)
	{
		
		GLSL::checkVersion();

		// Set background color.
		glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
		// Enable z-buffer test.
		glEnable(GL_DEPTH_TEST);

		// Initialize the GLSL program.
		

		//program for the postprocessing
		postproc = std::make_shared<Program>();
		postproc->setVerbose(true);
		postproc->setShaderNames(resourceDirectory + "/postproc_vertex.glsl", resourceDirectory + "/postproc_fragment.glsl");
		if (!postproc->init())
		{
			std::cerr << "One or more shaders failed to compile... exiting!" << std::endl;
			exit(1);
		}
		postproc->addAttribute("vertPos");
		postproc->addAttribute("vertTex");



		// init prog for spheres
		prog = std::make_shared<Program>();
		prog->setVerbose(true);
		prog->setShaderNames(resourceDirectory + "/shader_vertex.glsl", resourceDirectory + "/shader_fragment.glsl");
		if (!prog->init())
		{
			std::cerr << "One or more shaders failed to compile... exiting!" << std::endl;
			exit(1);
		}
		prog->addUniform("P");
		prog->addUniform("V");
		prog->addUniform("M");
		prog->addUniform("campos");
		prog->addAttribute("vertPos");
		prog->addAttribute("vertNor");
		prog->addAttribute("vertTex");



		//load the compute shader
		createComputeShader( &computeGridProgram, "compute_grid");

		//load the HeatMap shader
		createComputeShader(&computeHeatMapProgram, "compute_heatmap");

		initGrid();

		// create ssbo
		glGenBuffers(1, &ssbo_GPU_id);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo_GPU_id);
		glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(ssbo_data), &ssbo, GL_DYNAMIC_COPY);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, ssbo_GPU_id);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0); // unbind
		// --------------------------------------------------------
		// link ssbo
		GLuint block_index;
		block_index = glGetProgramResourceIndex(computeGridProgram, GL_SHADER_STORAGE_BLOCK, "grid_data");
		GLuint ssbo_binding_point_index = 2;
		glShaderStorageBlockBinding(computeGridProgram, block_index, ssbo_binding_point_index);
	}

	/****DRAW
	This is the most important function in your program - this is where you
	will actually issue the commands to draw any geometry you have set up to
	draw
	********/

	int compute(int printframes){

			// link ssbo
			//GLuint block_index;
			//block_index = glGetProgramResourceIndex(computeGridProgram, GL_SHADER_STORAGE_BLOCK, "grid_data");
			//GLuint ssbo_binding_point_index = 2;
			//glShaderStorageBlockBinding(computeGridProgram, block_index, ssbo_binding_point_index);


			glUseProgram(computeGridProgram);
			glDispatchCompute( (GLuint)1, (GLuint)1, 1);
			glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);

			// test "grid_data"
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo_GPU_id);
			GLvoid* p = glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_WRITE);
			memcpy(&ssbo, p, sizeof(ssbo_data));
			glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0); // unbind


			for (int i = 0; i < XDIM; i++) {
				cout << "X Pos: " << ssbo.pos[i].x << "m, Width: " << ssbo.pos[i].w << "m, Vel: " << ssbo.vel[i].x << "m/s, Gauge Pressure: -" << ssbo.pressure[i].x << "Pa" << endl;
			}

			// copy over data

			static bool flap = 1;
			glUseProgram(computeHeatMapProgram);
			glDispatchCompute((GLuint)tex_w, (GLuint)tex_h, 1);
			glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
			glBindImageTexture(!flap, CS_tex_A, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);
			glBindImageTexture(flap, CS_tex_B, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA32F);

			flap = !flap;

			return flap;

	}

	void update(int i, float delta_t) {
		sphereObj.position[i].x += sphereObj.velocity[i].x * delta_t;
		sphereObj.position[i].y += sphereObj.velocity[i].y * delta_t;
		sphereObj.position[i].z += sphereObj.velocity[i].z * delta_t;
	}

	//*****************************************************************************************
	void render(int texnum){
		// Get current frame buffer size.
		int width, height;
		glfwGetFramebufferSize(windowManager->getHandle(), &width, &height);
		glViewport(0, 0, width, height);
		// Clear framebuffer.
		glClearColor(1.0f, 0.1f, 0.1f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		postproc->bind();
		glActiveTexture(GL_TEXTURE0);
		if (texnum == 0)
			glBindTexture(GL_TEXTURE_2D, CS_tex_B);
		else
			glBindTexture(GL_TEXTURE_2D, CS_tex_A);

		glBindVertexArray(VertexArrayIDScreen);
		glDrawArrays(GL_TRIANGLES, 0, 6);
		postproc->unbind();


		glViewport(0, 0, width, height);

		// Clear framebuffer.
		glClearColor(0.8f, 0.8f, 1.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


		// render spheres
		glm::mat4 V = glm::mat4(1), M = glm::mat4(1), P;

		P = glm::perspective((float)(3.14159 / 4.), (float)((float)width / (float)height), 0.1f, 1000.0f);

		prog->bind();
		
		glm::mat4 TransZ;
		glm::mat4 S = glm::scale(glm::mat4(1.0f), glm::vec3(0.1));

		float frametime = get_last_elapsed_time();

		for (int i = 0; i < NUM_SPHERE; i++) {
			update(i, frametime);

			vec3 pos = sphereObj.position[i];
			TransZ = glm::translate(glm::mat4(1.0f), pos);
			M = TransZ * S;

			V = camera.process(frametime);
			//send the matrices to the shaders
			glUniformMatrix4fv(prog->getUniform("P"), 1, GL_FALSE, &P[0][0]);
			glUniformMatrix4fv(prog->getUniform("V"), 1, GL_FALSE, &V[0][0]);
			glUniformMatrix4fv(prog->getUniform("M"), 1, GL_FALSE, &M[0][0]);
			glUniform3fv(prog->getUniform("campos"), 1, &camera.pos[0]);
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, SphereTexture);
			sphere->draw(prog, FALSE);
		}

		prog->unbind();
	}
};
//******************************************************************************************
int main(int argc, char **argv)
{
	//initialize Open GL
	glfwInit();
	//make a window
	GLFWwindow* window = glfwCreateWindow(512, 512, "Dummy", nullptr, nullptr);
	glfwMakeContextCurrent(window);
	//initialize Open GL Loader function
	gladLoadGL();

	std::string resourceDir = "../resources"; // Where the resources are loaded from
	if (argc >= 2)
	{
		resourceDir = argv[1];
	}

	Application* application = new Application();
	/* your main will always include a similar set up to establish your window
	and GL context, etc. */
	WindowManager* windowManager = new WindowManager();
	windowManager->init(1920, 1080);
	windowManager->setEventCallbacks(application);
	application->windowManager = windowManager;

	/* This is the code that will likely change program to program as you
		may need to initialize or set up different data and state */
		// Initialize scene.
	application->init(resourceDir);
	application->initGeom();

	glUseProgram(computeGridProgram);
	glUseProgram(computeHeatMapProgram);


	// Loop until the user closes the window.
	double timef = 0;
	int printframes = 0;
	while(! glfwWindowShouldClose(windowManager->getHandle()))
	{

		int ret = application->compute(printframes++);

		application->render(ret);

		// Swap front and back buffers.
		glfwSwapBuffers(windowManager->getHandle());
		// Poll for and process events.
		glfwPollEvents();
		//timef = 1./get_last_elapsed_time();
		//printf("%f\n", timef);
	}

	/*int width = RESX, height = RESY;
	stbi_write_png("output.png", width, height, 4, buffer.data(), 0);
	stbi_write_png("output2.png", width, height, 4, buffer2.data(), 0);
	*/
	// Quit program.
	windowManager->shutdown();
	return 0;
}
