# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import global_settings with context %}
{% from "ceph/map.jinja" import mon_settings with context %}
{% from "ceph/map.jinja" import osd_settings with context %}
{% from "ceph/map.jinja" import mds_settings with context %}
{% from "ceph/map.jinja" import rgw_settings with context %}
{% from "ceph/map.jinja" import client_settings with context %}

include:
  - .repo

install_ceph:
  pkg.installed:
    - require:
        - pkgrepo: ceph_repo
    - pkgs:
{%- if mon_settings.get('enabled', False) %}
{%- for pkg in mon_settings.get('pkgs', []) %}
        - {{ pkg }}
{%- endfor %}
{%- endif %}
