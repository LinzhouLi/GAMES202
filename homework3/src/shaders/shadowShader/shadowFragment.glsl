#ifdef GL_ES
#extension GL_EXT_draw_buffers: enable
precision highp float;
#endif

uniform vec3 uCameraPos;

varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;
varying highp float vDepth;

vec4 pack (float depth) {
  // 使用rgba 4字节共32位来存储z值,1个字节精度为1/256
  const vec4 bitShift = vec4(1.0, 255.0, 65025.0, 16581375.0);
  const vec4 bitMask = vec4(1.0 / 255.0, 1.0 / 255.0, 1.0 / 255.0, 0.0);
  // gl_FragCoord:片元的坐标,fract():返回数值的小数部分
  vec4 rgbaDepth = fract(depth * bitShift); //计算每个点的z值
  rgbaDepth -= rgbaDepth.gbaa * bitMask; // Cut off the value which do not fit in 8 bits
  return rgbaDepth;
}

void main(){
  gl_FragData[0] = pack(gl_FragCoord.z);
  // gl_FragData[0] = EncodeFloatRGBA(gl_FragCoord.z * 100.0);
}