### 扫光
总的思路：自发光（边缘光）+流光

自发光的计算：使用菲涅尔光边缘光加模型本身贴图的r通道相加，这样既有边缘光又增加一定的模型细节。

1.	先用菲涅尔计算边缘光，菲涅尔是 1-ndotv，可以使用smoothstep在给定的边缘光强度范围内插值。之后的菲涅尔可以用来做透明度。
2.	自发光的颜色分为两个部分，一个是内光颜色，一个是边缘光颜色，使用菲涅尔+Basemap.r平滑过渡。

**流光的计算方法：用一个随时间变动的uv来采样流光贴图。**

要有一个可以控制流光的tilling，用世界空间下的顶点位置减去模型中心的世界坐标，这样使流光看起来不会因为模型的形状或放置位置而发生不自然的偏移，这样流光会跟随模型而变动。 因此采样uv可以用二者的插值xy方向乘tilling。此外我们还需要一个可以控制运动的面板参数_speed。最后的流动uv计算方法：
```
half2 uv_flow = (i.posWS.xy - i.pivot_world.xy) * _FloweFilling.xy;
uv_flow.xy = uv_flow + _Time.y  * _Speed.xy;
```
之后用这个uv来采样流光贴图就好。

最终的颜色：自发光+流光，透明度是得到的菲涅尔+模型细节值。

这里需要注意的是：因为整体是透明物体的渲染，因此可以看到模型的背面，整个表现会比较混乱。这个时候使用提前深度写入的透明度检测方法。对于第一个pass只开启深度写入，但不写入颜色缓冲区。对于第二个pass就进行正常的透明物体渲染，关闭深度写入。
（对于urp项目还是使用urp管线来写shader吧，不然渲染透明物体会出现很多不报错的错误。
