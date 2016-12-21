# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import global_settings with context %}
{% from "ceph/map.jinja" import mon_settings with context %}

set_cluster_name_{{ global_settings.cluster }}_in_/etc/default/ceph:
  file.append:
    - name: /etc/default/ceph
    - text: "CLUSTER={{ global_settings.cluster }}"
    - require:
      - pkg: install_ceph

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
      - file: set_cluster_name_{{ global_settings.cluster }}_in_/etc/default/ceph

{% if mon_settings.get('enabled', False) %}
# A workaround for ceph-create-key early start
stop_ceph-create-key_service:
  service.dead:
    - name: ceph-create-keys@{{ global_settings.mon_id }}.service
    - require:
        - pkg: install_ceph
{% endif %}

{% if salt.grains.get('init', '') == 'systemd' %}
reload_service_unit:
  module.run:
    - name: service.systemctl_reload
    - watch:
        - file: set_cluster_name_{{ global_settings.cluster }}_in_/etc/default/ceph
{% endif %}

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