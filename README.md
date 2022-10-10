# 麗 -ulalaca-

xrdp-powered remote session broker / projector for macOS

![Screenshot_20220527_171145](https://user-images.githubusercontent.com/964412/170659838-3843d5e9-3372-47f8-940b-4ce183ca5ec9.png)

![image](https://user-images.githubusercontent.com/964412/194804281-0feb38fc-e64e-4327-92cf-d53e43215f5b.png)


# NOTE

- **STILL IN HEAVY DEVELOPMENT, NOT SUITABLE FOR PRODUCTION USE YET**
- This software requires [xrdp](https://github.com/neutrinolabs/xrdp) and [ulalaca-xrdp](https://github.com/neutrinolabs/ulalaca-xrdp) to be installed for work.
- This software uses [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) which introduced with macOS 12.3, so macOS 12.3 or higher version is required.


# INSTALLATION

```
$ git clone https://github.com/unstabler/Ulalaca.git ulalaca
$ cd ulalaca

# build sessionprojector
$ xcodebuild DSTROOT=/usr/local/opt -workspace Ulalaca.xcworkspace -scheme sessionbroker
$ sudo xcodebuild DSTROOT=/usr/local/opt -workspace Ulalaca.xcworkspace -scheme sessionbroker install

# enable launchd service
$ sudo cp /usr/local/opt/ulalaca-sessionprojector/pl.unstabler.ulalaca.sessionbroker.plist /Library/LaunchDaemons
$ launchctl start pl.unstabler.ulalaca.sessionbroker

# build sessionprojector
$ xcodebuild DSTROOT=`pwd`/build -workspace Ulalaca.workspace -scheme sessionprojector

# copy sessionprojector.app to /Applications
$ open build/ 

# register autostart entry
$ sudo cp sessionprojector/LaunchAgents/pl.unstabler.ulalaca.sessionprojector.plist /Library/LaunchAgents/

```

# AUTHOR

This software brought to you by [team unstablers](https://unstabler.pl).

### team unstablers

- Gyuhwan Park (@unstabler)


### THANKS TO

- @am0c - 형 앞으로도 계속 하늘에서 저 지켜봐 주세요!! \ ' ')/
