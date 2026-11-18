#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float phase; vec2 pixelStep; };
layout(binding=1) uniform sampler2D source;
void main() {
 vec2 uv=qt_TexCoord0;
 float a=atan(uv.y-.5,uv.x-.5)/6.2831853+.5;
 float d=abs(a-phase); d=min(d,1.-d);
 float beam=exp(-d*d/0.0015);
 float mask=texture(source,uv).a;
 vec2 stepUV=2.0*pixelStep;
 float halo=(texture(source,uv+vec2(stepUV.x,0)).a+texture(source,uv-vec2(stepUV.x,0)).a+texture(source,uv+vec2(0,stepUV.y)).a+texture(source,uv-vec2(0,stepUV.y)).a)*.12;
 float alpha=min(1.,(mask+halo)*beam);
 fragColor=vec4(mix(vec3(.65,.45,1.),vec3(1.),mask)*alpha,alpha)*qt_Opacity;
}
