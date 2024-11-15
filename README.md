# debian-preseed-iso

Tool used to generate Debian netinst ISO with preseed file

#### Usage

Just run `./build.sh` and it will automatically download the latest amd64 Debian netinst ISO and modify it to add the `preseed.cfg` file found in the root of this repository.

#### What the bundled preseed file does?

The bundled `preseed.cfg` sets the following:
- set the installer language to english
- set the country to Romania
- set the locale and keyboard layout to en_US
- set the hostname to `debian` and the domain name to `debian.internal`
- enable the network console to allow remote installation and set its password to `debian`

After the installer has booted and it responds to pings, you can SSH into it using `ssh installer@<ip>` and password `debian`.

Should you need something else, change the preseed file, the build script should run the same.
