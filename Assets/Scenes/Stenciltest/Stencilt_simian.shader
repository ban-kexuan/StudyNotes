//模板测试
Shader "Banshader/BasicFramework/Stencilt_simian"
{
    Properties
    {
        _Refid("mask id", Int) = 1
        _MainTex("maintex",2D) = "white"{}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Geometry+2"} //非透明物体的渲染顺序是2000 这里默认先渲染镜子外周围的物体，再渲染镜子模板，再渲染镜中物体
        LOD 100
        ZTest always
        //模板测试需要写在pass之前
        Stencil{
            Ref[_Refid]
            Comp equal //此时相等才能显示
            //Pass replace //这里默认是keep 对于场景物体来说我们不需要修改模板缓冲区的值
            //其余保持不变 Fail keep   Zfail keep
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 texColor = tex2D(_MainTex, i.uv);
                return texColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
