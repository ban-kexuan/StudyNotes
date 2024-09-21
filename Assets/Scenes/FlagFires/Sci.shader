//实现一个从下到上的溶解科技效果
Shader "Banshader/Effets/Sci"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Grdient ("Graddient", 2D) = "white" {}
        _ramp ("Ramp", 2D) = "white" {}
        _cutoff ("cutoff" ,Range(0,1)) = 0.1
        _ChangeAmount("ChangeAmount" ,Range(-1,1)) = 0.1
        _edgewidth("Edgewwidth",Range(0.1,2))=1.5
        _edgecolor("edgecolor",Color) = (1.0,1.0,1.0,1.0)
        _edgeenitisy("edge enitisy",float) = 2.0
        _smoothness ("smoothness",Range(0,0.5)) = 0.1
        _NoiseTex ("NoiseTex",2D) = "white"{}
        _TimeSpeed("Timespeed",float) = 1.2
        _spread ("spread",Range(0,1)) = 0.2
    }
    SubShader
    {
        Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="Opaque"}
        LOD 100
        cull off
        //Zwrite off
        //Blend SrcAlpha OneMinusSrcAlpha
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
                float2 uv1:texcoord2;
                float3 posWS: texcoord3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Grdient;
            float4 _Gradient_ST;
            sampler2D _ramp;
            float4 _ramp_ST;
            float _cutoff;
            float _ChangeAmount;
            float _edgewidth;
            fixed4 _edgecolor;
            float _edgeenitisy;
            float _smoothness;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float _TimeSpeed;
            float _spread;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.posWS =  mul(unity_ObjectToWorld,v.vertex).xyz;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                float3 center = mul(unity_ObjectToWorld , float4(0,-1,0,1)).xyz;
                fixed3 gradcol= i.posWS-center;
                float len = clamp(length(gradcol),0,1);
                //fixed3 gradcol = tex2D(_Grdient,i.uv).rgb;//采样一个灰度图
                fixed3 noise= tex2D(_NoiseTex,i.uv).rgb;//noise贴图

                //可以用自动循环播放代替changeamount
                float x = frac(_Time.y * _TimeSpeed);
                x = x*2-1;
                float b = len  - x;
                b = b/_spread;
                b = b-noise.r;
                float c = smoothstep(_smoothness,0.5,b);
                float al = col.a * c;
                clip (al - _cutoff);//但是现在想让它全部显现，因此可以引入changeamount
                //计算当前的灰度值与0.5的距离，当前的灰度值是b  目前要做的是燃烧部分会有一条线，发光，现在的目的是求出这条线
                float xian = distance(b,_smoothness); //溶解边缘的衰减范围
                xian = max(0,1-xian/_edgewidth);

                fixed3 ramp= tex2D(_ramp,float2(1-xian,0.5)).rgb;
                fixed3 final = lerp(col.rgb,col.rgb*_edgecolor*_edgeenitisy,xian);
                return fixed4(final,1);
            }
            ENDCG
        }
    }
}
