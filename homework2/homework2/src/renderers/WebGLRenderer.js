class WebGLRenderer {
    meshes = [];
    shadowMeshes = [];
    lights = [];

    #A33; #A33n0; #A33n1; #A33n2;
    #A55; #A55n0; #A55n1; #A55n2; #A55n3; #A55n4;

    constructor(gl, camera) {
        this.gl = gl;
        this.camera = camera;

        this.precomputeA33();
        this.precomputeA55();
    }

    precomputeA33() {

        this.#A33n0 = [1, 0, 0];
        this.#A33n1 = [0, 0, 1];
        this.#A33n2 = [0, 1, 0];

        let pSH0 = SHEval(...this.#A33n0, 3);
        let pSH1 = SHEval(...this.#A33n1, 3);
        let pSH2 = SHEval(...this.#A33n2, 3);

        // let mat = math.matrix([
        //     [pSH0[1], pSH0[2], pSH0[3]],
        //     [pSH1[1], pSH1[2], pSH1[3]],
        //     [pSH2[1], pSH2[2], pSH2[3]],
        // ]);
        let mat = math.matrix([
            [pSH0[1], pSH1[1], pSH2[1]],
            [pSH0[2], pSH1[2], pSH2[2]],
            [pSH0[3], pSH1[3], pSH2[3]],
        ]);
        this.#A33 = math.inv(mat);

    }

    precomputeA55() {

        let k = 1 / Math.sqrt(2);
        this.#A55n0 = [1, 0, 0];
        this.#A55n1 = [0, 0, 1];
        this.#A55n2 = [k, k, 0];
        this.#A55n3 = [k, 0, k];
        this.#A55n4 = [0, k, k];

        let pSH0 = SHEval3(...this.#A55n0);
        let pSH1 = SHEval3(...this.#A55n1);
        let pSH2 = SHEval3(...this.#A55n2);
        let pSH3 = SHEval3(...this.#A55n3);
        let pSH4 = SHEval3(...this.#A55n4);

        // let mat = math.matrix([
        //     [pSH0[4], pSH0[5], pSH0[6], pSH0[7], pSH0[8]],
        //     [pSH1[4], pSH1[5], pSH1[6], pSH1[7], pSH1[8]],
        //     [pSH2[4], pSH2[5], pSH2[6], pSH2[7], pSH2[8]],
        //     [pSH3[4], pSH3[5], pSH3[6], pSH3[7], pSH3[8]],
        //     [pSH4[4], pSH4[5], pSH4[6], pSH4[7], pSH4[8]]
        // ]);
        let mat = math.matrix([
            [pSH0[4], pSH1[4], pSH2[4], pSH3[4], pSH4[4]],
            [pSH0[5], pSH1[5], pSH2[5], pSH3[5], pSH4[5]],
            [pSH0[6], pSH1[6], pSH2[6], pSH3[6], pSH4[6]],
            [pSH0[7], pSH1[7], pSH2[7], pSH3[7], pSH4[7]],
            [pSH0[8], pSH1[8], pSH2[8], pSH3[8], pSH4[8]]
        ]);
        this.#A55 = math.inv(mat);
        
    }

    addLight(light) {
        this.lights.push({
            entity: light,
            meshRender: new MeshRender(this.gl, light.mesh, light.mat)
        });
    }
    addMeshRender(mesh) { this.meshes.push(mesh); }
    addShadowMeshRender(mesh) { this.shadowMeshes.push(mesh); }

    len(x) {return x[0]*x[0] + x[1]*x[1] + x[2]*x[2];}

    computeA33(R) {

        let A33n0R = math.multiply(R, this.#A33n0)._data;
        let A33n1R = math.multiply(R, this.#A33n1)._data;
        let A33n2R = math.multiply(R, this.#A33n2)._data;
        
        let pSH0 = SHEval(...A33n0R, 3);
        let pSH1 = SHEval(...A33n1R, 3);
        let pSH2 = SHEval(...A33n2R, 3);
        
        return math.matrix([
            [pSH0[1], pSH1[1], pSH2[1]],
            [pSH0[2], pSH1[2], pSH2[2]],
            [pSH0[3], pSH1[3], pSH2[3]],
        ]);

    }

    computeA55(R) {

        let A55n0R = math.multiply(R, this.#A55n0)._data;
        let A55n1R = math.multiply(R, this.#A55n1)._data;
        let A55n2R = math.multiply(R, this.#A55n2)._data;
        let A55n3R = math.multiply(R, this.#A55n3)._data;
        let A55n4R = math.multiply(R, this.#A55n4)._data;

        let pSH0 = SHEval(...A55n0R, 3);
        let pSH1 = SHEval(...A55n1R, 3);
        let pSH2 = SHEval(...A55n2R, 3);
        let pSH3 = SHEval(...A55n3R, 3);
        let pSH4 = SHEval(...A55n4R, 3);

        return math.matrix([
            [pSH0[4], pSH1[4], pSH2[4], pSH3[4], pSH4[4]],
            [pSH0[5], pSH1[5], pSH2[5], pSH3[5], pSH4[5]],
            [pSH0[6], pSH1[6], pSH2[6], pSH3[6], pSH4[6]],
            [pSH0[7], pSH1[7], pSH2[7], pSH3[7], pSH4[7]],
            [pSH0[8], pSH1[8], pSH2[8], pSH3[8], pSH4[8]]
        ]);

    }

    applyM(M33, M55, p) {

        let p13 = math.multiply(M33, [p[1], p[2], p[3]])._data;
        let p48 = math.multiply(M55, [p[4], p[5], p[6], p[7], p[8]])._data;
        
        return [p[0], ...p13, ...p48];

    }

    getRotationPrecomputeL(precomputeLRGB, cameraModelMatrix) {

        let R = math.matrix([...cameraModelMatrix]);
        R = math.reshape(R, [4, 4]);
        R = math.subset(R, math.index([0, 1, 2], [0, 1, 2]));
        R = math.transpose(R);
        
        let A33 = this.computeA33(R);
        let A55 = this.computeA55(R);
        
        let M33 = math.multiply(A33, this.#A33);
        let M55 = math.multiply(A55, this.#A55);

        let precomputedLR = precomputeLRGB.map(item => { return item[0]; });
        let precomputedLG = precomputeLRGB.map(item => { return item[1]; });
        let precomputedLB = precomputeLRGB.map(item => { return item[2]; });
        
        return [
            this.applyM(M33, M55, precomputedLR),
            this.applyM(M33, M55, precomputedLG),
            this.applyM(M33, M55, precomputedLB)
        ];

    }

    render() {

        const gl = this.gl;

        gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
        gl.clearDepth(1.0); // Clear everything
        gl.enable(gl.DEPTH_TEST); // Enable depth testing
        gl.depthFunc(gl.LEQUAL); // Near things obscure far things

        console.assert(this.lights.length != 0, "No light");
        console.assert(this.lights.length == 1, "Multiple lights");

        const timer = Date.now() * 0.0001;

        // Fast Spherical Harmonic Rotation
        let cameraModelMatrix = mat4.create();
        mat4.fromRotation(cameraModelMatrix, timer, [0, 1, 0]);
        let precomputeLRGBMat3 = this.getRotationPrecomputeL(precomputeL[guiParams.envmapId], cameraModelMatrix);
        
        for (let l = 0; l < this.lights.length; l++) {
            // Draw light
            this.lights[l].meshRender.mesh.transform.translate = this.lights[l].entity.lightPos;
            this.lights[l].meshRender.draw(this.camera);

            // Shadow pass
            if (this.lights[l].entity.hasShadowMap == true) {
                for (let i = 0; i < this.shadowMeshes.length; i++) {
                    this.shadowMeshes[i].draw(this.camera);
                }
            }

            // Camera pass
            for (let i = 0; i < this.meshes.length; i++) {
                this.gl.useProgram(this.meshes[i].shader.program.glShaderProgram);
                this.gl.uniform3fv(this.meshes[i].shader.program.uniforms.uLightPos, this.lights[l].entity.lightPos);
                
                for (let k in this.meshes[i].material.uniforms) {

                    if (k == 'uMoveWithCamera') { // The rotation of the skybox
                        gl.uniformMatrix4fv(
                            this.meshes[i].shader.program.uniforms[k],
                            false,
                            cameraModelMatrix);
                    }
                    
                    if (k == 'uPrecomputedLR') {
                        this.meshes[i].material.uniforms[k].value.set(
                            precomputeLRGBMat3[0]
                        );
                    }
                    if (k == 'uPrecomputedLG') {
                        this.meshes[i].material.uniforms[k].value.set(
                            precomputeLRGBMat3[1]
                        );
                    }
                    if (k == 'uPrecomputedLB') {
                        this.meshes[i].material.uniforms[k].value.set(
                            precomputeLRGBMat3[2]
                        );
                    }
                }

                this.meshes[i].draw(this.camera);
            }
        }

    }
}