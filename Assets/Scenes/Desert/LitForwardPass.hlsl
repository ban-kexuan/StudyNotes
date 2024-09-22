#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/Shaders/PBRShader/Include/Common.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

    float3 positionWS               : TEXCOORD2;


    float3 normalWS                 : TEXCOORD3;
#ifdef _NORMALMAP
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS                : TEXCOORD5;

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD7;
#endif
    float3 posOS                    : TEXCOORD8;
    float4 positionCS               : TEXCOORD9;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct DomainOut  //曲面细分的结构体
{
    float4 positionCS:SV_POSITION;  
    float3 posOS : TEXCOORD0;
    float2 uv    : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
    float3 normalWS : TEXCOORD4;
#ifdef _NORMALMAP
    float4 tangentWS : TEXCOORD5;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS : TEXCOORD6;

    half4 fogFactorAndVertexLight : TEXCOORD7; // x: fogFactor, yzw: vertex light
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD8;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(DomainOut input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    inputData.positionWS = input.positionWS;
#endif

    half3 viewDirWS = SafeNormalize(input.viewDirWS);
#ifdef _NORMALMAP
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    float3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    output.viewDirWS = viewDirWS;
#ifdef _NORMALMAP
    real sign = input.tangentOS.w * GetOddNegativeScale();
    output.tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    output.posOS = input.positionOS.xyz;
#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif
    
    //output.positionWS = worldPos;
    //vertexInput.positionWS = worldPos;
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif
    
    
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

    return output;
}


struct PatchTess //曲面细分规则配置，如何对一个三角面进行细分，需要设hi三角形各边要分成几段，以及三角形内部有几个新加的点
{
    float EdgeTess[3]:SV_TessFactor; //各边细分数
    float InsideTess:SV_InsideTessFactor; //内部细分点系数
};
PatchTess ConstantHS(InputPatch<Varyings,3> patch,uint patchID:SV_PrimitiveID)//具体怎么分
{
    PatchTess pt;
    pt.EdgeTess[0]=_Tesselation; //第一条边的的细分段数
    pt.EdgeTess[1]=_Tesselation; //第二条边的细分段数
    pt.EdgeTess[2]=_Tesselation; //第三条边的细分段数
    pt.InsideTess=_Tesselation;  //内部细分点系数
    return pt;
                
}
            
            
struct HullOut
{
    float3 posOS : TEXCOORD0;
    float2 uv    : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
    float3 normalWS : TEXCOORD4;
#ifdef _NORMALMAP
    float4 tangentWS : TEXCOORD5;    // xyz: tangent, w: sign
#endif
    float3 viewDirWS : TEXCOORD6;

    half4 fogFactorAndVertexLight : TEXCOORD7; // x: fogFactor, yzw: vertex light
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD8;
#endif
    float4 positionCS               : TEXCOORD9;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

//计算插值权重，这是不可编程的，这里是得到每个顶点的插值权重，真正的混合需要我们在下一个阶段手动计算 
            
[domain("tri")] //图元类型，三角面片
[partitioning("integer")] // 曲面细分的过度方式是整数还是小数，这里是整数
[outputtopology("triangle_cw")] //三角面正方向是顺时针还是逆时针，这里是顺时针
[outputcontrolpoints(3)] //输出的控制点数
[patchconstantfunc("ConstantHS")] //对之前的细分规则配置阶段的方法名
[maxtessfactor(64.0f)] //最大可能的细分段数


HullOut HS(InputPatch<Varyings,3> p,uint i:SV_OutputControlPointID) //对原模型，获取各种参数
{
    HullOut hout;
   
   
    hout.uv = p[i].uv;
    hout.positionWS = p[i].positionWS;
    hout.normalWS = p[i].normalWS;
    OUTPUT_LIGHTMAP_UV(p[i].lightmapUV, unity_LightmapST, hout.lightmapUV);
    hout.vertexSH = p[i].vertexSH;
    half fogFactor = ComputeFogFactor(p[i].positionCS.z);
    half3 vertexLight = VertexLighting(p[i].positionWS, p[i].normalWS);
#ifdef _NORMALMAP
    hout.tangentWS = p[i].tangentWS;    // xyz: tangent, w: sign
#endif
    hout.viewDirWS = p[i].viewDirWS;
    hout.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    hout.shadowCoord = TransformWorldToShadowCoord(float4(p[i].positionWS , 1));
#endif 
   
    hout.posOS=p[i].posOS;
    hout.positionCS = p[i].positionCS;
    return hout;
}
            



[domain("tri")] //细分着色器的最后一步，这一步的方法相当于顶点着色器，这里的顶点是做过细分处理的。
DomainOut DS(PatchTess patchTess,float3 baryCoords:SV_DomainLocation,const OutputPatch<HullOut,3> triangles)
{
    DomainOut dout;
    //这里的uv，positionWS，posOS都是在做权重混合
    dout.uv = triangles[0].uv * baryCoords.x + triangles[1].uv * baryCoords.y + triangles[2].uv * baryCoords.z;   
    float width = _OrthographicCameraSize;
    float3 wordPos = triangles[0].positionWS * baryCoords.x + triangles[1].positionWS * baryCoords.y + triangles[2].positionWS * baryCoords.z;   
    float2 uv = (wordPos.xz - _OrthographicCameraPos.xz) / (width * 2) + float2(0.5 , 0.5);
    //获取高度图
    half2 heightTex = SAMPLE_TEXTURE2D_LOD(_PathRT , sampler_PathRT , uv , 0).rg;
    half pathNoise = (SAMPLE_TEXTURE2D_LOD(_PathNoiseTexture , sampler_PathNoiseTexture , dout.uv *_PathNoiseTexture_ST.xy + _PathNoiseTexture_ST.zw , 0).r) * _NoiseInt;
    dout.normalWS = triangles[0].normalWS * baryCoords.x + triangles[1].normalWS * baryCoords.y + triangles[2].normalWS * baryCoords.z;
    float3 OffsetDir = normalize(dout.normalWS);
    float3 ObjOffsetDir = TransformWorldToObjectDir(OffsetDir);
    float OffsetInt = _HeightScale *(heightTex.g * pathNoise  - heightTex.r * _DownInt) / 100000; 
    float3 OffsetObjVert = ObjOffsetDir * OffsetInt;
    float3 OffsetWorldVert = OffsetDir * OffsetInt;
    //做顶点偏移
    dout.positionWS = (triangles[0].positionWS + OffsetWorldVert) * baryCoords.x + (triangles[1].positionWS + OffsetWorldVert)* baryCoords.y + (triangles[2].positionWS + OffsetWorldVert) * baryCoords.z;
    dout.posOS = (triangles[0].posOS + OffsetObjVert) * baryCoords.x + (triangles[1].posOS + OffsetObjVert) * baryCoords.y + (triangles[2].posOS + OffsetObjVert) * baryCoords.z;
    //float3 p = TransformWorldToObject(dout.positionWS);
    
#ifdef _NORMALMAP
    dout.tangentWS = triangles[0].tangentWS * baryCoords.x + triangles[1].tangentWS * baryCoords.y + triangles[2].tangentWS * baryCoords.z;
#endif
    dout.viewDirWS = triangles[0].viewDirWS * baryCoords.x + triangles[1].viewDirWS * baryCoords.y + triangles[2].viewDirWS * baryCoords.z;
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    dout.shadowCoord = triangles[0].shadowCoord * baryCoords.x + triangles[1].shadowCoord * baryCoords.y + triangles[2].shadowCoord * baryCoords.z;
#endif    
    dout.positionCS=TransformObjectToHClip(dout.posOS.xyz);
    half3 vertexLight = VertexLighting(dout.positionWS, dout.normalWS);
    half fogFactor = ComputeFogFactor(dout.positionCS.z);
    dout.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    return dout;
}



// Used in Standard (Physically Based) shader
half4 LitPassFragment(DomainOut input) : SV_Target
{
    //这里只是针对高度和法线改变渲染时的顶点位置，实际的模型却没有改变
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    MySurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    half ndv = saturate(dot(inputData.normalWS , inputData.viewDirectionWS));
    surfaceData.emission *= saturate(pow(ndv , _EmissionPow)).xxx;
    Light mainLight = GetMainLight(inputData.shadowCoord);

    half pathNoise = (SAMPLE_TEXTURE2D(_PathNoiseTexture , sampler_PathNoiseTexture , input.uv *_PathNoiseTexture_ST.xy + _PathNoiseTexture_ST.zw).r) * _NoiseInt;
    //计算高度 计算与正交相机的相对位置，获取UV坐标
    float width = _OrthographicCameraSize;
    float2 uv = (inputData.positionWS.xz - _OrthographicCameraPos.xz) / (width * 2) + float2(0.5 , 0.5);
    half4 heightTex = SAMPLE_TEXTURE2D(_PathRT , sampler_PathRT ,  uv ); //获取高度信息
    float height = (heightTex.r * _DownInt - heightTex.g * pathNoise) * _PathNormalScale; //这里的rgb都代表不一样的值吗，结合噪声

    surfaceData.emission *= (1-heightTex.a) * mainLight.shadowAttenuation;
    inputData.normalWS = NormalFromHeight(height , inputData.normalWS , inputData.positionWS.xyz); //把得到的高度转为法线，因为顶点偏移后法线并没有改变，为了正确的灯光效果，这是必要的。
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
    half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);
    float2 smokeDir = normalize(_SmokeVector.xy);
    float tX = frac(_Time.g * _SmokeVector.z * _SmokeVector.x);
    float tY = frac(_Time.g * _SmokeVector.w * _SmokeVector.y);
    float2 speed = float2(tX,tY);
    half smokeMask = SAMPLE_TEXTURE2D(_SmokeMaskTex , sampler_SmokeMaskTex , input.uv * _SmokeMaskTex_ST.xy).r;
    half smoke = SAMPLE_TEXTURE2D(_SmokeNoiseTex , sampler_SmokeNoiseTex , (input.uv + speed) * _SmokeNoiseTex_ST.xy).r;
    color.rgb = lerp(_SmokeColor.rgb * mainLight.shadowAttenuation , color.rgb, saturate(smoke + (1 - _SmokeColor.a) + smokeMask) );
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);
    return color;
}

#endif
