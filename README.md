# Docker image for alexa-fhem
A [FHEM](https://fhem.de/) complementary Docker image for Amazon alexa voice assistant, based on 
- [Node 22 - Debian bookworm-slim@sha256](https://hub.docker.com/_/node/tags?page=1&name=22-bookworm-slim@sha256)
- [alexa_fhem](https://www.npmjs.com/package/alexa-fhem?activeTab=versions)



## Installation
Pre-build images are available on [Docker Hub](https://hub.docker.com/r/fhem/alexa-fhem) and on [Github Container Registry](https://github.com/orgs/fhem/packages/container/package/fhem/alexa-fhem).


### From Github container registry
Updated version, only with Version tags
- NodeJS 22
- Alexa-Fhem 0.5.65

        docker pull ghcr.io/fhem/alexa-fhem:5.1.5

#### To start your container right away:

docker run -d --name alexa-fhem ghcr.io/fhem/alexa-fhem:5.1.5


### Permanent storage
Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name alexa-fhem -v /some/host/directory:/alexa-fhem ghcr.io/fhem/alexa-fhem:5.1.5

#### Verify if container is runnung
After starting your container, you may check the web server availability:

	http://xxx.xxx.xxx.xxx:3000/

You may want to have a look to the [alexa-fhem documentation](https://wiki.fhem.de/wiki/Alexa-Fhem) or [FHEM Connector documentation](https://wiki.fhem.de/wiki/FHEM_Connector) for further information.


### Image flavors
This image provides different variants:

- `latest` (default, can introduce breaking changes)
- `2.0.7` ( latest released Version. Can be a prerelease version)
- `5` ( latest stable release in Major v5)
- `dev` (development tag, not updated anymore)

You can use one of those variants by adding them to the docker image name like this:

	docker pull ghcr.io/fhem/alexa-fhem:latest
  docker pull ghcr.io/fhem/alexa-fhem:5	
	docker pull ghcr.io/fhem/alexa-fhem:5.1.5

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
        - subnet: 172.27.0.0/28
          gateway: 172.27.0.1
        - subnet: fd00:0:0:0:27::/80
          gateway: fd00:0:0:0:27::1


services:
  # Minimum example w/o any custom environment variables of fhem container
  fhem:
    image: ghcr.io/fhem/fhem-docker:4-bullseye
    restart: always
    networks:
      - fhem_net
    ports:
      - "8083:8083"
    volumes:
      - "./fhem/:/opt/fhem/"

 # Minimum example with some custom environment variables of alexa-fhem container
 alexa-fhem:
    image: ghcr.io/fhem/alexa-fhem:5.1.5
    restart: always
    networks:
     - fhem_net
    volumes:
      - "./alexa-fhem/:/alexa-fhem/"
    environment:
      ALEXAFHEM_UID: 6062
      ALEXAFHEM_GID: 6062
      TZ: Europe/Berlin
```

If you use another name for your fhem container `fhem`, or want to use another tcp port for fhemweb connections, then you have to change the alexa-fhem config file in the volume for your alea-fhem container `./alexa-fhem/alexa-fhem.json`.

## Configuration of alexa-fhem container

The config file is placed in the volume /alexa-fhem.
If not already present, it will be created here.

In the connections part, servername and port must match withhin fhem configuration:
```
"connections": [
    {
      "name": "FHEM",
      "webname": "fhem",
      "filter": "alexaName=..*",
      "uid": "6062",
      "port": "8083",
      "server": "fhem"
    }
  ]
```

Starting with Docker image version 5.1.x, you can control every setting via an environment variable provided by the Docker host. This means there is no need to edit any configuration files manually. All environment variables starting with the common prefix "CONFIG_" are evaluated and added to the configuration file.

To enable SSL for communication with FHEMweb, add an environment variable CONFIG_connections_0_ssl=true. If your container running FHEM is named differently, use the environment variable CONFIG_connections_0_server='fhem.docker.local'. To use another TCP port for communication with FHEM, set the environment variable CONFIG_connections_0_port='8088'.

The settings for Alexa can also be changed. Here are some examples:

`CONFIG_alexa_port=4000`
`CONFIG_alexa_name=myAlexaSkill`
`CONFIG_alexa_ssl=true`
Additionally, the SSH proxy settings can be changed if needed:

`CONFIG_sshproxy_ssh='/usr/bin/ssh'`
## Configuration of FHEM configuration

Within FHEM, you have to specify a alexa device and add attribute to identify the host. 
In this example, the container name is `alexa-fhem`, so this is also the hostname.

```
define alexa alexa
attr alexa alexaFHEM-host alexa-fhem
```

SSH and other attributes are not needed for running in a docker environment.
alexa-fhem is running correctly if you have reading like this:

`alexaFHEM.ProxyConnection = running; SSH connected`
`alexaFHEM.bearerToken = <some secret value>`
`alexaFHEM.skillRegKey = crypt:<some long value>`

You will also see a internal `alexa-fhem version` 





___
[Production Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=master)

[Development Build and Test](https://github.com/fhem/fhem/alexa-fhem-docker/workflows/Build%20and%20Test/badge.svg?branch=dev)
