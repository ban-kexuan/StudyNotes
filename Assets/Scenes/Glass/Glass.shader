Shader "Ban/Glass"
{
    //反射（cubemap/matcap）+折射+透明度
    Properties
    {
        _Matcap ("MatCap", 2D) = "white" {}
        _Matcap2 ("MatCap2", 2D) = "white" {}
        _Thickness ("ThicknessTex", 2D) = "white" {}
        _fractionmin("Fraction min",Range(0,1)) =0.1
        _fractionmax("Fraction max",Range(0,1)) =0.5
        _fractionIntensity("Fraction Intensity",float) = 1.0
        _bottleColor ("Bottle Color", Color) = (1,1,1,1)
        _ColorIntensity("Color Intensity",float) = 1.0
        _WaterDirty("WaterDirty",2D) = "black"{}
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline"
			"Queue"="Transparent"  "RenderType"="Transparent"}
        LOD 100
        
        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            
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
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normalWS:TEXCOORD1;
                float3 normalVS: TEXCOORD2;
                float3 PosWS :TEXCOORD3;
            };

            sampler2D _Matcap;
            float4 _Matcap_ST;
            sampler2D _Matcap2;
            float4 _Matcap2_ST;
            sampler2D _Thickness;
            float4 _Thickness_ST;
            sampler2D _WaterDirty;
            float4 _WaterDirty_ST;
            float _fractionmin;
            float _fractionmax;
            float _fractionIntensity;
            fixed4 _bottleColor;
            float _ColorIntensity;
            v2f vert (appdata v)
            {
                //matcap要拿到view空间下的法线
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.PosWS = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv = v.uv;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.normalVS =  mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 norvs = normalize(i.normalVS.xyz);

                fixed2 matuv = norvs.xy*0.5+0.5;
                //matcap的新uv
                //得到view空间下的顶点位置并做归一化
  
                float thickness = tex2D(_Thickness,i.uv*_Thickness_ST.xy+_Thickness_ST.zw).r;
                float3 posVS = normalize(mul(UNITY_MATRIX_V,float4(i.PosWS,1.0)).xyz);
                //是要把观察空间下的顶点坐标和法线做叉乘
                float3 cha = normalize(cross(posVS,norvs));
                float2 matuv2 =cha.xy;
                matuv2.x = -cha.y;
                matuv2.y = cha.x;
                matuv2 = matuv2.xy*0.5+0.5;
                fixed4 col = tex2D(_Matcap, matuv);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.PosWS.xyz);
                //折射效果，还是采用matcap只是uv加偏移
                //对于有厚度的地方用菲涅尔，没有厚度的地方用其他方法来代替
                float ndotv = dot(normalize(i.normalWS),viewDir);
                float fresnel = 1- smoothstep(_fractionmin,_fractionmax,ndotv);
                float dirty = tex2D(_WaterDirty,i.uv*_WaterDirty_ST.xy+_WaterDirty_ST.zw).a;
                fresnel = fresnel+thickness+dirty;
                float fresnel2 = fresnel*_fractionIntensity;

                float2 matuv3 = matuv2 + fresnel2;
                fixed4 col2 = tex2D(_Matcap2, matuv);

                fixed3 Colormix = lerp(_bottleColor.rgb*0.5,col2.rgb*_bottleColor.rgb,fresnel2);

                fixed3 final = clamp(col.rgb*_bottleColor*_ColorIntensity+Colormix.rgb,0,1);
                return fixed4(final.rgb,clamp(max(col.r,fresnel),0,1));
            }
            ENDCG
        }
    }
    Fallback "Universal Render Pipeline/Lit"
}
