#version 330

$GLMatrices

in vec3 position;
in vec3 normal;

// position of source light in camera space
uniform vec3 lightpos;

// diffuse color of object
uniform vec4 diffuseColor;

// value to pass to geometry shader
out vec4 color;

void main() {
	// normal vector in camera space (for computing the lighting)
	vec3 eN = normalize(normalMatrix *normal);

	// vertex position in camera space (for computing the lighting)
	vec4 pos4 = vec4(position, 1.0);
	vec3 eposition=vec3(modelviewMatrix * pos4);

	// computing vertex lighting (considering we only have a point light source)
	color = max(0.0, dot(eN, normalize(lightpos-eposition))) * diffuseColor;

	// vertex position in world coordinates
	gl_Position = modelMatrix * pos4;
}
