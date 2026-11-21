# 稻生江畔

一款可离线游玩的 Windows 农业生存策略游戏。带十个人在长江边扎根，在同一片 2.5D 河谷里度过四个时代。每季有四十秒，随时可以暂停派工。

**[下载 Windows x64 试玩版](https://github.com/Imngenesis/TimeofAgriculture-AgricultureBall/raw/refs/heads/main/dist/RiceByTheRiver-Windows-x64.zip)**。解压整个压缩包，双击「稻生江畔.exe」。游戏与旁边的资源包需放在同一文件夹。

![实机中的河谷经营画面](docs/river-valley.jpg)

## 第一年

先在野粮采集地按两次「＋」派人。打开「调度」封存两份种粮，再到「农学」研习「留种试种」。研究完成后，通过「建设」在地图上选址开田。春夏播种，秋末收粮，每块收获田会给下次播种留两份种子。

| 时代 | 河谷里的抉择 |
| --- | --- |
| 原始采集 | 分配有限的野粮，在冬季口粮和来年种子之间取舍。 |
| 早期农耕 | 洪峰前修田堤保住田里的作物，或把粮种转运到高处，退水后复耕。 |
| 传统农耕 | 修梯田或实行稻豆轮作，让坡田经受梅雨冲刷。 |
| 工业与现代农业 | 平衡农机增产、尾水污染与作物疫病，确保疫后仍有收成。 |

空格控制暂停，数字 1、2、3 对应一倍、二倍、四倍速。中键拖动或 WASD 平移视野，滚轮缩放。左键选址，右键取消，修堤时按 R 换边。点顶部农时预报可定位风险。游戏每季自动存档，Esc 菜单支持手动存读，失败后可重试当前时代。

## 开发与验证

使用 Godot 4.7.2 标准版打开 [桌面工程](desktop/project.godot)，按 F6 运行主场景或按 F5 运行项目。模拟按固定时钟推进，规则集中在 [农业模拟](desktop/simulation.gd)，地图投影、六角格邻接和河道地形在 [河谷定义](desktop/valley.gd)。

准备相同版本的 Windows x64 导出模板，在 PowerShell 运行构建脚本。它会生成 `Windows/` 下的可执行文件和 `dist/` 下的试玩包。

```powershell
.\build-windows.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
```

[原生交互回归](desktop/checks/playthrough.gd) 用鼠标事件操作实际界面，加速推进正常模拟时钟。它从同一个洪水预警存档验证修堤与转运两条通关路线，还会检查暂停、调速、存读、完全断粮与时代重试。运行下例会将截图、测试存档和结果单独写入临时目录。

```powershell
$result = Join-Path $env:TEMP ("rice-valley-check-" + [guid]::NewGuid())
& '.\Windows\稻生江畔.exe' --resolution 1280x720 -- "--test-output=$result" | Out-Null
Get-Content -LiteralPath (Join-Path $result 'verification.txt')
```

本仓库根目录亦保留早期设计稿、离线网页原型和旧试玩资料。当前桌面游戏使用独立存档。引擎和第三方组件的许可收录于 [licenses](licenses)。
