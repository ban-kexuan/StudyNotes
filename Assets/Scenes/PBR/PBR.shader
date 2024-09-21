Shader "Banshader/PBR"
{
    Properties
    {
        //首先需要明确的几个贴图 basecolor，高光，金属度，粗糙度，AO，法线，环境光贴图cubemap,自发光
        _BaseMap("Albedo", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BaseColor("Color", Color) = (1,1,1,1)
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _GlossScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}
        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline"  "RenderType"="Opaque" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True"}
        LOD 100

        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma multi_compile_fwdbase
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            
            #pragma multi_compile _ _EMISSIONGROUP_ON
            #pragma shader_feature _CUSTOM_REFL_CUBE_ON

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            SAMPLER(sampler_MainTex);
            TEXTURE2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _DiffuseColor;
            SAMPLER(sampler_SpecularTex);
            TEXTURE2D _SpecularTex;
            fixed3 _SpecularColor;
            SAMPLER(sampler_MetallicTex);
            TEXTURE2D _MetallicTex;
            half _Metallic;
            SAMPLER(sampler_RoughnessTex);            
            TEXTURE2D _RoughnessTex;
            half _Roughness;
            SAMPLER(sampler_AOTex);
            TEXTURE2D _AOTex;
            half _AoPower;
            SAMPLER(sampler_EmissionTex);           
            TEXTURE2D _EmissionTex;
            fixed3 _EmissionColor;
            SAMPLER(sampler_IrradianceCubemap);
            SAMPLER(sampler_CustomReflectTex);
            TEXTURECUBE _IrradianceCubemap;
            TEXTURECUBE _CustomReflectTex;
            half4 _CustomReflectTex_HDR;

            TEXTURE2D _NormalTex;
            SAMPLER(sampler_NormalTex);
            fixed _NormalScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                return col;
            }
            ENDHLSL
        }
    }
}
