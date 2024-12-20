## 模板测试
实现stencil mirror的效果，只有从镜子里才能看到镜中景色，在镜子周围还有非镜内物体，他们也许在镜子前方，也许在镜子后方。为了避免镜子后方的外部物体在镜内显示，给镜子里的物体添加一个天空球，并设置天空球的深度检测总是通过，这样就会把镜中外部物体剔除，需要注意渲染顺序。

1. 参数设置

模板缓冲区的值默认为0，可以设置为其他id。

Comp表示什么情况下模板测试通过，可以设置大于等于或其他。

Pass表示通过模板测试后模板缓冲区的值怎么处理，是替换还是保持原来的值。

Fail front代表如果检测失败怎么办。

Zfail front是说如果模板测试通过，但是深度测试失败怎么办？是否要修改模板缓冲区的值。

2. 实际操作

镜子是一个看不见的平面物体，不需要颜色写入，调整镜子shader设置colormask为0，关闭深度写入，并且开启模板检测。

关于镜子的模板检测设置：
```
Stencil
{
    Ref[_Refid]
    Comp always //模板测试总是通过
    Pass replace //修改模板缓冲区的值
    //其余保持不变 Fail keep   Zfail keep
}
```

关于场景内物体的模板检测设置，在这里不需要修改模板缓冲区的值，只用进行模板测试：
```
Stencil
{
    Ref[_Refid]
    Comp equal //此时相等才能显示
    //Pass replace //这里默认是keep 对于场景物体来说我们不需要修改模板缓冲区的值
    //其余保持不变 Fail keep   Zfail keep
}
```
但此时，若存在一个镜子外的物体在镜子的后方会发现通过镜子依旧能看到镜外物体，这时候设置一个大的球体（包裹镜内所有物体）作为天空球，遮挡镜外物体的显示。

关于天空球的设置，因为我们要遮挡镜外物体的显示，因此天空球的渲染顺序要在镜外物体的后面，设置深度检测总是通过（这一步就遮盖了镜子里的镜外物体）：
```
ZTest always
Stencil{
    Ref[_Refid]
    Comp equal //此时相等才能显示
}
```

为了镜子/镜子内物体/镜子外的物体能够正确显示，不受遮挡。

渲染顺序应为：

>镜子外物体>镜子(关闭深度写入)>镜中天空球(深度测试总是通过)>镜子内物体

镜子shader设置为总是通过模板测试，镜子内的物体设置为等于模板缓冲区的值才可以通过测试。

此外，若实现cube每个面看到的内容不同，可以为每个面设置一个蒙版遮罩，一个蒙版对应一个物体。
