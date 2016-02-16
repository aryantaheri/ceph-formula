# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}

include:
  - .repo

install_ceph:
  pkg.installed:
    - name: {{ ceph_settings.pkg }}
    - require:
        - pkgrepo: ceph_repo
