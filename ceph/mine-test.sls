# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}
{% set roles = salt['pillar.get']('ceph:nodes:' + ceph_settings.minion_id + ':roles') -%}


{% for mon, ip_map in salt['mine.get']('roles:ceph-mon','ip_map','grain').items() -%}

[mon.{{ mon }}]
#    mon host = {{ mon }}
    mon addr = {{ ip_map['eth1'][0] }}:6789

{% endfor -%}


