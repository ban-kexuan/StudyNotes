# 次表面散射:
次表面散射= BRDF+BTDF 


既有透射又有规则和不规则反射。可以用光线追踪来实现，但是一般实时游戏都是快速次表面散射。

构成可以概括为 背光+扰动+扩散; 
```
BackIntensity = saturate(V· -(L+N+distortion)p) * s //p为指数
```
BSSRDF更多关注光源和相机在物体同一侧时光源打入介质的晕染效果；BTDF则更多关注物体间隔在相机和光源中间，光线透射物体的效果。
背光颜色 = 灯光衰减值*( BackIntensity +ambient )*thickness, 透射距离的计算方法有两种。

#### 厚度图模拟 

对于一些简单的物体也可以用gradient图来近似，substance painter也可以烘焙厚度图。不过烘焙出的效果薄的地方为黑色，因此要用1-thickness来乘backcolor。（在使用sp导出厚度图时，选择模板mesh map才会有thickness选项）

#### 通过深度来模拟厚度
在 [冰的模拟](https://www.163.com/dy/article/J503NGTE0526E124.html) 中，使用的是求射线相交物体的厚度函数。
```
// t = -b ± sqrt(b^2 - c)
void IntersectionShere(float3 rayOrigin, float3 rayDirection, float3 position, float radius,
out float frontDist, out float backDist, out float thickness)
{
    float3 oc = rayOrigin - position;//起始点就是摄像机，终点是球心
    float b = dot(oc, rayDirection);//观察方向 点乘 摄像机到球心
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    h = sqrt(h);
    
    frontDist = -b - h;
    backDist = -b + h;
    thickness = h * 2.0;
}
```
其主要功能是确定从给定的光线起点（rayOrigin）和方向（rayDirection）出发，是否与一个球体相交，并计算出相交的厚度（thickness）

这类快速次表面散射的方法可以实现树叶、蜡烛、玉等。
但是树叶有一些不一样，树叶每个面的法线可能指向任意地方，看起来会很杂乱，并且不是想要的那样最外层的树叶有透射效果。

因此，采用顶点position来做，向量从中心指向四周，看起来像个球体（也可以在DCC中修改法线）。显然，下面的效果更符合预期，再根据向量的长度做衰减。

![这里写图片描述](https://github.com/ban-kexuan/StudyNotes/blob/master/Assets/NotePic/SSS-tree.png)

蜡烛的SSS和玉石的类似，在这里记录一下蜡烛火苗的做法：
采用Substance designer做出一个火苗效果，整个流程较简单，主要运用的节点是directional warp，方向变形，根据内焰外焰做出三层效果混合。

![这里写图片描述](https://github.com/ban-kexuan/StudyNotes/blob/master/Assets/NotePic/SSS-firesd.png)
![这里写图片描述](https://github.com/ban-kexuan/StudyNotes/blob/master/Assets/NotePic/SSS-blend.png)

Shader流程如下：
![这里写图片描述](https://github.com/ban-kexuan/StudyNotes/blob/master/Assets/NotePic/SSS-fire.png)

对水的法线贴图进行采样（使用panner增加时间和速度的采样动画），对其xy值与uv相加得到火焰贴图采样的新uv。 勾选Billboard使火焰面片使用面向相机。

参考链接：

https://blog.csdn.net/coldbluer/article/details/138170142

https://www.youtube.com/watch?v=gA9Dt5o-c_s&t=4s

https://www.youtube.com/watch?v=uBb1F02peto

https://www.163.com/dy/article/J503NGTE0526E124.html

