### Elasticksearch 6 with collect log from all docker sockets

Example secret curator_delete:
```
  actions:
    1:
      action: delete_indices
      filters:
      - filtertype: age
        source: creation_date
        direction: older
        unit: days
        unit_count: 10
        timestring: '%Y.%m.%d'
      - filtertype: pattern
        kind: regex
        value: 'filebeat-*'
      options:
        ignore_empty_list: True
```
Example secret curator_config:
```
  client:
    hosts:
      - elasticsearch
```
Example secret filebeat_config:
```
  filebeat.prospectors:
  - type: log
    paths:
     - '/var/lib/docker/containers/*/*.log'
     - '/var/lib/rancheros/containers/*/*.log'
    json.message_key: log
    json.keys_under_root: true
    processors:
    - add_docker_metadata:
        host: "unix:///var/run/docker.sock"
  output.elasticsearch:
    hosts: ["elasticsearch:9200"]
```
