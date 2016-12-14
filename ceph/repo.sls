# vi: set ft=yaml.jinja :
{% from "ceph/map.jinja" import ceph_settings with context %}

ceph_repo:
  pkgrepo.managed:
    - name: deb https://download.ceph.com/debian-{{ ceph_settings.version }}/ {{ ceph_settings.minion_oscodename }} main
    - file: /etc/apt/sources.list.d/ceph.list
    - key_url: https://download.ceph.com/keys/release.asc

