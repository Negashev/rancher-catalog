version: '2'
services:
  es-storage:
    image: busybox
    network_mode: none
    volumes:
    - $ES_STORAGE
    labels:
      io.rancher.container.start_once: 'true'
    command:
    - chmod
    - '777'
    - -R
    - /usr/share/elasticsearch/data
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELK_VERSION}
    environment:
      xpack.security.enabled: 'false'
      ES_JAVA_OPTS: ${ES_JAVA_OPTS}
      node.name: $${HOSTNAME}
      discovery.zen.ping.unicast.hosts: elasticsearch
    stdin_open: true
    tty: true
    volumes_from:
    - es-storage
    links:
    - sysctl:sysctl
    labels:
      io.rancher.sidekicks: es-storage
      io.rancher.container.hostname_override: container_name
      io.rancher.container.pull_image: always
      io.rancher.scheduler.affinity:host_label_ne: elk=false
      io.rancher.scheduler.global: 'true'
    logging:
      driver: json-file
      options:
        max-file: '1'
        max-size: 1mb
  sysctl:
    privileged: true
    image: alpine
    stdin_open: true
    network_mode: none
    tty: true
    command:
    - sysctl
    - -w
    - vm.max_map_count=262144
    labels:
      io.rancher.container.start_once: 'true'
      io.rancher.container.pull_image: always
      io.rancher.scheduler.global: 'true'
      cron.schedule: 0 */5 * * * *
      cron.action: start
  cerebro:
    image: yannart/cerebro
    stdin_open: true
    tty: true
    links:
    - elasticsearch:elasticsearch
    labels:
      io.rancher.container.pull_image: always
      {{- if eq .Values.UI_CEREBRO "true" }}
      io.rancher.service.ui_link.label: '{"en-us":"CEREBRO"}'
      io.rancher.websocket.proxy.port: '9000'
      {{- end }}
  curator:
    image: bobrik/curator:4.0.4
    stdin_open: true
    tty: true
    logging:
      driver: json-file
      options:
        max-file: '1'
        max-size: 1mb
    links:
    - elasticsearch:elasticsearch
    command:
    - curator
    - --config
    - /run/secrets/curator_config.yml
    - /run/secrets/curator_delete.yml
    labels:
      io.rancher.container.start_once: 'true'
      io.rancher.sidekicks: curator-conf
      io.rancher.container.pull_image: always
      cron.schedule: 0 0 * * * *
      cron.action: restart
    secrets:
    - mode: '0444'
      uid: '0'
      gid: '0'
      source: ${curator_config}
      target: curator_config.yml
    - mode: '0444'
      uid: '0'
      gid: '0'
      source: ${curator_delete}
      target: curator_delete.yml
  kibana:
    image: docker.elastic.co/kibana/kibana:${ELK_VERSION}
    stdin_open: true
    tty: true
    environment:
      xpack.monitoring.ui.container.elasticsearch.enabled: 'false'
      xpack.security.enabled: 'false'
    logging:
      driver: json-file
      options:
        max-file: '1'
        max-size: 1mb
    links:
    - elasticsearch:elasticsearch
    labels:
      io.rancher.container.pull_image: always
      {{- if eq .Values.UI_KIBANA "true" }}
      io.rancher.service.ui_link.label: '{"en-us":"KIBANA"}'
      io.rancher.websocket.proxy.port: '5601'
      {{- end }}
  filebeat:
    image: docker.elastic.co/beats/filebeat:${ELK_VERSION}
    stdin_open: true
    network_mode: host
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    {{- range $i, $volume := split .Values.LOGS_VOLUMES ", " }}
    - {{$volume}}:{{$volume}}
    {{- end }}
    tty: true
    links:
    - elasticsearch:elasticsearch
    secrets:
    - mode: '0444'
      uid: '0'
      gid: '0'
      source: ${filebeat_config}
      target: filebeat.yml
    user: root
    command:
    - filebeat
    - -c
    - /run/secrets/filebeat.yml
    labels:
      io.rancher.container.dns: 'true'
      io.rancher.container.hostname_override: container_name
      io.rancher.container.pull_image: always
      io.rancher.scheduler.global: 'true'
secrets:
  {{ .Values.curator_config }}:
    external: 'true'
  {{ .Values.curator_delete }}:
    external: 'true'
  {{ .Values.filebeat_config }}:
    external: 'true'
