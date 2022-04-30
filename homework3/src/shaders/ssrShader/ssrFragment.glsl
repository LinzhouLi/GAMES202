#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

#define EPS 1e-2
#define THRES 0.1
#define RAY_MARCH_STEP 0.8
#define RAY_MARCH_STEP_COUNT 20
#define SAMPLE_NUM 5

#define ROUGHNESS 0.8

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
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

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {

  // Fresnel_term
  vec3 F0 = vec3(0.05); // 基础反射率
  vec3 h = normalize(wi + wo);
  vec3 v = wi;
  vec3 Fresnel_term = F0 + (1.0 - F0) * pow((1.0 - dot(h, v)), 5.0);

  // GGX_NDF
  float alpha = pow(ROUGHNESS, 2.0);
  float alpha_2 = pow(alpha, 2.0);
  vec3 n = GetGBufferNormalWorld(uv);
  float GGX_NDF = alpha_2 / (M_PI * pow(
    pow(dot(n, h), 2.0) * (alpha_2 - 1.0) + 1.0,
    2.0
  ));

  // Shadowing Masking
  float k = pow(ROUGHNESS + 1.0, 2.0) / 8.0;
  float G1L = dot(n, wo) / (dot(n, wo) * (1.0 - k) + k);
  float G1V = dot(n, wi) / (dot(n, wo) * (1.0 - k) + k);
  float Graphic_term = G1L * G1V;

  vec3 BRDF = (Fresnel_term + GGX_NDF + Graphic_term) / (4.0 * dot(n, wi) * dot(n, wo));
  vec3 albedo = GetGBufferDiffuse(uv);
  return BRDF * albedo;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {

  float visibility = GetGBufferuShadow(uv);
  return uLightRadiance * visibility;

}

bool outScreen(vec3 pos){
  vec2 uv = GetScreenCoordinate(pos);
  return any(bvec4(lessThan(uv, vec2(0.0)), greaterThan(uv, vec2(1.0))));
}
bool atFront(vec3 pos){
  return GetDepth(pos) < GetGBufferDepth(GetScreenCoordinate(pos));
}
bool hasInter(vec3 pos, vec3 dir, out vec3 hitPos){
  float d1 = GetGBufferDepth(GetScreenCoordinate(pos)) - GetDepth(pos) + EPS;
  float d2 = GetDepth(pos + dir) - GetGBufferDepth(GetScreenCoordinate(pos + dir)) + EPS;
  if(d1 < THRES && d2 < THRES){
    hitPos = pos + dir * d1 / (d1 + d2);
    return true;
  }  
  return false;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {

  bool intersect = false, firstinter = false;
  float st = RAY_MARCH_STEP;
  vec3 current = ori;
  for (int i = 0;i < RAY_MARCH_STEP_COUNT;i++){
    if(outScreen(current)){
      break;
    }
    else if(atFront(current + dir * st)){
      current += dir * st;
    }else{
      firstinter = true;
      if(st < EPS){
        if(hasInter(current, dir * st * 2.0, hitPos)){
          intersect = true;
        }
        break;
      }
    }
    if(firstinter)
      st *= 0.5;
  }
  return intersect;

}

vec3 DirectLighting(vec2 uv, vec3 pos) {

  vec3 wi = uLightDir;
  vec3 wo = normalize(uCameraPos - pos);
  return EvalDiffuse(wi, wo, uv) * EvalDirectionalLight(uv);

}

vec3 IndirectLighting(vec2 uv, vec3 pos, vec3 normal) {

  float s = InitRand(gl_FragCoord.xy);
  float pdf = 1.0;
  vec3 L = vec3(0.0), hitPos, b1, b2;
  vec3 camDir = normalize(uCameraPos - pos);

  for (int i = 0; i < SAMPLE_NUM; i++) {
    vec3 dir = SampleHemisphereCos(s, pdf);
    LocalBasis(normal, b1, b2);
    dir = normalize(mat3(b1, b2, normal) * dir);
    // dir = reflect(-camDir, normal);

    if (RayMarch(pos, dir, hitPos)) {
      vec2 hituv = GetScreenCoordinate(hitPos);
      L += 1.0 / pdf *
        EvalDiffuse(-dir, camDir, uv) *
        EvalDiffuse(uLightDir, -dir, hituv) *
        EvalDirectionalLight(hituv);
    }
  }

  return L / float(SAMPLE_NUM);

}

void main() {

  vec3 posWorld = vPosWorld.xyz;
  vec2 uv = GetScreenCoordinate(posWorld);
  vec3 normalWorld = GetGBufferNormalWorld(uv);

  vec3 L = DirectLighting(uv, posWorld) + IndirectLighting(uv, posWorld, normalWorld);
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(color, 1.0);
}
