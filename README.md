# Docker image for alexa-fhem
A [FHEM](https://fhem.de/) complementary Docker image for Amazon alexa voice assistant, based on Debian Stretch.


## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/).
We recommend pulling from the [main repository](https://hub.docker.com/r/fhem/alexa-fhem/) to allow automatic download of the correct image for your system platform:

	docker pull fhem/alexa-fhem

To start your container right away:

    docker run -d --name alexa-fhem -p 3000:3000 fhem/alexa-fhem

Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name alexa-fhem -p 3000:3000 -v /some/host/directory:/alexa-fhem fhem/alexa-fhem 

After starting your container, you may check the web server availability:

	http://xxx.xxx.xxx.xxx:3000/

You may want to have a look to the [alexa-fhem documentation](https://wiki.fhem.de/wiki/Alexa-Fhem) or [FHEM Connector documentation](https://wiki.fhem.de/wiki/FHEM_Connector) for further information.


### Image flavors
This image provides 2 different variants:

- `latest` (default)
- `dev`

You can use one of those variants by adding them to the docker image name like this:

	docker pull fhem/alexa-fhem:latest

If you do not specify any variant, `latest` will always be the default.

`latest` will give you the current stable Docker image, including up-to-date alexa-fhem.
`dev` will give you the latest development Docker image, including up-to-date alexa-fhem.


### Supported platforms
This is a multi-platform image, providing support for the following platforms:


Linux:

- `x86-64/AMD64` [Link](https://hub.docker.com/r/fhem/alexa-fhem-amd64_linux/)
- `i386` [Link](https://hub.docker.com/r/fhem/alexa-fhem-i386_linux/) currently not updated !
- `ARM32v5, armel` not available
- `ARM32v7, armhf` [Link](https://hub.docker.com/r/fhem/alexa-fhem-arm32v7_linux/)
- `ARM64v8, arm64` [Link](https://hub.docker.com/r/fhem/alexa-fhem-arm64v8_linux/)


Windows:

- currently not supported


The main repository will allow you to install on any of these platforms.
In case you would like to specifically choose your platform, go to the platform-related repository by clicking on the respective link above.

The platform repositories will also allow you to choose more specific build tags beside the rolling tags latest or dev.


## Customize your container configuration


#### Tweak container settings using environment variables

* Change alexa-fhem system user ID:
	To set a different UID for the user 'fhem' (default is 6062):

		-e ALEXAFHEM_UID=6062

* Change FHEM group ID:
	To set a different GID for the group 'fhem' (default is 6062):

    	-e ALEXAFHEM_GID=6062

* Set timezone:
	Set a specific timezone in [POSIX format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):

    	-e TZ=Europe/Berlin



___
[Production Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=master)

[Development Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=dev)
