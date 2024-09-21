# 旗帜燃烧：
有很多溶解算法：
总的思路是透明度检测，小于阈值直接剔除。
1.	需要有一张梯度图和物体maintex。用一个ChangeAmount来控制溶解过程。将梯度值与changeamount相减，使用step严格控制，小于0.5返回0，由于物体本身的贴图也是具有透明度的，因此再乘maintex的a通道。
``` 
float b = gradientcol.r - _ChangeAmount;
float c = step(0.5,b);
float al = col.a * c;
clip (al - _cutoff); //不满足直接剔除
```

对于颜色部分，效果是渐变的，燃烧边缘是具有燃烧色彩的。因此用前面得到的差值b计算与0.5的距离，以此得到溶解边缘的衰减范围（是满巧妙的方法）。可以再增加溶解边宽度进一步控制。最终的颜色使用lerp插值 ，距0.5的近距离越小说明约接近燃烧部分，颜色约接近燃烧色彩。
```
fixed3 final = lerp(col.rgb,_edgecolor*_edgeenitisy , _distance);
```

2.	对上面的方法进一步扩充，燃烧锯齿或许太锋利，可以增加smoothness面板参数，使用smoothstep代替step对边缘进行软化。
```
float c = smoothstep(_smoothness,0.5,b);
```
3.	对于想要按照顺序比如从上到下或从下到上溶解，可以给一个水平or垂直方向的梯度图，再使用一个noise贴图进行扰动。使用一个ramp贴图进一步对燃烧色彩细化。
