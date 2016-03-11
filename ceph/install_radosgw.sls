# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}

include:
  - .repo

install_radosgw:
  pkg.installed:
    - name: {{ ceph_settings.radosgw_pkg }}
    - require:
        - pkgrepo: ceph_repo
