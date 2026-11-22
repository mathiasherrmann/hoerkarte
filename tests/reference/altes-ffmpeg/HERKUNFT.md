# Herkunft und Identität der alten x86_64-Binaries

Erfasst am 2026-11-22 13:34:29 CET auf arm64, macOS 26.5.1, unter Rosetta 2.
Quelle: hoerbert/tools/mac/ffmpeg im Commit 7f225e2.

## SHA-256 und Architektur

| Datei | Bytes | Architektur | SHA-256 |
|---|---|---|---|
| `ffmpeg` | 243888 | x86_64 | `9ee9c85fe3787b9225e0db65c7a6c3acb7df79cf66a940c61c65cffcd2b1b1fc` |
| `ffplay` | 2169672 | x86_64 | `cc2d6b63536e46e223296bd28c899ad027a78b7f8210cb1ab15bc410b8856b88` |
| `ffprobe` | 158248 | x86_64 | `1d469628141b4a88c5c523d279a8fa8c1de8cf582b00fb9893024c5359ae2d75` |
| `libavcodec.58.dylib` | 48793100 | x86_64 | `280c0992761a1ca59c65356350627acd0d413822da52411a08f81455423fc2e8` |
| `libavdevice.58.dylib` | 2076756 | x86_64 | `a5095517533bcea38bc4642cc36d881f8a8575511444b1094f62bee4fd996686` |
| `libavfilter.7.dylib` | 7838084 | x86_64 | `870455ef9ee51edff5bd0c9f3c06a99d5e699783a42f755fe72052d7dc74e9bc` |
| `libavformat.58.dylib` | 7786520 | x86_64 | `c21fc79e42d738ae73efe8462f72383445cffbbf66e0182b98945a56877431b9` |
| `libavutil.56.dylib` | 414160 | x86_64 | `6cc17e95d027aa208f5ce1822787a7846e6406390e6683fc840fc8a38d2e4f6f` |
| `libpostproc.55.dylib` | 140948 | x86_64 | `354a2a4426b5f8f303732b9a3afa1bb4b30c9e252cb70009ca466195c6c3ceee` |
| `libswresample.3.dylib` | 371664 | x86_64 | `4f51bffccf1c62e499927e011499ba3a3464bf23a2dfa049765d4db4de1f7699` |
| `libswscale.5.dylib` | 809116 | x86_64 | `792480b76c4b5eb6e0fbf72a279bc95497243deaf4d1b1fd691a5e2b3ab9abbc` |

## README im Verzeichnis (Originaltext)

```
custom ffmpeg build.

For mac, this ffmpeg build mainly does this:
Add version numbers to the dlls, so this ffmpeg does not pull the wrong dlls, even when they reside in the same directory
```

## Bibliotheksbindung

### ffmpeg
```
	@loader_path/libavdevice.58.dylib (compatibility version 58.0.0, current version 58.7.100)
	@loader_path/libavfilter.7.dylib (compatibility version 7.0.0, current version 7.48.100)
	@loader_path/libavformat.58.dylib (compatibility version 58.0.0, current version 58.27.100)
	@loader_path/libavcodec.58.dylib (compatibility version 58.0.0, current version 58.48.101)
	@loader_path/libpostproc.55.dylib (compatibility version 55.0.0, current version 55.4.100)
	@loader_path/libswresample.3.dylib (compatibility version 3.0.0, current version 3.4.100)
	@loader_path/libswscale.5.dylib (compatibility version 5.0.0, current version 5.4.100)
	@loader_path/libavutil.56.dylib (compatibility version 56.0.0, current version 56.26.100)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1570.15.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.250.1)
	/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
	/System/Library/Frameworks/CoreVideo.framework/Versions/A/CoreVideo (compatibility version 1.2.0, current version 1.5.0)
	/System/Library/Frameworks/CoreMedia.framework/Versions/A/CoreMedia (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics (compatibility version 64.0.0, current version 1251.12.0)
	/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox (compatibility version 1.0.0, current version 492.0.0)
	/System/Library/Frameworks/ForceFeedback.framework/Versions/A/ForceFeedback (compatibility version 1.0.0, current version 1.0.2)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa (compatibility version 1.0.0, current version 23.0.0)
	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 158.0.0)
	/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit (compatibility version 1.0.0, current version 275.0.0)
	/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore (compatibility version 1.2.0, current version 1.11.0, weak)
	/System/Library/Frameworks/Metal.framework/Versions/A/Metal (compatibility version 1.0.0, current version 161.7.1, weak)
	/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libbz2.1.0.dylib (compatibility version 1.0.0, current version 1.0.5)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 400.9.4)
	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 1671.40.118)
	/System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1570.15.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 944.3.0)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 58286.251.4)
	/usr/lib/libexpat.1.dylib (compatibility version 7.0.0, current version 8.0.0)
```

