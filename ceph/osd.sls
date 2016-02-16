# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}

include:
  - .roles
  - .repo
  - .install
  - .config

{{ ceph_settings.bootstrap_osd_keyring }}:
  cmd.run:
    - name: echo "Getting bootstrap OSD keyring"
    - unless: test -f {{ ceph_settings.bootstrap_osd_keyring }}

{% for mon in salt['mine.get']('roles:ceph-mon','ip_map','grain') -%}

cp.get_file {{ mon }}{{ ceph_settings.bootstrap_osd_keyring }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mon }}/files{{ ceph_settings.bootstrap_osd_keyring }}
    - dest: {{ ceph_settings.bootstrap_osd_keyring }}
    - watch:
      - cmd: {{ ceph_settings.bootstrap_osd_keyring }}

{% endfor -%}

{% for dev in salt['pillar.get']('ceph:nodes:' + ceph_settings.minion_id + ':devs') -%}
{% if dev -%}
{% set journal = salt['pillar.get']('ceph:nodes:' + ceph_settings.minion_id + ':devs:' + dev + ':journal') -%}

disk_prepare {{ dev }}:
  cmd.run:
    - name: |
        ceph-disk prepare --cluster {{ ceph_settings.cluster }} \
                          --cluster-uuid {{ ceph_settings.fsid }} \
                          --fs-type xfs /dev/{{ dev }} /dev/{{ journal }}
    - unless: parted --script /dev/{{ dev }} print | grep 'ceph data'

disk_activate {{ dev }}1:
  cmd.run:
    - name: ceph-disk activate /dev/{{ dev }}1
    - onlyif: test -f {{ ceph_settings.bootstrap_osd_keyring }}
    - unless: ceph-disk list | egrep "/dev/{{ dev }}1.*active"
    - timeout: 10

{% endif -%}
{% endfor -%}

start ceph-osd-all:
  cmd.run:
    - onlyif: initctl list | grep "ceph-osd-all stop/waiting"
