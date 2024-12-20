//halflambert+phong
Shader "Banshader/BasicFramework/Lambert"
{
    Properties
    {
        _maincolor("Color",Color)  = (1.0,1.0,1.0,1.0)
        _Spec("Specular mi",Range(2,100)) = 10
        _Speccol("Specular color",Color) = (1.0,1.0,1.0,1.0)
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

			#include "Lighting.cginc"
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 Ndirws : TEXCOORD1;
                float3 vertexWS: TEXCOORD2;
            };


            fixed4 _maincolor;
            float _Spec;
            fixed4 _Speccol;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.Ndirws =mul(v.normal,(float3x3)unity_WorldToObject);//矩阵右乘
                o.vertexWS = mul(unity_ObjectToWorld,v.vertex);//矩阵左乘
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;//环境光的实现
                //兰伯特是ndotl
                float3 normalDir = normalize(i.Ndirws);
                float3 lightpos = normalize(_WorldSpaceLightPos0.xyz);
                float3 vdirws =normalize( _WorldSpaceCameraPos.xyz - i.vertexWS.xyz); //这里忘了要normalize了,并且这里要的是顶点的世界坐标
                float3 rdirws = reflect(-lightpos,normalDir);//这里需要注意的是是lightpos的反方向

                float ndotl = dot(lightpos,normalDir);//lambert  n dot l
                float rdotv = dot(rdirws,vdirws);//phong  r dot v  dot的值会存在负值，必须要max处理
                fixed3 lambert = (ndotl*0.5+0.5)*_maincolor.rgb * _LightColor0.rgb;//半兰伯特实现
                //phong模型是dot（r,v），观察方向点乘反射方向
                float3 phong = _Speccol.rgb* pow(max(0,rdotv),_Spec) * _LightColor0.rgb;
                fixed3 finalcol = lambert + phong +ambient;
                return fixed4(finalcol,1.0);
            }
            ENDCG
        }
    }
    FallBack "Transparent/Cutout/VertexLit" //虽然没写阴影，但可以调用阴影
}
