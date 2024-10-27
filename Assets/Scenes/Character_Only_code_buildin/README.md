# Character移动端角色渲染分析
整个光照模型的框架分为四个部分，这里的lambert和blin-phong都可以改为PBR光照。
1. 直接光漫反射：Lambert+sss
2. 直接光的镜面反射：Blin-Phong + KK各向异性
3. 间接光漫反射：SH
4. 间接光镜面反射：IBL

## 服装模型：
整个人物的模型贴图都在一张里，由于贴图有金属的部分，也有非金属的部分，因此，需要通过mental贴图来区分金属与非金属。对于金属来说，是没有漫反射的，只有镜面反射，并且，镜面反射的颜色是金属的颜色本身。储存金属度信息的通道是这样的，黑色是皮肤，值为1的部分是金属，其余是介于金属与皮肤之间的一种材质。
![mental](https://github.com/ban-kexuan/StudyNotes/tree/master/Assets/NotePic/Character/mental.png)
```
half4 comp = tex2D(_CompMask, i.uv);
fixed metal = comp.g; //根据金属度决定  
metal = saturate(metal + _MetalAdjust); 
fixed3 base_color = albedo_color.rgb * (1-metal);//得到非金属的固有色
fixed3 spec_color = lerp(0.01,albedo_color,metal);//得到金属高光颜色
```
通过采样得到金属的高光颜色和非金属的固有色。

下面开始逐步实现每个光照框架

对于非金属的部分我们需要实现:
1.	直接光漫反射
2.	直接光镜面反射
3.	间接光漫反射
4.	间接光镜面反射

对于金属部分我们需要实现:
1.	直接光镜面反射
2.	间接光镜面反射

### 一、直接光漫反射
使用兰伯特计算基础色，颜色分为四个部分，要注意灯光的颜色和衰减。
```
half3 D_diffuse = NdotL * _LightColor0.xyz * atten * base_color;
```
这里还增加了皮肤的SSS效果，这里只是简单采用了ramp贴图进行采样，uv的计算还考虑了阴影部分。
```
half2 uv2 = half2(halflambert *atten + _rampoffset ,_rampcontrol);
fixed3 sss = tex2D(_RampTex, uv2).rgb;
```

### 二、直接光镜面反射
采用Blinn-phong模型，使用Roughness贴作为高光参数控制，这里考虑了皮肤的油光，对皮肤和金属进行颜色区分。
half3 spec_qu = lerp(spec_color,0.1,skin);
half3 Direct_specular = pow(NdotH,shinesness* smoothness) * spec_qu  *_LightColor0.xyz * LIGHT_ATTENUATION(i);

### 三、间接光漫反射
间接光的漫反射使用二阶球谐函数
```
float3 custom_sh(float3 normalDir)
{
    float4 normalForSH = float4(normalDir, 1.0);
    //SHEvalLinearL0L1
    half3 x;
    x.r = dot(custom_SHAr, normalForSH);
    x.g = dot(custom_SHAg, normalForSH);
    x.b = dot(custom_SHAb, normalForSH);

    //SHEvalLinearL2
    half3 x1, x2;
    // 4 of the quadratic (L2) polynomials
    half4 vB = normalForSH.xyzz * normalForSH.yzzx;
    x1.r = dot(custom_SHBr, vB);
    x1.g = dot(custom_SHBg, vB);
    x1.b = dot(custom_SHBb, vB);

    // Final (5th) quadratic (L2) polynomial
    half vC = normalForSH.x*normalForSH.x - normalForSH.y*normalForSH.y;
    x2 = custom_SHC.rgb * vC;

    float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
    sh = pow(sh, 1.0 / 2.2);
    return sh;
}
```
### 四、间接光镜面反射IBL
在Cubmap中选择Specular，我们就能得到IBL信息，通过粗糙度与mip级数相乘来采样不同粗糙度下的环境贴图。
```
half4 color_cubemap = texCUBElod(_CubeMap, float4(reflectDir, mip_level));
half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);//确保在移动端能拿到HDR信息
half3 env_specular = env_color  * _Expose * spec_color * halflambert;//高光颜色
```
最后将四个颜色相加得到最终的服装效果。

## 头发的渲染：
头发最终的部分在于各向异性高光的模拟，最常用的kajiya各向异性高光。
 
#### Kajiya-kay经验着色模型：
光照模型 = 环境光 + 漫反射 + 各向异性高光
 
将头发抽象化一个不透明的圆柱体，不能够透射和内部反射。

光照分为diffuse+Specular

Diffuse采用Lamber，specular使用Phong，

Diffuse = Kd sin(T,L); T为切线，

Specular = Kd sin(T,H)Specularity

这里采用切线或副切线的原因不用normal的原因在于法线是一个点，而我们希望一根头发的整个截面。
由于这个方法不是基于物理的，因此不能模拟光纤可能穿过 头发或者在头发中传播的情况，这就导致了其不能模拟出背光以及二次高光的效果。

#### Marschner：【等后续用了再回来补充】
另一个应用广泛的头发着色模型。
该模型将头发抽象为一个透明的椭圆柱体:

- R Path：光线到达头发纤维角质层直接被反射。
- TRT Path：光线透过角质层进入皮层，角质层内层折射，又透射到空气中，可以知道，出射点距离入射点以及发生了偏移。
- TT Path：光线透射进入皮层，又从中直接透射出去。
因此S方程可以写为：S=SR+STT+STRT

#### Scheuermann Shading Model
在kajiya的基础上引入了Marschner的双层高光思想，一层是没有颜色的用来模拟油脂层，一层是有颜色的用来模拟底部色素层，两层高光互相错开，因为实际上头发就是有两层高光，他们之间要有对应的偏移 ，方法是沿法线方向偏移切线，即在原有切线的基础上再加上乘上偏移因子的N得到偏移后的T_shifted

以上是头发的渲染方法，下面对移动端的角色的头发进行模拟，考虑了直接光漫反射，直接光高光，漫反射高光，由于头发材质是会比皮肤反射率更强点，重点在于反射。

**一、	直接光的漫反射 与服装类似：**

half3 D_diffuse = halflambert * _LightColor0.xyz * atten * basecolor.rgb;
这里头发由于是亮色，加了阴影压暗了一些。

**二、直接光高光：**

这里采用Scheuermann方法，在kajiya基础上修改了一些计算方法。

首先确定高光的颜色，将副切线的方向进行偏移扰动，关于是将切线进行扰动还是副切线进行扰动要看哪个方向与UV的U同方向。需要注意的是，这里的NdotB, TdotH, BdotH都不能取大于0的值，因为各向异性有正有负，允许一些方向的贡献为负。这里的aniso_noise来自采样的发丝灰度图。

第一道高光的计算:
```
 half3 Spec_color1 = _SpecColor1.rgb + basecolor.rgb;
float3 aniso_offset1 = normalDir *(aniso_noise * _ShiftNoise1 + _ShiftOffset1);//朝着法线方向做扰动
float3 bitanoffset1 = normalize(bitanDir + aniso_offset1);
//这里最关键的一步是不能用max！！！！
half BdotH1 = dot(bitanoffset1,halfDir) / _Shineness1;//还除了一个光滑度
//采用了于kajiya不同的计算方式
float3 spec_term1 = exp(-(TdotH * TdotH + BdotH1 *BdotH1)/(1.0 + NdotH));
float3 final_Specu = spec_term1 * aniso_atten * Spec_color1 * _LightColor0.rgb;//颜色值*衰减
```
第二道高光与第一道一样，只是用不同的参数进行控制，最后将两道高光进行叠加。

**三、间接光镜面反射：**

采用IBL的方式，与服装不同之处在于不用乘spec_color，但需要乘aniso_noise，让整个镜面反射与发丝的noise融合。
