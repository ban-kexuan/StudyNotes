//模板测试
Shader "Banshader/BasicFramework/Stencilt"
{
    Properties
    {
        _Refid("mask id", Int) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue" = "Geometry+1"} //非透明物体的渲染顺序是2000 这里默认先渲染镜子外周围的物体，避免遮挡出现问题

        ColorMask 0 //不写入颜色缓冲区
        //模板测试需要写在pass之前
        ZWrite off
        Stencil{
            Ref[_Refid]
            Comp always
            Pass replace //这里默认是keep 我们需要修改模板缓冲区的值
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(1,1,1,1);
            }
            ENDCG
        }
    }
}
