# exploding_bunny
OpenGL app that shows the explosion effect of an object using C++ and GLSL. Most of the computations are performed in the geometry shader. It uses the parametric coordinates of the triangles for subdividing them N times and translate the new produced vertices over time. It uses the centroid of the triangles as reference for the direction vectors of traslation for each new vertex. giovanny.jtt@gmail.com

https://youtu.be/FPhnLEm4NMk

![Exploding Bunny Image](./images/exploding_bunny_gif.gif "Exploding Bunny Gif")
