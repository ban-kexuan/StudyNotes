Shader "Ban/Hair"
{
    Properties
    {
        _BaseMap ("base map", 2D) = "white" {}
        _Normalmap("normal_map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",float) = 1.0

        [Header(Specular)]

        _ShiftMap("Shift Map",2D) = "gray"{}
        _SpecColor1("Specular Color",Color) = (1,1,1,1)
        _Shineness1 ("Shineness",Range(0,1)) = 1.0 //光滑度
        _ShiftOffset1("Shift Offset",float) = 1
        _ShiftNoise1("Shift Noise",float) = 1

        _Shineness2 ("Shineness2",Range(0,1)) = 1.0 //光滑度
        _ShiftOffset2("Shift Offset2",float) = 1
        _SpecColor2("Specular Color2",Color) = (1,1,1,1)
        _ShiftNoise2("Shift Noise2",float) = 1

        _CubeMap("Cube Map",Cube) = "white"{}
		_Expose("Expose",Float) = 1.0
        _Roughness ("Roughness", Range(0,1)) = 0.5
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
            
            sampler2D _Normalmap;

            sampler2D _ShiftMap;
            float4 _ShiftMap_ST;
            float _Shineness1;
            float _ShiftOffset1;
            float3 _SpecColor1;
            float _ShiftNoise1;
            float _Shineness2;
            float _ShiftOffset2;
            float3 _SpecColor2;
            float _ShiftNoise2;


            samplerCUBE _CubeMap;
			float4 _CubeMap_HDR;
            float _Expose;
            float _NormalIntensity;
            float4 _LightColor0;
            float _Shineness;
            float _specIntensity;
            float _ShiftOffset;
            float _ShiftIntensity;
            float _Roughness;

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
                o.uv = v.uv;
                o.normalWS = normalize(mul(float4(v.normal,0.0),unity_WorldToObject));
                o.posWS = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.tangentWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.BitangentWS = normalize(cross(o.normalWS,o.tangentWS))* v.tangent.w;
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                fixed3 basecolor = tex2D(_BaseMap, i.uv).rgb;   
                float3 normalDir = normalize(i.normalWS);
                float3 tanDir = normalize(i.tangentWS);
                float3 bitanDir = normalize(i.BitangentWS);
                float3x3 TBN = float3x3(tanDir,bitanDir,normalDir);
                float3 normalTex = UnpackNormal(tex2D(_Normalmap,i.uv));
                normalDir = normalize(tanDir * normalTex.x
					+ bitanDir * normalTex.y + normalDir * normalTex.z);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 reflectDir = reflect(-viewDir,normalDir);
                float3 LightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                //lambert直接光漫反射
                half NdotL = max(0.0,dot(normalDir,LightDir));
                half halflambert = (NdotL+1.0 ) * 0.5;    
                half atten = LIGHT_ATTENUATION(i);
                half3 D_diffuse = halflambert * _LightColor0.xyz * atten * basecolor.rgb;
                
                //直接光高光 sin(Hdot
                float3 halfDir = normalize(LightDir + viewDir);
                half2 uv_noise = i.uv* _ShiftMap_ST.xy + _ShiftMap_ST.zw;
                half aniso_noise = tex2D(_ShiftMap,uv_noise).r;//想让他从-1，1
                aniso_noise  = aniso_noise -0.5;//也可以直接减去0.5
                //bitanDir = normalize(bitanDir + normalDir * (aniso_noise+_ShiftOffset));
                half NdotH = dot(normalDir,halfDir);
                half TdotH = dot(halfDir,tanDir);

                //计算一个衰减范围,有一个弧形的衰减
                half NdotV = max(0.0,dot(viewDir,normalDir));
                float aniso_atten = saturate(sqrt(max(0.0,halflambert / NdotV)))* atten;
                //第一道高光的颜色值
                half3 Spec_color1 = _SpecColor1.rgb + basecolor.rgb;
                float3 aniso_offset1 = normalDir *(aniso_noise * _ShiftNoise1 + _ShiftOffset1);//朝着法线方向做扰动
                float3 bitanoffset1 = normalize(bitanDir + aniso_offset1);
                //这里最关键的一步是不能用max！！！！
                half BdotH1 = dot(bitanoffset1,halfDir) / _Shineness1;//还除了一个光滑度
                //采用了于kajiya不同的计算方式
                float3 spec_term1 = exp(-(TdotH * TdotH + BdotH1 *BdotH1)/(1.0 + NdotH));
                //half3 Direct_specular = pow(sinTH,_Shineness)*_LightColor0.xyz * atten *_specIntensity;
                float3 final_Specu = spec_term1 * aniso_atten * Spec_color1 * _LightColor0.rgb;//颜色值*衰减


                //第二道高光
                half3 Spec_color2 = _SpecColor2.rgb + basecolor.rgb;
                float3 aniso_offset2 = normalDir *(aniso_noise * _ShiftNoise2 + _ShiftOffset2);//朝着法线方向做扰动
                float3 bitanoffset2 = normalize(bitanDir + aniso_offset2);
                //这里最关键的一步是不能用max！！！！
                half BdotH2 = dot(bitanoffset2,halfDir) / _Shineness2;//还除了一个光滑度
                //采用了于kajiya不同的计算方式
                float3 spec_term2 = exp(-(TdotH * TdotH + BdotH2 *BdotH2)/(1.0 + NdotH));
                //half3 Direct_specular = pow(sinTH,_Shineness)*_LightColor0.xyz * atten *_specIntensity;
                float3 final_Specu2 = spec_term2 * aniso_atten * Spec_color2 * _LightColor0.rgb;//颜色值*衰减

                float3 final_specolall = final_Specu+final_Specu2;

                 //间接光镜面反射 IBL
				float mip_level = _Roughness * 6.0;

				half4 color_cubemap = texCUBElod(_CubeMap, float4(reflectDir, mip_level));
				half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);//确保在移动端能拿到HDR信息
				half3 env_specular = env_color  * _Expose  * halflambert *aniso_noise;//高光颜色
                half3 final_color = D_diffuse + final_specolall +env_specular;
                final_color = ACES_Tonemapping(final_color);
                return half4(final_color,1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
