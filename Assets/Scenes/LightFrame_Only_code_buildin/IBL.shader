Shader "Ban/IBL"
{
    Properties
    {
        _Cubemap("Cubemap",CUBE) = "_sky"{}
        _Normalmap("normal_map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",float) = 1.0
        _AO ("AO_map",2D) = "white"{}
        _AO_adjust("ao_adjust",Range(0,1)) = 0.5
        _Tint ("Color ",Color) = (1,1,1,1)
        _Expose("Expose",float) = 0.5
        _Rotate("Rotate",Range(0,360)) = 0
        _Roughness ("Roughness",Range(0,1)) = 0.5
        _RoughnessMap("RoughnessMap",2D) = "black"{}
        _RoughnessContrast("Roughness Contrast",Range(0,1)) = 0.2
        _RoughnessBrightness("Roughness Brightness",float) = 0.2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                float4 vertex : SV_POSITION;
                float3 normalWS: TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 BitangentWS : TEXCOORD4;
            };

            samplerCUBE _Cubemap;
            float4 _CubeMap_HDR;
            sampler2D _Normalmap;
            float4 _Normalmap_ST;
            sampler2D _AO;
            sampler2D _RoughnessMap;
            float4 _AO_ST;
            float _AO_adjust;
            float4 _Tint;
            float _Expose;
            float _NormalIntensity;
            float _Rotate;
            float _Roughness;
            float _RoughnessContrast;
            float _RoughnessBrightness;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv * _Normalmap_ST.xy + _Normalmap_ST.zw;
                o.normalWS = normalize(mul(float4(v.normal,0.0),unity_WorldToObject));
                o.posWS = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.tangentWS = normalize(mul(unity_ObjectToWorld,v.tangent).xyz);
                o.BitangentWS = normalize(cross(o.normalWS,o.tangentWS))* v.tangent.w;
                return o;
            }

            //ACES tonemapping函数
            inline float3 ACES_Tonemapping(float3 x)
            {
                float a=2.51f;
                float b= 0.03f;
                float c= 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                float3 encode_color = saturate((x*(a*x + b))/ (x*(c*x + d) + e));
                return encode_color;
            }
            half4 frag (v2f i) : SV_Target
            {
                float3 normalDir = normalize(i.normalWS);
                float3 normalTex = UnpackNormal(tex2D(_Normalmap,i.uv));
                normalTex.xy = normalTex.xy * _NormalIntensity;
                float3 tanDir = normalize(i.tangentWS);
                float3 bitanDir = normalize(i.BitangentWS);
                normalDir = normalize(tanDir *normalTex.x + bitanDir * normalTex.y + normalDir * normalTex.z);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.posWS.xyz);
                //如果要实现将cubemap水平方向旋转，需要把viewdir进行旋转。
                //构建xz平面的旋转矩阵
                float3 reflectDir = reflect(-viewDir,normalDir);

                float ri = _Rotate * UNITY_PI/180; //角度转弧度的公式
                //构建旋转矩阵
                float2x2 rotateMatrix = float2x2(cos(ri),-sin(ri),sin(ri),cos(ri));
                float2 rotateDir = mul(rotateMatrix,reflectDir.xz);
                reflectDir = float3(rotateDir.x,reflectDir.y,rotateDir.y);
                float ao = tex2D(_AO,i.uv).r;
                ao = lerp(1,ao,_AO_adjust);//去调整ao的效果，可以看出，如果aojust是0显示1，这时候没有立体感
                float roughness = tex2D(_RoughnessMap,i.uv).r;
                roughness = saturate(pow(roughness,_RoughnessContrast) * _RoughnessBrightness);//加深对比度

                float mip = roughness *6;
                float4 cubecol = texCUBElod(_Cubemap,float4(reflectDir,mip));
                //如果是用probe来采样那么
                //float4 cubecol =  UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,reflectDir,mip);

                half3 env_color = DecodeHDR(cubecol, _CubeMap_HDR);//确保在移动端能拿到HDR信息

                //float3 envcolor = DecodeHDR(cubecol,_CubeMap_HDR);//移动端得到HDR的方法
                half3 finalcol = env_color *ao * _Expose * _Tint.rgb * _Tint.rgb;
                half3 final_linear = pow(finalcol , 2.2);
                finalcol = ACES_Tonemapping(final_linear);
                half3 final_gamma = pow(finalcol, 1.0/2.2);
                return float4(final_gamma,1.0);
            }
            ENDCG
        }
    }
}
