class PRTMaterial extends Material {

    constructor(vertexShader, fragmentShader) {

        super({
            uPrecomputedLR: { type: 'matrix3fv', value: new Float32Array(9) },
            uPrecomputedLG: { type: 'matrix3fv', value: new Float32Array(9) },
            uPrecomputedLB: { type: 'matrix3fv', value: new Float32Array(9)},
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);

    }

}

async function buildPRTMaterial(vertexPath, fragmentPath) {

    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new PRTMaterial(vertexShader, fragmentShader);

}