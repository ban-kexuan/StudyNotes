Shader "Ban/Character"
{
    Properties
    {
        _BaseMap ("base map", 2D) = "white" {}
        _CompMask ("comp mask(RM)", 2D) = "white" {}
        _RampTex ("Ramp Texture" , 2D) = "white"{}
        _rampcontrol("Ramp control",Range(0,1)) =0.5
        _rampoffset("Ramp offset",float)=0 
        _RoughnessAdjust("Roughness Adjust", Range(-1,1)) = 0

        _MetalAdjust("Metal Adjust", Range(-1,1)) = 0
        _Normalmap("normal_map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",float) = 1.0
        _Shineness ("Shineness",float) = 1.0
        _specIntensity ("Specular Intensity" , float) = 0.5
        [Header(Env Specular)]
        _CubeMap("Cube Map",Cube) = "white"{}
        _Tint("Tint",Color) = (1,1,1,1)
		_Expose("Expose",Float) = 1.0
		_Rotate("Rotate",Range(0,360)) = 0
        
        [Toggle(_DIFFUSECHECK_ON)] _Diffusecheck("DiffuseCheck",float) = 0.0
        [HideInInspector]custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode" = "ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma shader_feature _DIFFUSECHECK_ON
            #include "AutoLight.cginc"
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normalWS: TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 BitangentWS : TEXCOORD4;
                LIGHTING_COORDS(5,6)

            };

            sampler2D _BaseMap;
            float4 _BaseMap_ST;
            sampler2D _CompMask; 
            sampler2D _Normalmap;
            sampler2D _RampTex;
            samplerCUBE _CubeMap;
			float4 _CubeMap_HDR;
			float4 _Tint;
            float _rampcontrol;
			float _Expose;
            float _Rotate;
            float _NormalIntensity;
            float4 _LightColor0;
            float _Shineness;
            float _specIntensity;
            float _RoughnessAdjust;
            float _MetalAdjust;
            half4 custom_SHAr;
			half4 custom_SHAg;
			half4 custom_SHAb;
			half4 custom_SHBr;
			half4 custom_SHBg;
			half4 custom_SHBb;
			half4 custom_SHC;
            float _rampoffset;

            float3 custom_sh(float3 normalDir)
            {
                float4 normalForSH = float4(normalDir, 1.0);
				//SHEvalLinearL0L1
				half3 x;
				x.r = dot(custom_SHAr, normalForSH);
				x.g = dot(custom_SHAg, normalForSH);
				x.b = dot(custom_SHAb, normalForSH);

				//SHEvalLinearL2
				half3 x1, x2;
				// 4 of the quadratic (L2) polynomials
				half4 vB = normalForSH.xyzz * normalForSH.yzzx;
				x1.r = dot(custom_SHBr, vB);
				x1.g = dot(custom_SHBg, vB);
				x1.b = dot(custom_SHBb, vB);

				// Final (5th) quadratic (L2) polynomial
				half vC = normalForSH.x*normalForSH.x - normalForSH.y*normalForSH.y;
				x2 = custom_SHC.rgb * vC;

				float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
				sh = pow(sh, 1.0 / 2.2);
                return sh;
            }

            inline float3 ACES_Tonemapping(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				float3 encode_color = saturate((x*(a*x + b)) / (x*(c*x + d) + e));
				return encode_color;
			}
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_BaseMap);
                o.normalWS = normalize(mul(float4(v.normal,0.0),unity_WorldToObject));
                o.posWS = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.tangentWS = normalize(mul(unity_ObjectToWorld,v.tangent).xyz);
                o.BitangentWS = normalize(cross(o.normalWS,o.tangentWS))* v.tangent.w;
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                fixed4 albedo_color = tex2D(_BaseMap, i.uv);
               // fixed4 albedo_color = pow(basecolor_gamma,2.2);
                half4 comp = tex2D(_CompMask, i.uv);
                fixed Roughness= comp.r;
                Roughness = saturate(Roughness + _RoughnessAdjust);
                fixed metal = comp.g; //根据金属度决定  
                metal = saturate(metal + _MetalAdjust); 
                fixed3 base_color = albedo_color.rgb * (1-metal);//得到非金属的固有色
                fixed3 spec_color = lerp(0.01,albedo_color,metal);//得到金属高光颜色

                float3 normalDir = normalize(i.normalWS);
                float3 normalTex = UnpackNormal(tex2D(_Normalmap,i.uv));
                normalTex.xy = normalTex.xy * _NormalIntensity;
                float3 tanDir = normalize(i.tangentWS);
                float3 bitanDir = normalize(i.BitangentWS);
                float3x3 TBN = float3x3(tanDir,bitanDir,normalDir);
                normalDir = normalize(mul(normalTex.rgb, TBN));
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.posWS.xyz);
                float3 reflectDir = reflect(-viewDir,normalDir);
                float3 LightDir = normalize(_WorldSpaceLightPos0.xyz);

    
                //lambert直接光漫反射
                half NdotL = max(0.0,dot(normalDir,LightDir));
                half halflambert = (NdotL+1.0 ) * 0.5;
                half skin = 1- comp.b;
                half atten = LIGHT_ATTENUATION(i);
                half2 uv2 = half2(halflambert *atten + _rampoffset ,_rampcontrol);
                fixed3 sss = tex2D(_RampTex, uv2).rgb;
                half3 sss_diffuse = sss * _LightColor0.xyz * halflambert  * base_color;
                half3 D_diffuse = NdotL * _LightColor0.xyz 
                                * atten* base_color;
                #ifdef _DIFFUSECHECK_ON
                half3 Direct_diffuse = lerp(D_diffuse,sss_diffuse,skin);
                #else
                half3 Direct_diffuse = half3(0,0,0);
                #endif

                //直接光高光
                float3 halfDir = normalize(LightDir+viewDir);
                half NdotH = max(0,dot(normalDir,halfDir));
                fixed smoothness = 1-Roughness;
                half shinesness = lerp(1,_Shineness,smoothness);
                half3 spec_skin = lerp(spec_color,0.1,skin);
                half3 Direct_specular = pow(NdotH,shinesness* smoothness) * spec_skin  
                            *_LightColor0.xyz * LIGHT_ATTENUATION(i);

                //阴影不用乘在间接光，因为间接光是用来提亮我们的暗部的
                //间接光漫反射 使用SH
                //球谐函数
                half3 env_diffuse = custom_sh(normalDir) * base_color *halflambert;

                //间接光镜面反射 IBL
				Roughness = Roughness * (1.7 - 0.7 * Roughness);
				float mip_level = Roughness * 6.0;

				half4 color_cubemap = texCUBElod(_CubeMap, float4(reflectDir, mip_level));
				half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);//确保在移动端能拿到HDR信息
				half3 env_specular = env_color  * _Expose * spec_color * halflambert;//高光颜色


                half3 final_color = Direct_diffuse + Direct_specular +env_diffuse *0.8 + env_specular;
                //final_color = pow(final_color,1.0/2.2);
                final_color = ACES_Tonemapping(final_color);
                return half4(final_color,1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
