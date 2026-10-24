# Docker image for alexa-fhem
A [FHEM](https://fhem.de/) complementary Docker image for Amazon alexa voice assistant, based on 
- [Node 22 - Debian bookworm-slim](https://hub.docker.com/_/node/tags?page=1&name=22-bookworm-slim)
- [alexa_fhem](https://www.npmjs.com/package/alexa-fhem?activeTab=versions)



## Installation
Pre-build images are available on [Github Container Registry](https://github.com/orgs/fhem/packages/container/package/fhem/alexa-fhem).

### Caution
No up to date images are provided on [Docker Hub](https://hub.docker.com/r/fhem/alexa-fhem) currently. 
Do not use the outdated images.


### From Github container registry
Updated version, only with Version tags
- NodeJS 22
- Alexa-Fhem 0.5.65

        docker pull ghcr.io/fhem/alexa-fhem:5.2.1

#### To start your container right away:

docker run -d --name alexa-fhem ghcr.io/fhem/alexa-fhem:5.2.1


### Permanent storage
Usually you want to keep your FHEM setup after a container was destroyed (or re-build) so it is a good idea to provide an external directory on your Docker host to keep that data:

    docker run -d --name alexa-fhem -v /some/host/directory:/alexa-fhem ghcr.io/fhem/alexa-fhem:5.2.1

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
	docker pull ghcr.io/fhem/alexa-fhem:5.2.1

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
    image: ghcr.io/fhem/fhem-docker:5-bookworm
    restart: always
    networks:
      - fhem_net
    ports:
      - "8083:8083"
    volumes:
      - "./fhem/:/opt/fhem/"

 # Minimum example with some custom environment variables of alexa-fhem container
 alexa-fhem:
    image: ghcr.io/fhem/alexa-fhem:5.2.1
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
### Optional logfile

By default alexa-fhem only writes to stdout/stderr (`docker logs`). To additionally write the output to a file, e.g. on a volume shared with the FHEM container, set the environment variable `ALEXAFHEM_LOGFILE`. If it is unset or empty (default), no logfile is written.

```
  alexa-fhem:
    image: ghcr.io/fhem/alexa-fhem:5.2.1
    volumes:
      - "./alexa-fhem/:/alexa-fhem/"
      - "alexa_fhem_log:/var/log/alexa-fhem"
    environment:
      ALEXAFHEM_LOGFILE: /var/log/alexa-fhem/alexa-fhem.log

  fhem:
    volumes:
      - "./fhem/:/opt/fhem/"
      # mount read-only into a subdirectory, so the existing FHEM log directory is not hidden
      - "alexa_fhem_log:/opt/fhem/log/alexa-fhem:ro"

volumes:
  alexa_fhem_log:
```

If a logfile is configured, stderr is merged into stdout. The path must be absolute and a regular file (symlinks and directories are rejected). The log directory must not contain symlinks and must only be writable by root or the alexa-fhem user, otherwise file logging is disabled with a warning. Therefore mount the volume read-only (`:ro`) in other containers like FHEM; the fhem container would otherwise take over ownership of it on startup. 
**Sensitive data:** alexa-fhem logs the requests it receives, including bearer tokens, grant codes, device states and voice commands. Everybody who can read the logfile, e.g. FHEMWEB users via the FileLog below and FHEM backups, can see this data. By default the file is world-readable (644). To restrict it to the fhem group, set `ALEXAFHEM_LOGFILE_GID` to the numeric group id of the fhem user in the fhem container (default `6061`); the file is then created with mode 640:

```
    environment:
      ALEXAFHEM_LOGFILE: /var/log/alexa-fhem/alexa-fhem.log
      ALEXAFHEM_LOGFILE_GID: 6061
```

**Rotation:** The file is appended to and not rotated by the container, and it grows with every reading change. Rotate it on the Docker host, e.g. with `/etc/logrotate.d/alexa-fhem` (adjust the path to your volume, see `docker volume inspect <project>_alexa_fhem_log`):

```
/var/lib/docker/volumes/<project>_alexa_fhem_log/_data/alexa-fhem.log {
    daily
    maxsize 10M
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
```

`copytruncate` is required, because the container keeps the file open. Do not delete the file while the container is running, the output would then go to the deleted file until the next restart.

To show the file in the FHEM frontend without FHEM writing to it, define a FileLog with `fakelog` in FHEM (the path is the one seen from the FHEM container):

```
define alexaFhemLog FileLog /opt/fhem/log/alexa-fhem/alexa-fhem.log fakelog
```

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
