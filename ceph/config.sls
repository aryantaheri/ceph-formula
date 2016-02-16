# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}

{{ ceph_settings.conf_file }}:
  file.managed:
    - name: {{ ceph_settings.conf_file }}
    - source: salt://ceph/files/ceph.conf
    - mode: 0644
    - user: root
    - group: root
    - template: jinja
    - require:
      - pkg: ceph

cp.push {{ ceph_settings.conf_file }}:
  module.wait:
    - name: cp.push
    - path: {{ ceph_settings.conf_file }}
    - watch:
      - file: {{ ceph_settings.conf_file }}