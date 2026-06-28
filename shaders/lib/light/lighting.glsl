#ifndef LIB_LIGHT_LIGHTING
#define LIB_LIGHT_LIGHTING

#include "lighting_util.glsl"

float calcLambert(vec3 viewNormal, vec3 lightDir, vec3 viewDir, vec3 ambientLight)
{
    float lambert = dot(viewNormal, lightDir);
    #ifndef GROUNDCOVER
        lambert = max(lambert, 0.0);
    #else
        float eyeCosine = dot(viewNormal, viewDir);
        if (lambert < 0.0)
        {
            lambert = -lambert;
            eyeCosine = -eyeCosine;
        }
        lambert *= clamp(-8.0 * (1.0 - 0.3) * eyeCosine + 1.0, 0.3, 1.0);
    #endif
    float luma = 0.2126 * ambientLight.r + 0.7152 * ambientLight.g + 0.0722 * ambientLight.b;
    float diffuse = 0.3 * smoothstep(0.04 * luma, 0.06 * luma, lambert) + 0.35 * smoothstep(0.29 * luma, 0.31 * luma, lambert) + 0.35 * smoothstep(0.64 * luma, 0.66 * luma, lambert);
    return diffuse;
}

float calcSpecIntensity(vec3 viewNormal, vec3 viewDir, float shininess, vec3 lightDir)
{
    if (dot(viewNormal, lightDir) > 0.0)
    {
        vec3 halfVec = normalize(lightDir - viewDir);
        float specAngle = max(dot(viewNormal, halfVec), 0.0);
        float specReflection = pow(specAngle, shininess);
        return specReflection * smoothstep(0.49, 0.51, specReflection);
    }
    return 0.0;
}

#if PER_PIXEL_LIGHTING
    void doLighting(vec3 viewPos, vec3 viewNormal, float shininess, float shadowing, out vec3 diffuseLight, out vec3 ambientLight, out vec3 specularLight)
#else
    void doLighting(vec3 viewPos, vec3 viewNormal, float shininess, out vec3 diffuseLight, out vec3 ambientLight, out vec3 specularLight, out vec3 shadowDiffuse, out vec3 shadowSpecular)
#endif
{
    vec3 viewDir = normalize(viewPos);
    shininess = max(shininess, 1e-4);

    vec3 sunDir = normalize(lcalcPosition(0));
    ambientLight = gl_LightModel.ambient.xyz;
    diffuseLight = lcalcDiffuse(0) * calcLambert(viewNormal, sunDir, viewDir, ambientLight);
    specularLight = lcalcSpecular(0).xyz * calcSpecIntensity(viewNormal, viewDir, shininess, sunDir);

    #if PER_PIXEL_LIGHTING
        diffuseLight *= shadowing;
        specularLight *= shadowing;
    #else
        shadowDiffuse = diffuseLight;
        shadowSpecular = specularLight;
        diffuseLight = vec3(0.0);
        specularLight = vec3(0.0);
    #endif

    for (int i = @startLight; i < PointLightCount; ++i)
    {
    #if @lightingMethodUBO
        int lightIndex = PointLightIndex[i];
    #else
        int lightIndex = i;
    #endif
        vec3 lightPos = lcalcPosition(lightIndex) - viewPos;
        float lightDistance = length(lightPos);

    // cull point lighting by radius, light is guaranteed to not fall outside this bound with our cutoff
    #if !@classicFalloff
        if (lightDistance > lcalcRadius(lightIndex) * 2.0)
            continue;
    #endif

        vec3 lightDir = lightPos / lightDistance;

        float illumination = lcalcIllumination(lightIndex, lightDistance);
        ambientLight += lcalcAmbient(lightIndex) * illumination;
        diffuseLight += lcalcDiffuse(lightIndex) * calcLambert(viewNormal, lightDir, viewDir, ambientLight) * illumination;
        specularLight += lcalcSpecular(lightIndex).xyz * calcSpecIntensity(viewNormal, viewDir, shininess, lightDir) * illumination;
    }
}

#endif
