# vi: set ft=yaml.jinja :
{% set oscodename = salt['config.get']('oscodename') -%}
{% from "ceph/map.jinja" import global_settings with context %}

ceph_repo:
  pkgrepo.managed:
    - name: deb https://download.ceph.com/debian-{{ global_settings.version }}/ {{ oscodename }} main
    - file: /etc/apt/sources.list.d/ceph.list
    - key_url: https://download.ceph.com/keys/release.asc

