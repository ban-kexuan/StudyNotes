//在flag的基础上增加了平滑处理
Shader "Banshader/Effets/Flag1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Grdient ("Graddient", 2D) = "white" {}
        _cutoff ("cutoff" ,Range(0,1)) = 0.1
        _ChangeAmount("ChangeAmount" ,Range(-1,1)) = 0.1
        _edgewidth("Edgewwidth",Range(0.1,2))=1.5
        _edgecolor("edgecolor",Color) = (1.0,1.0,1.0,1.0)
        _edgeenitisy("edge enitisy",float) = 2.0
        _smoothness ("smoothness",Range(0,0.5)) = 0.1
    }
    SubShader
    {
        Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="Opaque"}
        LOD 100
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
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Grdient;
            float4 _Gradient_ST;
            float _cutoff;
            float _ChangeAmount;
            float _edgewidth;
            fixed4 _edgecolor;
            float _edgeenitisy;
            float _smoothness;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed3 gradcol = tex2D(_Grdient,i.uv).rgb;
                float b = gradcol.r - _ChangeAmount;
                float al = col.a * b;//是不是应该先
                //al = step(0.5,al);
                float al2 = smoothstep(_smoothness, 0.5, al);
                clip (al2 - _cutoff);//但是现在想让它全部显现，因此可以引入changeamount
                //计算当前的灰度值与0.5的距离，当前的灰度值是b  目前要做的是燃烧部分会有一条线，发光，现在的目的是求出这条线
                float xian = distance(al,_smoothness);
                xian = max(0,1-xian/_edgewidth);
                fixed3 final = lerp(col.rgb,_edgecolor*_edgeenitisy,xian);
                return fixed4(final,1);
            }
            ENDCG
        }
    }
}
