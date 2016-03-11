# vi: set ft=yaml.jinja :
{% set oscodename = salt['config.get']('oscodename') -%}
{% from "ceph/map.jinja" import ceph_settings with context %}

ceph_repo:
  pkgrepo.managed:
    - name: deb http://ceph.com/debian-{{ ceph_settings.version }}/ {{ oscodename }} main
    - file: /etc/apt/sources.list.d/ceph.list
    - key_url: https://raw.github.com/ceph/ceph/master/keys/release.asc

