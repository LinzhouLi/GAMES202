#ifdef GL_ES
#extension GL_EXT_draw_buffers: enable
precision highp float;
#endif

uniform sampler2D uKd;
uniform sampler2D uNt;
uniform sampler2D uShadowMap;

varying mat4 vWorldToLight;
varying highp vec2 vTextureCoord;
varying highp vec4 vPosWorld;
varying highp vec3 vNormalWorld;
varying highp float vDepth;

#define NUM_SAMPLES 50
#define BLOCKER_SEARCH_NUM_SAMPLES 16
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define BLOCKER_FIND_WIDTH 6.0

#define LIGHT_WIDTH 30.0
#define LIGHT_DEPTH 0.1
#define SHADOW_MAP_RESOLUTION 2048.0

#define SM_BIAS 0.025
#define PCF_BIAS 0.015
#define PCSS_BIAS 0.03

#define PI 3.141592653589793
#define PI2 6.283185307179586

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
  const vec4 bitShift = vec4(1.0, 1.0 / 255.0, 1.0 / 65025.0, 1.0 / 16581375.0);
  return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

float findBlocker(sampler2D shadowMap, vec2 uv, float zReceiver) {

  float shadowMapDepth;
  float blockerNum = 0.0, blockerSum = 0.0;
  float blockerSize = LIGHT_WIDTH * (zReceiver - LIGHT_DEPTH) / zReceiver / SHADOW_MAP_RESOLUTION;
  for (int i = 0; i < PCF_NUM_SAMPLES; i++) {
    shadowMapDepth = unpack(texture2D(shadowMap, uv + blockerSize * poissonDisk[i]));
    if (zReceiver > shadowMapDepth + PCSS_BIAS * zReceiver) {
      blockerNum += 1.0;
      blockerSum += shadowMapDepth;
    }
  }
  
  if (blockerNum < 0.5) return 0.0;
	else return blockerSum / blockerNum;

}

float PCF(sampler2D shadowMap, vec4 coords, float filterSize) {

  int blocked = 0;
  float trueDepth = coords.z;
  float shadowMapDepth;
  for (int i = 0; i < PCF_NUM_SAMPLES; i++) {
    shadowMapDepth = unpack(texture2D(shadowMap, coords.xy + filterSize * poissonDisk[i]));
    if (trueDepth > shadowMapDepth + PCF_BIAS * trueDepth) blocked++;
  }
  return 1.0 - float(blocked) / float(PCF_NUM_SAMPLES);

}

float PCSS(vec4 coords){

  // STEP 1: avgblocker depth
  float receiverDepth = coords.z;
  float avgBlockerDepth = findBlocker(uShadowMap, coords.xy, receiverDepth);
  if (avgBlockerDepth < 1e-5) return 1.0;

  // STEP 2: penumbra size
  float penumbraSize = LIGHT_WIDTH * (receiverDepth - avgBlockerDepth) / avgBlockerDepth;

  // STEP 3: filtering
  float visibility = PCF(uShadowMap, coords, 0.5 * penumbraSize / SHADOW_MAP_RESOLUTION);
  
  return visibility;

}

float SimpleShadowMap(vec4 shadowCoord) {
  
  vec4 rgbaDepth = texture2D(uShadowMap, shadowCoord.xy);
  highp float shadowMapDepth = unpack(rgbaDepth);
  highp float trueDepth = shadowCoord.z;

  if (trueDepth < shadowMapDepth + SM_BIAS * trueDepth) return 1.0;
  else return 0.0;

}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec3 ApplyTangentNormalMap() {
  vec3 t, b;
  LocalBasis(vNormalWorld, t, b);
  vec3 nt = texture2D(uNt, vTextureCoord).xyz * 2.0 - 1.0;
  nt = normalize(nt.x * t + nt.y * b + nt.z * vNormalWorld);
  return nt;
}

void main(void) {
  vec3 kd = texture2D(uKd, vTextureCoord).rgb;
  vec4 shadowCoord = vWorldToLight * vPosWorld / 2.0 + 0.5;
  // poissonDiskSamples(shadowCoord.xy);

  gl_FragData[0] = vec4(kd, 1.0);
  gl_FragData[1] = vec4(vec3(vDepth), 1.0);
  gl_FragData[2] = vec4(ApplyTangentNormalMap(), 1.0);
  gl_FragData[3] = vec4(SimpleShadowMap(shadowCoord), vec3(1.0));
  gl_FragData[4] = vec4(vec3(vPosWorld.xyz), 1.0);
}
