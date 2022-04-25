class DirectionalLight {

    constructor(lightIntensity, lightColor, lightPos, focalPoint, lightUp, hasShadowMap, gl) {
        this.mesh = Mesh.cube(setTransform(0, 0, 0, 0.2, 0.2, 0.2, 0));
        this.mat = new EmissiveMaterial(lightIntensity, lightColor);
        this.lightPos = lightPos;
        this.focalPoint = focalPoint;
        this.lightUp = lightUp

        this.hasShadowMap = hasShadowMap;
        this.fbo = new FBO(gl);
        if (!this.fbo) {
            console.log("无法设置帧缓冲区对象");
            return;
        }
    }

    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();

        let eye = vec3.create();
        let center = vec3.create();
        let up = vec3.create();
        let translateVec = vec3.create();
        let scaleVec = vec3.create();
        vec3.set(eye, ...this.lightPos);
        vec3.set(center, ...this.focalPoint);
        vec3.set(up, ...this.lightUp);
        vec3.set(translateVec, ...translate);
        vec3.set(scaleVec, ...scale);
        vec3.normalize(eye, eye);
        vec3.normalize(center, center)
        vec3.normalize(up, up)

        // Model transform
        mat4.identity(modelMatrix);
        mat4.translate(modelMatrix, modelMatrix, translate);
        mat4.scale(modelMatrix, modelMatrix, scale);

        // View transform
        mat4.identity(viewMatrix);
        mat4.lookAt(viewMatrix, eye, center, up);
    
        // Projection transform
        mat4.identity(projectionMatrix);
        let range = 100;
        mat4.ortho(projectionMatrix, -range, range, -range, range, -range, range);

        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);

        return lightMVP;
    }
}
