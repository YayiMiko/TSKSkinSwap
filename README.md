# TskSkinSwap

适用于《ティンクルスターナイツX》的 Live2D 通常攻击动画替换 MOD。工具会在通常攻击 2 请求 `bc_<角色ID>` 骨骼时，改用对应变身演出的完整高画质 `tf_<角色ID>_m0` SkeletonData，包括骨骼、网格附件、skin、atlas 和材质。

[English](README.en.md)

## 一键安装

1. 从 [Releases](https://github.com/YayiMiko/TskSkinSwap/releases) 下载 `TskSkinSwap-v0.5.0.zip`。
2. 将压缩包内的 `TskSkinSwap` 文件夹放到：

   ```text
   <游戏目录>\mods\TskSkinSwap\
   ```

3. 游戏更新后先正常启动一次，以刷新 Addressables 目录，然后关闭游戏。
4. 双击 `Apply-TskSkinSwap.bat`。
5. 显示 `Completed successfully` 后即可启动游戏。

首次运行会从官方来源安装隔离的 Python、UnityPy、.NET SDK 和 BepInEx。随后脚本读取当前客户端的 Addressables 目录，并从游戏官方 CDN 下载 MOD 所需的高画质成人版变身包和对应 Cutin 包，无需逐个打开角色界面。

成人版 Cutin 不存在时会自动回退到同 ID 的高画质 `general` Cutin。2026 年 7 月的资源目录约需下载 2.0 GiB，请至少预留 2.1 GB 磁盘空间。

## 更新与工作原理

游戏版本更新后，再次双击 `Apply-TskSkinSwap.bat`。仍然有效的下载文件会被复用，目录中已变化的 bundle 会自动重新下载。

下载文件保存在 `downloaded/bundles/`。脚本只使用当前客户端目录提供的 URL，并校验文件大小、UnityFS 格式和目标 SkeletonData。游戏原始 Addressables bundle 与 Unity 缓存不会被修改。

## 卸载

双击 `Uninstall-TskSkinSwap.bat`。卸载不会删除 BepInEx 或自动下载的资源。若需释放磁盘空间，可在卸载后删除 `downloaded/`。

## 发布说明

请勿提交或重新分发 `.tools/`、`downloaded/`、`generated/`、`src/bin/` 或 `src/obj/`。其中 `downloaded/` 包含从游戏官方 CDN 获取的版权资源。第三方组件及许可证见 [THIRD_PARTY.md](THIRD_PARTY.md)。
