#version 330

$GLMatrices

#extension GL_EXT_geometry_shader4: enable
#extension GL_EXT_gpu_shader4: enable

layout(triangles) in;
//error C6033: Hardware limitation reached, can only emit 128 vertices of this size
layout(points, max_vertices=128) out;



// Constants for the explosion effect
// number of repetitions of the subdivision (if this increases then you have to reduce max_vertices)
uniform int uLevel = 4;

// gravity factor depending on the 3D model size. For "bunny" is ok in [0.0, 0.05]
float gravity = 0.01f;

// traslation units to move the new vertex in the desired direction
uniform float uT = 7.5f;

// speed factor of the traslation
uniform float uVelScale = 1.125f;



// Variables the explosion effect
// current time for explosion/implosion (it is comming from an interpolator)
uniform float tiempo;

// vectors on the triangle
vec3 V0, V01, V02;

// triangle centroid
vec3 CG;

// triangle normal vector
vec3 Normal;



// lighting
in vec4 color[3];
out vec4 fragColor;
uniform vec3 lightpos;



// clipping
uniform vec4 cube;
uniform vec4 cubeRotation;


// given a vertex it will check if it is inside the volume of the clipping object for discarding that vertex
int checkIsInside(vec4 pos){
	int aligned;
	if (cubeRotation.w == 0.0f) aligned = 1; else aligned = 0;

	vec3 c = cube.xyz; float lado = cube.w; float r = lado/2;

	int isInside = 0;

	// computational cost is less if cube is aligned with the world axis
	if (aligned == 1){

		// clipping boundaries in world coordinates
		float xinf = (c.x - r),	xsup = (c.x + r), yinf = (c.y - r),	ysup = (c.y + r), zinf = (c.z - r), zsup = (c.z + r);

		// if all 3 coordinates of the vertex are in range [center - radius, center +  radius] then is inside the cube
		// gl_Position in world coordinates

		if (xinf < pos.x && pos.x < xsup &&
			yinf < pos.y && pos.y < ysup &&
			zinf < pos.z && pos.z < zsup )
			isInside = 1;
	}
	else {
		// rotation angle on Y axis
		float a = radians(cubeRotation.w);
		float cos_a = cos(a), sin_a = sin(a);

		// rotation matrix on its own Y axis. For GLSL we have to write by columns
		mat4 Ry = mat4(
			vec4(cos_a, 0.0f, -sin_a, 0.0f),
			vec4(0.0f, 1.0f, 0.0f, 0.0f),
			vec4(sin_a, 0.0f, cos_a, 0.0f),
			vec4(0.0f, 0.0f, 0.0f, 1.0f)
		);

		// traslation matrix to the center of the cube in world coordinates. For GLSL we have to write by columns
		mat4 T = mat4(
			vec4(1.0f, 0.0f, 0.0f, 0.0f),
			vec4(0.0f, 1.0f, 0.0f, 0.0f),
			vec4(0.0f, 0.0f, 1.0f, 0.0f),
			vec4(c.x, c.y, c.z, 1.0f)
		);

		// accumulating transformations in one matrix
		mat4 TRy = T * Ry;

		// centers of cube sides (in the world origin)
		vec4 c1, c2, c3, c4, c5, c6;
		c1 = c2 = c3 = c4 = c5 = c6 = vec4(0.0f, 0.0f, 0.0f, 1.0f);
		c1.x = c1.x - r; c2.x = c2.x + r;
		c3.y = c3.y - r; c4.y = c4.y + r;
		c5.z = c5.z - r; c6.z = c6.z + r;

		// applying rotation on Y axis and traslation (in world coordinates)
		c1 = TRy * c1; c2 = TRy * c2;    //left, right
		c3 = TRy * c3; c4 = TRy * c4;    //bottom, top
		c5 = TRy * c5; c6 = TRy * c6;    //rear, front

		// rotating normal vectors (of cube sides) on Y axis (in world coordiantes)
		vec4 n1 = Ry * vec4(-1.0f, 0.0, 0.0f, 1.0f); vec4 n2 = Ry * vec4(1.0f, 0.0, 0.0f, 1.0f);
		vec4 n3 = Ry * vec4(0.0f, -1.0, 0.0f, 1.0f); vec4 n4 = Ry * vec4(0.0f, 1.0, 0.0f, 1.0f);
		vec4 n5 = Ry * vec4(0.0f, 0.0, -1.0f, 1.0f); vec4 n6 = Ry * vec4(0.0f, 0.0, 1.0f, 1.0f);
								
		// for each cube side: vector from cube-side center to "bunny" vertex (in world coordinates)
		// vector = normalize(destination - origin)
		vec4 v1 = normalize(pos - c1); vec4 v2 = normalize(pos - c2);
		vec4 v3 = normalize(pos - c3); vec4 v4 = normalize(pos - c4);
		vec4 v5 = normalize(pos - c5); vec4 v6 = normalize(pos - c6);

		// if all the cos between the previous vectors and cube-side normals are <= 0, then the vertex is inside the clipping cube
		// Remember: vector product between unit vectors gives the cos, and we can use "dot" instead of "cos" for efficiency
		// u·v = |u|·|v|·cos(a) = cos(a)
		float cos1 = dot(v1, n1); float cos2 = dot(v2, n2);
		float cos3 = dot(v3, n3); float cos4 = dot(v4, n4);
		float cos5 = dot(v5, n5); float cos6 = dot(v6, n6);

		if (cos1 <= 0 && cos2 <= 0 && cos3 <= 0 && cos4 <= 0 && cos5 <= 0 && cos6 <= 0)
			isInside = 1;
	}

	return isInside;
}


