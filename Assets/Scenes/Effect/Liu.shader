Shader "Banshader/Effects/Liu"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FlowTex ("FlowTexture", 2D) = "white" {}
        _rimColor ("Rim Color",Color) = (1.0,1.0,1.0,1.0)
        _innerColor ("innner Color",Color) = (1.0,1.0,1.0,1.0)
        _rimintensity("Rim Intensity",float) = 0.2
        _rimmin("Rim Min",Range(-1,1)) = 0.0
        _rimmax("Rim Max",Range(0,2)) = 1.0
        _FloweFilling("Flow Filling",Vector) = (1,1,0,0)
        _Speed("Flow speed",Vector) = (1,1,0,0)   
        _FlowIntensity("Flow intensity",float) = 0.3       
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
       
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline"
			"Queue"="Transparent" "IngoreProjector"="True" "RenderType"="Transparent"
  }
       
        LOD 100
        Pass
        {
            
            ZWrite On //打开深度缓存
            ColorMask 0
        }
        Pass
        {
            
			Tags {"LightMode"="UniversalForward"}

            ZWrite Off
            Blend SrcAlpha One

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal :NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normalWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 pivot_world : TEXCOORD3;
            };

            SAMPLER(sampler_MainTex);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_FlowTex);
            TEXTURE2D(_FlowTex);

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _FlowTex_ST;
            half4 _rimColor;
            float _rimintensity;
            float _rimmin;
            float _rimmax;
            half4 _innerColor;
            float4 _Speed;
            float4 _FloweFilling;
            float _FlowIntensity;
            float _AlphaScale;
        CBUFFER_END

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                o.posWS = mul(UNITY_MATRIX_M,v.vertex);
                o.normalWS =TransformObjectToWorldNormal(v.normal);//矩阵右乘
                o.pivot_world = mul(UNITY_MATRIX_M,float4(0.0,0.0,0.0,1.0));//模型原点
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //计算一个边缘光
                half3 normDir = normalize(i.normalWS);
                //菲涅尔计算边缘光，ndotv
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                half ndotv = saturate(dot(normDir,viewDir));
                half fresnel = 1-ndotv;
                fresnel = smoothstep(_rimmin,_rimmax,fresnel);
                half col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv).r;
                col = pow(col,5.0);

                half final = saturate(fresnel+col);//菲涅尔+自发光
                half3 rim_color = lerp(_innerColor,_rimColor*_rimintensity,final);

                //流光的计算
                half2 uv_flow = (i.posWS.xy - i.pivot_world.xy) * _FloweFilling.xy;
                uv_flow.xy = uv_flow + _Time.y  * _Speed.xy;
                float4 flow_col = SAMPLE_TEXTURE2D(_FlowTex,sampler_FlowTex,uv_flow) * _FlowIntensity;
                
                float3 final_col = rim_color + flow_col.rgb;
                float aalpha = saturate(fresnel+_AlphaScale);
                return half4(final_col,fresnel); 
            }
            ENDHLSL
        }
    }
    FallBack "Univeral Render Pipeline/Simple Lit"
}
