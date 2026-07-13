# Third-Party Components

TskSkinSwap downloads its runtime dependencies from their official distribution locations on first use. They are not intended to be committed to this repository.

- [BepInEx](https://github.com/BepInEx/BepInEx), LGPL-2.1 license.
- [.NET](https://github.com/dotnet), distributed under Microsoft's .NET licensing terms.
- [Python](https://www.python.org/), Python Software Foundation License.
- [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools), Android SDK license.
- [Android SDK Build Tools](https://developer.android.com/tools/releases/build-tools), Android SDK license.
- [Eclipse Temurin](https://adoptium.net/), GPL-2.0 with Classpath Exception.
- [frida-il2cpp-bridge](https://github.com/vfsfitvnm/frida-il2cpp-bridge), MIT license.
- [Frida](https://frida.re/), LGPL-2.1 license.
- [Objection](https://github.com/sensepost/objection), GPL-3.0 license. Its publicly available Android development signing key is downloaded from a pinned upstream revision when required.
- [anosu/DMM-Mod](https://github.com/anosu/DMM-Mod) provides the public compatible Android package used as patch input. The APK is downloaded separately and is not included in this repository or its release archives.

Review the upstream license files before redistributing bundled copies of these dependencies.