### ffprobe
```
	@loader_path/libavdevice.58.dylib (compatibility version 58.0.0, current version 58.7.100)
	@loader_path/libavfilter.7.dylib (compatibility version 7.0.0, current version 7.48.100)
	@loader_path/libavformat.58.dylib (compatibility version 58.0.0, current version 58.27.100)
	@loader_path/libavcodec.58.dylib (compatibility version 58.0.0, current version 58.48.101)
	@loader_path/libpostproc.55.dylib (compatibility version 55.0.0, current version 55.4.100)
	@loader_path/libswresample.3.dylib (compatibility version 3.0.0, current version 3.4.100)
	@loader_path/libswscale.5.dylib (compatibility version 5.0.0, current version 5.4.100)
	@loader_path/libavutil.56.dylib (compatibility version 56.0.0, current version 56.26.100)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1570.15.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.250.1)
	/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
	/System/Library/Frameworks/CoreVideo.framework/Versions/A/CoreVideo (compatibility version 1.2.0, current version 1.5.0)
	/System/Library/Frameworks/CoreMedia.framework/Versions/A/CoreMedia (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics (compatibility version 64.0.0, current version 1251.12.0)
	/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox (compatibility version 1.0.0, current version 492.0.0)
	/System/Library/Frameworks/ForceFeedback.framework/Versions/A/ForceFeedback (compatibility version 1.0.0, current version 1.0.2)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa (compatibility version 1.0.0, current version 23.0.0)
	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 158.0.0)
	/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit (compatibility version 1.0.0, current version 275.0.0)
	/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore (compatibility version 1.2.0, current version 1.11.0, weak)
	/System/Library/Frameworks/Metal.framework/Versions/A/Metal (compatibility version 1.0.0, current version 161.7.1, weak)
	/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libbz2.1.0.dylib (compatibility version 1.0.0, current version 1.0.5)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 400.9.4)
	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 1671.40.118)
	/System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1570.15.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 944.3.0)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 58286.251.4)
	/usr/lib/libexpat.1.dylib (compatibility version 7.0.0, current version 8.0.0)
```

### ffplay
```
	@loader_path/libavdevice.58.dylib (compatibility version 58.0.0, current version 58.7.100)
	@loader_path/libavfilter.7.dylib (compatibility version 7.0.0, current version 7.48.100)
	@loader_path/libavformat.58.dylib (compatibility version 58.0.0, current version 58.27.100)
	@loader_path/libavcodec.58.dylib (compatibility version 58.0.0, current version 58.48.101)
	@loader_path/libpostproc.55.dylib (compatibility version 55.0.0, current version 55.4.100)
	@loader_path/libswresample.3.dylib (compatibility version 3.0.0, current version 3.4.100)
	@loader_path/libswscale.5.dylib (compatibility version 5.0.0, current version 5.4.100)
	@loader_path/libavutil.56.dylib (compatibility version 56.0.0, current version 56.26.100)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1570.15.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.250.1)
	/System/Library/Frameworks/AVFoundation.framework/Versions/A/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
	/System/Library/Frameworks/CoreVideo.framework/Versions/A/CoreVideo (compatibility version 1.2.0, current version 1.5.0)
	/System/Library/Frameworks/CoreMedia.framework/Versions/A/CoreMedia (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics (compatibility version 64.0.0, current version 1251.12.0)
	/System/Library/Frameworks/CoreAudio.framework/Versions/A/CoreAudio (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/AudioToolbox.framework/Versions/A/AudioToolbox (compatibility version 1.0.0, current version 492.0.0)
	/System/Library/Frameworks/ForceFeedback.framework/Versions/A/ForceFeedback (compatibility version 1.0.0, current version 1.0.2)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa (compatibility version 1.0.0, current version 23.0.0)
	/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon (compatibility version 2.0.0, current version 158.0.0)
	/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit (compatibility version 1.0.0, current version 275.0.0)
	/System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore (compatibility version 1.2.0, current version 1.11.0, weak)
	/System/Library/Frameworks/Metal.framework/Versions/A/Metal (compatibility version 1.0.0, current version 161.7.1, weak)
	/System/Library/Frameworks/OpenGL.framework/Versions/A/OpenGL (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libbz2.1.0.dylib (compatibility version 1.0.0, current version 1.0.5)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 400.9.4)
	/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 1671.40.118)
	/System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox (compatibility version 1.0.0, current version 1.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1570.15.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 944.3.0)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 58286.251.4)
	/usr/lib/libexpat.1.dylib (compatibility version 7.0.0, current version 8.0.0)
```

