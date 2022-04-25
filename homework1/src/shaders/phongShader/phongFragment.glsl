#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 50
#define BLOCKER_SEARCH_NUM_SAMPLES 16
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define BLOCKER_FIND_WIDTH 6.0

#define LIGHT_WIDTH 30.0
#define LIGHT_DEPTH 0.1
#define SHADOW_MAP_RESOLUTION 2048.0

#define SM_BIAS 0.005
#define PCF_BIAS 0.015
#define PCSS_BIAS 0.03
#define PCF_FILTER_SIZE 0.005

#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

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

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

// float findBlocker(sampler2D shadowMap, vec2 uv, float zReceiver) {

//   float step = 1.0 / SHADOW_MAP_RESOLUTION;
//   float shadowMapDepth;
//   float blockerNum = 0.0, blockerSum = 0.0;

//   for (float u = -BLOCKER_FIND_WIDTH / 2.0; u < BLOCKER_FIND_WIDTH / 2.0 + 0.5; u += 1.0) {
//     for (float v = -BLOCKER_FIND_WIDTH / 2.0; v < BLOCKER_FIND_WIDTH / 2.0 + 0.5; v += 1.0) {

//       shadowMapDepth = unpack(texture2D(shadowMap, uv + vec2(u, v) * step));
//       if (zReceiver > shadowMapDepth + PCF_BIAS * zReceiver) {
//         blockerNum += 1.0;
//         blockerSum += shadowMapDepth;
//       }

//     }
//   }
//   if (blockerNum < 0.5) return 0.0;
// 	else return blockerSum / blockerNum;

// }

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

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth
  float receiverDepth = coords.z;
  float avgBlockerDepth = findBlocker(shadowMap, coords.xy, receiverDepth);
  if (avgBlockerDepth < 1e-5) return 1.0;

  // STEP 2: penumbra size
  float penumbraSize = LIGHT_WIDTH * (receiverDepth - avgBlockerDepth) / avgBlockerDepth;

  // STEP 3: filtering
  float visibility = PCF(shadowMap, coords, 0.5 * penumbraSize / SHADOW_MAP_RESOLUTION);
  
  return visibility;

}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord) {

  vec4 rgbaDepth = texture2D(shadowMap, shadowCoord.xy);
  highp float shadowMapDepth = unpack(rgbaDepth);
  highp float trueDepth = shadowCoord.z;

  if (trueDepth < shadowMapDepth + SM_BIAS * trueDepth) return 1.0;
  else return 0.0;

}

vec3 blinnPhong(float visibility) {

  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.01 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = ambient + visibility * (diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;

}

void main(void) {

  float visibility = 1.0;
  vec4 shadowCoord = vPositionFromLight / 2.0 + 0.5;
  poissonDiskSamples(shadowCoord.xy);

  // visibility = useShadowMap(uShadowMap, shadowCoord);
  // visibility = PCF(uShadowMap, shadowCoord, PCF_FILTER_SIZE);
  visibility = PCSS(uShadowMap, shadowCoord);

  vec3 phongColor = blinnPhong(visibility);

  gl_FragColor = vec4(phongColor, 1.0);
  // gl_FragColor = vec4(visibility, visibility, visibility, 1.0);
}