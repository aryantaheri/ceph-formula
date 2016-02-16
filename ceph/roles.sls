# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}
{% set roles = salt['pillar.get']('ceph:nodes:' + ceph_settings.minion_id + ':roles') -%}


{% if roles -%}
roles:
  grains.list_present:
    - value:
  {% for role in roles %}
      - {{ role }}
  {% endfor -%}
{% endif -%}


