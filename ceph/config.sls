# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import global_settings with context %}

{{ global_settings.conf_file }}:
  file.managed:
    - name: {{ global_settings.conf_file }}
    - source: salt://ceph/files/ceph.conf
    - mode: 0644
    - user: root
    - group: root
    - template: jinja
    - require:
      - pkg: install_ceph

#cp.push {{ global_settings.conf_file }}:
#  module.wait:
#    - name: cp.push
#    - path: {{ global_settings.conf_file }}
#    - watch:
#      - file: {{ global_settings.conf_file }}

#/etc/updatedb.conf:
#  file.replace:
#    - pattern: (^PRUNEPATHS.*)(\")
#    - repl: \1 /var/lib/ceph"
#    - unless: grep -q "PRUNEPATHS.*/var/lib/ceph" /etc/updatedb.conf

#updatedb:
#  cmd.wait:
#    - watch:
#      - file: /etc/updatedb.conf