Shader "Ban/SSS/Candle" {
   Properties {
		_basemap("Base Map",2D) = "white"{}
		_DiffuseColor("Diffuse Color",Color) = (0,0.352,0.219,1)
		_AddColor("Add Color",Color) = (0,0.352,0.219,1)
		_Opacity("Opacity",Range(0,1)) = 0
		_ThicknessMap("Thickness Map",2D) = "black"{}
		_NormalMap("Normal Map",2D) = "bump"{}
		[Header(BasePass)]
		_BasePassDistortion("Bass Pass Distortion", Range(0,1)) = 0.2
		_BasePassColor("BasePass Color",Color) = (1,1,1,1)
		_BasePassPower("BasePass Power",float) = 1
		_BasePassScale("BasePass Scale",float) = 2
		
		[Header(AddPass)]
		_AddPassDistortion("Add Pass Distortion", Range(0,1)) = 0.2
		_AddPassColor("AddPass Color",Color) = (0.56,0.647,0.509,1)
		_AddPassPower("AddPass Power",float) = 1
		_AddPassScale("AddPass Scale",float) = 1

		[Header(EnvReflect)]
		_EnvRotate("Env Rotate",Range(0,360)) = 0
		_EnvMap ("Env Map", Cube) = "white" {}
		_FresnelMin("Fresnel Min",Range(-2,2)) = 0
		_FresnelMax("Fresnel Max",Range(-2,2)) = 1
		_EnvIntensity("Env Intensity",float) = 1.0
   }
   SubShader {
		Pass {	
		Tags { "LightMode" = "ForwardBase" } 
		CGPROGRAM
 
		#pragma vertex vert  
		#pragma fragment frag 
		#pragma multi_compile_fwdbase
		#include "UnityCG.cginc"
		#include "AutoLight.cginc"

		sampler2D _ThicknessMap;
		sampler2D _NormalMap;
		sampler2D _basemap;
		float4 _basemap_ST;
		float4 _DiffuseColor;
		float4 _AddColor;
		float _Opacity;

		float4 _BasePassColor;
		float _BasePassDistortion;
		float _BasePassPower;
		float _BasePassScale;

 		samplerCUBE _EnvMap;
		float4 _EnvMap_HDR;
		float _EnvRotate;
		float _EnvIntensity;
		float _FresnelMin;
		float _FresnelMax;

		float4 _LightColor0;
 
		struct appdata {
			float4 vertex : POSITION;
			float2 texcoord : TEXCOORD0;
			float3 normal : NORMAL;
			float4 tangentOS : TANGENT;
		};
		struct v2f {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float4 posWorld : TEXCOORD1;
			float3 normalDir : TEXCOORD2;
			float3 tangentWS   : TEXCOORD5; // 世界空间的切线方向
    		float3 bitangentWS : TEXCOORD6;
		};

        v2f vert(appdata v) 
        {
			v2f o;
			o.posWorld = mul(unity_ObjectToWorld, v.vertex);
			o.normalDir = UnityObjectToWorldNormal(v.normal);
            o.posWorld = mul(unity_ObjectToWorld, v.vertex);
			o.uv = v.texcoord;
			o.pos = UnityObjectToClipPos(v.vertex);
			half3 viewDirWS = normalize(_WorldSpaceCameraPos - o.posWorld.xyz);
			o.tangentWS.xyz = normalize(mul(unity_ObjectToWorld,float4(v.tangentOS.xyz,0.0)).xyz);
			o.bitangentWS.xyz = normalize(cross(o.normalDir,o.tangentWS)* v.tangentOS.w);

			return o;
        }
 
        float4 frag(v2f i) : COLOR
        {
			float3x3 t2w = float3x3(i.tangentWS.xyz, i.bitangentWS.xyz, i.normalDir.xyz);
			float3 nor = UnpackNormal(tex2D(_NormalMap, i.uv));
			float3 normalDir = normalize(mul(nor, t2w));
			//info
			float3 basecolor = tex2D(_basemap, i.uv).rgb;
			float3 diffuse_color = _DiffuseColor * basecolor;
			//float3 normalDir = normalize(i.normalDir);
			float3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);
			float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);//平行光

			//diffuse
			float diff_term = max(0.0, dot(normalDir, lightDir));
			float3 diffuselight_color = diff_term * diffuse_color * _LightColor0.rgb; //顶点光源强度信息

			float sky_sphere = (dot(normalDir,float3(0,1,0)) + 1.0) * 0.5;
			float3 sky_light = sky_sphere * diffuse_color;
			float3 final_diffuse = diffuselight_color + sky_light * _Opacity + _AddColor.xyz;//addcolor补光

			//trans light
			float3 back_dir = -(lightDir + normalDir * _BasePassDistortion);
			float VdotB = max(0.0, dot(viewDir, back_dir));
			float backlight_term = max(0.0,pow(VdotB, _BasePassPower)) * _BasePassScale;
			float thickness = 1- tex2D(_ThicknessMap, i.uv).r;
			float3 backlight = backlight_term * thickness * _LightColor0.xyz * _BasePassColor.xyz;

			//ENV
			float3 reflectDir = reflect(-viewDir,normalDir);

			half theta = _EnvRotate * UNITY_PI / 180.0f;
			float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta),cos(theta));
			float2 v_rot = mul(m_rot, reflectDir.xz);
			reflectDir = half3(v_rot.x, reflectDir.y, v_rot.y);

			float4 cubemap_color = texCUBE(_EnvMap,reflectDir);
			half3 env_color = DecodeHDR(cubemap_color, _EnvMap_HDR);

			float fresnel = 1.0 - saturate(dot(normalDir, viewDir));
			fresnel = smoothstep(_FresnelMin, _FresnelMax, fresnel);

			float3 final_env = env_color * _EnvIntensity * fresnel;
			//combine
			float3 combined_color = final_diffuse + final_env + backlight;
			float3 final_color = combined_color;
			return float4(final_color,1.0);
		}
		ENDCG
		}
		Pass {	
			Tags { "LightMode" = "ForwardAdd" } 
			Blend One One 
			CGPROGRAM
 
			#pragma vertex vert  
			#pragma fragment frag 
			#pragma multi_compile_fwdadd
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			float4 _LightColor0; 
 
			float4 _DiffuseColor;
			sampler2D _ThicknessMap;
			float _AddPassDistortion;
			float _AddPassPower;
			float _AddPassScale;
			float4 _AddPassColor;

 			samplerCUBE _EnvMap;
			float _EnvIntensity;
			float _FresnelMin;
			float _FresnelMax;
 
			float3 CalculatePointLightColor (
			float4 lightPosX, float4 lightPosY, float4 lightPosZ,
			float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
			float4 lightAttenSq,
			float3 pos
			)
			{
				// to light vectors
				float4 toLightX = lightPosX - pos.x;
				float4 toLightY = lightPosY - pos.y;
				float4 toLightZ = lightPosZ - pos.z;
				// squared lengths
				float4 lengthSq = 0;
				lengthSq += toLightX * toLightX;
				lengthSq += toLightY * toLightY;
				lengthSq += toLightZ * toLightZ;
				// don't produce NaNs if some vertex position overlaps with the light
				lengthSq = max(lengthSq, 0.000001);

				float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
				// final color
				float3 col = 0;
				col += lightColor0 * atten.x;
				col += lightColor1 * atten.y;
				col += lightColor2 * atten.z;
				col += lightColor3 * atten.w;
				return col;
			}
			struct appdata {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 texcoord0 : TEXCOORD0;
			};
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 posWorld : TEXCOORD1;
				float3 normalDir : TEXCOORD2;
				float3 viewDir : TEXCOORD3;
				LIGHTING_COORDS(4,5)
			};
			v2f vert(appdata v) 
			{
				v2f o;

				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.uv = v.texcoord0;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.viewDir = UnityWorldSpaceViewDir(o.posWorld);
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}
 
			float4 frag(v2f i) : COLOR
			{
				float3 diffuse_color = _DiffuseColor * _DiffuseColor;

				float3 normalDir = normalize(i.normalDir); 
				float3 viewDir = normalize(i.viewDir);
				float NdotV = saturate(dot(normalDir,viewDir));
				//light info
				float3 lightDir = normalize(lerp(_WorldSpaceLightPos0.xyz,( _WorldSpaceLightPos0.xyz - i.posWorld.xyz),_WorldSpaceLightPos0.w));
				float attenuation = LIGHT_ATTENUATION(i);
				//trans light
				float3 back_dir = -normalize(lightDir + normalDir * _AddPassDistortion);
				float VdotB = max(0.0,dot(viewDir, back_dir));
				float backlight_term = max(0.0, pow(VdotB, _AddPassPower)) * _AddPassScale;
				float thickness = 1.0 - tex2D(_ThicknessMap, i.uv).r;
				float3 backlight = backlight_term * thickness *
					_LightColor0.xyz * _AddPassColor.xyz;

				float3 pointColor = CalculatePointLightColor(unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0,
				i.posWorld);

				//combine
				float3 final_color = backlight + pointColor;
				final_color = sqrt(final_color);
				return float4(final_color,1.0);
			}
			ENDCG
		}
	}
	FallBack "Diffuse"
}