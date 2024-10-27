Shader "Ban/SH"
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
            float4 _AO_ST;
            float _AO_adjust;
            float4 _Tint;
            float _Expose;
            float _NormalIntensity;

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

                float ao = tex2D(_AO,i.uv).r;
                ao = lerp(1,ao,_AO_adjust);//去调整ao的效果，可以看出，如果aojust是0显示1，这时候没有立体感
               

                //float3 envcolor = DecodeHDR(cubecol,_CubeMap_HDR);//移动端得到HDR的方法
                float3 envcolor = ShadeSH9(float4(normalDir,1.0));//用了七个参数？
                half3 finalcol = envcolor *ao * _Expose * _Tint.rgb * _Tint.rgb;

                return float4(finalcol,1.0);
            }
            ENDCG
        }
    }
}
