attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;
attribute mat3 aPrecomputeLT;

uniform mat3 uPrecomputedLR;
uniform mat3 uPrecomputedLG;
uniform mat3 uPrecomputedLB;
uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;
varying highp vec3 vColor;

#define PI 3.141592653589793

highp float matDot(mat3 a, mat3 b) {

    return (
        a[0][0] * b[0][0] +
        a[1][0] * b[1][0] +
        a[2][0] * b[2][0] +
        a[0][1] * b[0][1] +
        a[1][1] * b[1][1] +
        a[2][1] * b[2][1] +
        a[0][2] * b[0][2] +
        a[1][2] * b[1][2] +
        a[2][2] * b[2][2]
    );

}

void main(void) {

    vFragPos = (uModelMatrix * vec4(aVertexPosition, 1.0)).xyz;
    vNormal = (uModelMatrix * vec4(aNormalPosition, 0.0)).xyz;
    vTextureCoord = aTextureCoord;
    vColor = vec3(
        matDot(uPrecomputedLR, aPrecomputeLT),
        matDot(uPrecomputedLG, aPrecomputeLT),
        matDot(uPrecomputedLB, aPrecomputeLT)
    ) / PI;

    gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);

}