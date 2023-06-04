# 麗 -Ulalaca-

xrdp-powered remote session broker / projector for macOS

![Screenshot_20220527_171145](https://user-images.githubusercontent.com/964412/170659838-3843d5e9-3372-47f8-940b-4ce183ca5ec9.png)

![image](https://user-images.githubusercontent.com/964412/194804281-0feb38fc-e64e-4327-92cf-d53e43215f5b.png)


# NOTE

- **STILL IN HEAVY DEVELOPMENT, NOT SUITABLE FOR PRODUCTION USE YET**
- This software requires [xrdp](https://github.com/neutrinolabs/xrdp) and [XrdpUlalaca](https://github.com/neutrinolabs/ulalaca-xrdp) to be installed for work.
- This software uses [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) which introduced with macOS 12.3, so macOS 12.3 or higher version is required.

- The name of this project, '麗 -Ulalaca-' is derived from the song "Urara" from the music simulation game [beatmania IIDX](https://en.wikipedia.org/wiki/Beatmania_IIDX).

# INSTALLATION

## USING PRE-BUILT BINARIES
To install 麗 -Ulalaca- on your system, Please check our [INSTALLATION GUIDE](https://teamunstablers.notion.site/xrdp-Ulalaca-Getting-started-f82b0c55f0b540a6ac277cc5902361b1).

## BUILD FROM SOURCE
Also, you can build 麗 -Ulalaca- from source code. Since 麗 -Ulalaca- has no external dependencies yet, so you can build apps by just open the project with Xcode. 

You can also check [ulalaca-installer](https://github.com/team-unstablers/ulalaca-installer) repository for automated build scripts.

### NOTE FOR DEVELOPERS
- `sessionprojector.app` MUST BE signed with valid Apple Developer ID, or it will requests screen recording permission on every build.
- `sessionbroker` should be run as root.

# AUTHOR

This software brought to you by [team unstablers](https://unstabler.pl).

### team unstablers

- Gyuhwan Park (@unstabler)

### THANKS TO

- @am0c - 형 앞으로도 계속 하늘에서 저 지켜봐 주세요!! \ ' ')/
