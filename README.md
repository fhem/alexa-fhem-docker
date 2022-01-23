# Docker image for alexa-fhem
A [FHEM](https://fhem.de/) complementary Docker image for Amazon alexa voice assistant, based on 
- [Node 14 - Debian Buster](https://hub.docker.com/_/node?tab=tags&page=1&name=14-buster-slim)
- [alexa_fhem](https://www.npmjs.com/package/alexa-fhem?activeTab=versions)



## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/alexa-fhem) and on [Github Container Registry](https://github.com/orgs/fhem/packages/container/package/fhem/alexa-fhem).

### From Docker Hub
Currently outdated but still available
- NodeJS 10
- Alexa-Fhem 0.5.27


        docker pull fhem/alexa-fhem

#### To start your container right away:

        docker run -d --name alexa-fhem -p 3000:3000 fhem/alexa-fhem

### From Github container registry
Updated version, only with Version tags
- NodeJS 14
- Alexa-Fhem 0.5.62

        docker pull ghcr.io/fhem/fhem/alexa-fhem:1.0.3

#### To start your container right away:

docker run -d --name alexa-fhem -p 3000:3000 ghcr.io/fhem/fhem/alexa-fhem:dev


### Permanent storage
Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name alexa-fhem -p 3000:3000 -v /some/host/directory:/alexa-fhem fhem/alexa-fhem 

#### Verify if container is runnung
After starting your container, you may check the web server availability:

	http://xxx.xxx.xxx.xxx:3000/

You may want to have a look to the [alexa-fhem documentation](https://wiki.fhem.de/wiki/Alexa-Fhem) or [FHEM Connector documentation](https://wiki.fhem.de/wiki/FHEM_Connector) for further information.


### Image flavors
This image provides different variants:

- `latest` (default, can introduce breaking changes)
- `1.0.3` ( latest released Version. Can be a prerelease version)
- `1` ( latest stable release in Major v1)
- `dev` (development tag, not updated anymore)

You can use one of those variants by adding them to the docker image name like this:

	docker pull fhem/alexa-fhem:latest
	docker pull ghcr.io/fhem/fhem/alexa-fhem:1.0.3

If you do not specify any variant, `latest` will always be the default.

### Supported platforms
This is a multi-platform image, providing support for the following platforms:


Linux:

- `x86-64/AMD64` 
- `ARM32v7, armhf` 
- `ARM64v8, arm64` 


Windows:

- currently not supported


The main repository will allow you to install on any of these platforms.
In case you would like to specifically choose your platform, go to the platform-related section in the container repository.

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

## Use docker-compose.yaml
No problem at all. To connect alexa-fhem to your alexa container, you need a common network.
Named it fhem_net. You should connect your fhem container to the same network to support communication via alexa-fhem and fhem itself.

```
version: '2.3'

networks:
  fhem_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.27.0.0/24
          gateway: 172.27.0.1
        - subnet: fd00:0:0:0:27::/80
          gateway: fd00:0:0:0:27::1

services:
  alexa-fhem:
    # image: fhem/alexa-fhem:latest
    image: ghcr.io/fhem/fhem/alexa-fhem:dev
    restart: always
    networks:
     - fhem_net
    ports:
      - "3000:3000"
    volumes:
      - "./alexa-fhem/:/alexa-fhem/"
    environment:
      ALEXAFHEM_UID: 6062
      ALEXAFHEM_GID: 6062
      TZ: Europe/Berlin
```

___
[Production Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=master)

[Development Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=dev)