/*
produceVertex: This function produces a vertex from the parametric coordinates (s and t) of the triangle
and displace them in a computed direction. For displacing the new vertices it will use speed factor and
gravity factor.

Triangle parametric coordinates:
	      (s,t)=(1,0)
		      /\
			 /  \
(s,t)=(0,0) -- (s,t)=(0,1);

"v" is the result of dividing the tringle using the parametric coordinates
"GC" is the centroid of the original triangle
"v - GC" is the direction vector that will be used for displacing the new vertex
*/

void produceVertex( float s, float t ){
	// computing position of new vertex from the new parametric coordinates
	vec3 v = V0 + s*V01 + t*V02;

	// computing the displacement of new vertex (from centroid to new vertex, or viceversa when it is imploding)
	vec3 vel = uVelScale * tiempo * (v - CG);
	vec3 vDesp = v + vel*uT + 0.5*vec3( 0.0f, gravity, 0.0f)*uT*uT;

	if ( checkIsInside( vec4( vDesp, 1.0f ) ) == 1 ){
		// emiting red vertex
		fragColor = vec4 (1.0f, 0.2f, 0.1f, 1.0f);
		gl_Position = projMatrix * viewMatrix * vec4( vDesp, 1.0f );
		EmitVertex();

		// for emiting blue
		//fragColor = vec4 (0.1f, 0.2f, 1.0f, 1.0f);
		//vDesp.x *= tiempo;
	}
	else 
		// average color  of the 3 original vertices
		fragColor = color[0] + color[1] + color[2] / 3.0f;

	// setting the final position of new vertex
	gl_Position = projMatrix * viewMatrix * vec4( vDesp, 1.0f );

	// emiting vertex (position and color will be received in fragment shader)
	EmitVertex();
}



void main(){

	// vectors on the triangle plane
	V01 = ( gl_PositionIn[1] - gl_PositionIn[0] ).xyz;
	V02 = ( gl_PositionIn[2] - gl_PositionIn[0] ).xyz;

	// triangle normal vector
	Normal = normalize( cross( V01, V02 ) );

	// initial position
	V0 = gl_PositionIn[0].xyz;

	// traingle centroid
	CG = ( gl_PositionIn[0].xyz + gl_PositionIn[1].xyz + gl_PositionIn[2].xyz ) / 3.0f;

	// number of times for repeating the triangle subdivision (numLayer = 2 ^ uLevel)
	int numLayers = 1 << uLevel;

	// delta for coordinate t
	float dt = 1.0f / float( numLayers );

	// initial value of t
	float t = 1.0f;

	// for each value of t
	for(int i = 0; i <= numLayers; i++){
		float smax = 1.0f - t;
		int nums = i + 1;

		// delta for coordinate s
		float ds = smax / float( nums - 1 );

		// initial value of s
		float s = 0.0f;

		// for each value of s
		for(int j = 0; j < nums; j++){
			produceVertex( s, t );

			s += ds;
		}

		t -= dt;
	}
}
