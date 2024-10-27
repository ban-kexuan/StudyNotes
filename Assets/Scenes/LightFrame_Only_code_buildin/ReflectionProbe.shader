Shader "Unlit/ReflectProbe"
{
    Properties
    {
       // _Cubemap("Cubemap",CUBE) = "_sky"{}
        _Normalmap("normal_map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",float) = 1.0
        _AO ("AO_map",2D) = "white"{}
        _Tint ("Color ",Color) = (1,1,1,1)
        _Expose("Expose",float) = 0.5
        _Rotate("Rotate",Range(0,360)) = 0
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

           // samplerCUBE _Cubemap;

            sampler2D _Normalmap;
            float4 _Normalmap_ST;
            sampler2D _AO;
            float4 _AO_ST;
            float4 _Tint;
            float _Expose;
            float _NormalIntensity;
            float _Rotate;
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

                //float4 cubecol = texCUBE(_Cubemap,reflectDir);
                float4 cubecol =  UNITY_SAMPLE_TEXCUBE(unity_SpecCube0,reflectDir);
                half3 envcolor = DecodeHDR(cubecol,unity_SpecCube0_HDR);
                half3 finalcol = envcolor *ao * _Expose * _Tint;
                return half4(finalcol,1.0);
            }
            ENDCG
        }
    }
}
