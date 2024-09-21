Shader "Banshader/NPR/Face"
{
    Properties
    {
        //漫反射（阶梯状的动态阴影）+高光+边缘光+内外描边
        _MainTex("MainTex", 2D) = "White" { }
        _SDFTex ("SDFTexture" , 2D) = "White"{}
        _MainColor("BaseColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _DarkColor ("DarkColor" , Color) = (0,0,1,0)//阴影颜色
        _BrightColor ("BrightColor" , Color) = (1,1,1,1)//高光颜色
        _EmissColor ("EmissionColor" , Color) = (1,1,1,1)
        _OutlineColor ("OutLineColor" , Color) = (0,0,0,0)
        _OutlineWidth ("OutlineWidth" , Range(0 , 10)) = 1
        _RimOffect ("_RimOffect" , Range(-0.3 , 0.3)) = 0.2//边缘光
        _Threshold ("Threshold" , Range(0 , 1)) = 0.5
        _RimColor ("RimColor" , Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RanderPipline" = "UniversalPipeline"
            "RanderType" = "Opaque" }
        LOD 100

        Pass
        {
            Name "Diffusecolor"
            Tags {"Lightmode" = "UniversalForward"}
            Cull back //背面剔除

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //#include "Assets/Shaders/PBRShader/Include/Common.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _MainColor;
                half4 _DarkColor;
                half4 _BrightColor;
                half4 _EmissColor;
                half4 _OutlineColor;
                half _OutlineWidth;
                float _RimOffect;
                float _Threshold;
                float4 _RimColor;
            CBUFFER_END
           
        ENDHLSL

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
                #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
                #pragma multi_compile _ _SHADOWS_SOFT 

                struct appdata
                {
                    float4 pos : POSITION;
                    float2 uv : TEXCOORD0;
                    half4 Color : COLOR;
                    float3 normal : NORMAL;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 posCS : SV_POSITION;
                    float3 normalWS : TEXCOORD1;
                    half4 vertColor : TEXCOORD2;
                    float3 posWS : TEXCOORD3;
                    float4 shadowCoord : TEXCOORD4;
                    half3 forwardWS   : TEXCOORD5;
                    float4 centerSCS : TEXCOORD6;
                    float clipWS       : TEXCOORD7;
                    float4 screenPos  : TEXCOORD8;
                };

                TEXTURE2D (_MainTex);
                SAMPLER(sampler_MainTex);     
                TEXTURE2D (_SDFTex);
                SAMPLER (sampler_SDFTex);

                v2f vert (appdata v)
                {
                    const VertexPositionInputs vertexInput = GetVertexPositionInputs(v.pos.xyz);
                    v2f o;
                    o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                    o.posCS = vertexInput.positionCS;
                    o.vertColor = v.Color;
                    o.posWS = TransformObjectToWorld(v.pos.xyz);
                    o.shadowCoord = TransformWorldToShadowCoord(float4(o.posWS,1));
                    half3 centerWS = TransformObjectToWorld(float3(0,0,0.6));
                    o.centerSCS = TransformWorldToShadowCoord(centerWS);
                    o.forwardWS = TransformObjectToWorldDir(float3(0,0,1));//前向
                    o.screenPos = ComputeScreenPos(o.posCS);
                    o.normalWS = TransformObjectToWorldNormal(v.normal);
                    return o;
                }

                half4 frag(v2f input) : SV_Target
                {
                    float3 normalWS = normalize(input.normalWS);
                    float3 viewWS = normalize( _WorldSpaceCameraPos - input.posWS);
                    Light mainLight = GetMainLight(input.shadowCoord);
                    float2 screenPos = input.screenPos.xy / input.screenPos.w; //屏幕空间的坐标 
                    //SDF
                    half LR = cross(input.forwardWS , mainLight.direction).y; //根据叉乘可以判断是左边脸还是右边脸
                    half ndv = saturate(dot(viewWS , normalWS));
                    half2 ndir = normalize(input.forwardWS.xz);
                    half2 ldir = normalize(-mainLight.direction.xz);
                    half ndl = saturate(dot(ndir , ldir));
                    float2 flipUV = float2(1 - input.uv.x, input.uv.y);
                    half sdf = 0;
                    half sdfL = SAMPLE_TEXTURE2D(_SDFTex , sampler_SDFTex , input.uv);
                    half sdfR = SAMPLE_TEXTURE2D(_SDFTex , sampler_SDFTex , flipUV);
                    half isL = step(LR , 0);//Lr大于0，返回0；反之返回1
                    sdf = lerp(sdfR , sdfL , isL);//LR大于0，isL等于0，说明说明是右边
                    sdf = step(ndl , sdf);//这里是为什么呢？
                    //half ramp = SAMPLE_TEXTURE2D(_RampTex , sampler_RampTex , float2(1 - sdf , 0.5)).r;                   
                    half4 baseTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _MainColor;
                    half3 darkColor = baseTex.rgb * _DarkColor.rgb;
                    float shadow = max(MainLightRealtimeShadow(input.centerSCS) , 0.5);
                     //SSRIM
                    half rimIntensity = step(0.5 ,pow((1 - ndv) , 3)); //菲涅尔 非得涅尔得到的是一个强度
                    half3 rimCol = rimIntensity * _RimColor.rgb * baseTex.rgb;
                    half3 mixCol = lerp(darkColor , baseTex.rgb ,  sdf * shadow) + _EmissColor.rgb * baseTex.rgb + rimCol;
                    return half4(mixCol , 1) ;
                }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            //描边
            Name "OutLine"
            Tags {"LightMode"="SRPDefaultUnlit"}
            Cull Front //正面剔除
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //#include "Assets/Shaders/PBRShader/Include/Common.hlsl"

        ENDHLSL
         
            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                struct v
                {
                    float4 positionOS : POSITION;
                    float2 uv         : TEXCOORD0;
                    float3 normal     : NORMAL;
                    float4 tangent    : TANGENT;
                };

                struct v2
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv         : TEXCOORD0;
                };

                TEXTURE2D (_MainTex);
                SAMPLER(sampler_MainTex);

                v2 vert(v input)
                {
                    /*
                    v2 output;
                    float3 posWS = TransformObjectToWorld(input.positionOS.xyz);

                    float3 normalWS = TransformObjectToWorldNormal(input.normal);
                    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);
                    float3 posVS = TransformWorldToView(posWS);
                    posVS.xyz += normalVS * _OutlineWidth * 0.1;
                    output.positionCS = TransformViewToHClip(posVS);*/
                    v2 output;
                    float4 scaledScreenParams = GetScaledScreenParams();
                    float ScaleX = abs(scaledScreenParams.x / scaledScreenParams.y);
                    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                    half3 normalWS = TransformObjectToWorldNormal(input.tangent.xyz);
                    float4 pos = TransformObjectToHClip(input.positionOS.xyz);
                    float3 normalCS = TransformWorldToHClipDir(normalWS);
                    //在屏幕空间下完成的
                    float2 extendDis = normalize(normalCS.xy) *(_OutlineWidth*0.01);
                    extendDis.x /=ScaleX ;
                    pos.xy += extendDis * pos.w ;
                    output.positionCS = pos;          
                    return output;
                }

                half4 frag(v2 input) : SV_Target
                {                  
                    half4 baseTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _MainColor;
                    half4 finalCol = half4(_OutlineColor.rgb * baseTex.rgb , 1);
                    return finalCol;
                }
            
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}
