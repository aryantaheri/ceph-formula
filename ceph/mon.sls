# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}
{% set ip = salt['network.ip_addrs'](ceph_settings.mon_interface)[0] -%}
{% set secret = '/var/lib/ceph/tmp/' + ceph_settings.cluster + '.mon.keyring' -%}
{% set monmap = '/var/lib/ceph/tmp/' + ceph_settings.cluster + 'monmap' -%}

include:
  - .roles
  - .repo
  - .install
  - .config

{{ ceph_settings.admin_keyring }}:
  cmd.run:
    - name: echo "Getting admin keyring"
    - unless: test -f {{ ceph_settings.admin_keyring }}

{% for mon in salt['mine.get']('roles:ceph-mon','ip_map','grain') -%}

cp.get_file {{ mon }}{{ ceph_settings.admin_keyring }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mon }}/files{{ ceph_settings.admin_keyring }}
    - dest: {{ ceph_settings.admin_keyring }}
    - watch:
      - cmd: {{ ceph_settings.admin_keyring }}

{% endfor -%}

get_mon_secret:
  cmd.run:
    - name: ceph --cluster {{ ceph_settings.cluster }} auth get mon. -o {{ secret }}
    - onlyif: test -f {{ ceph_settings.admin_keyring }}
    - unless: test -f {{ secret }}

get_mon_map:
  cmd.run:
    - name: ceph --cluster {{ ceph_settings.cluster }} mon getmap -o {{ monmap }}
    - onlyif: test -f {{ ceph_settings.admin_keyring }}
    - unless: test -f {{ monmap }}

gen_mon_secret:
  cmd.run:
    - name: |
        ceph-authtool --cluster {{ ceph_settings.cluster }} \
                      --create-keyring {{ secret }} \
                      --gen-key -n mon. \
                      --cap mon 'allow *'
    - unless: test -f /var/lib/ceph/mon/{{ ceph_settings.cluster }}-{{ ceph_settings.minion_id }}/keyring || test -f {{ secret }}

gen_admin_keyring:
  cmd.run:
    - name: |
        ceph-authtool --cluster {{ ceph_settings.cluster }} \
                      --create-keyring {{ ceph_settings.admin_keyring }} \
                      --gen-key -n client.admin \
                      --set-uid=0 \
                      --cap mon 'allow *' \
                      --cap osd 'allow *' \
                      --cap mds 'allow'
    - unless: test -f /var/lib/ceph/mon/{{ ceph_settings.cluster }}-{{ ceph_settings.minion_id }}/keyring || test -f {{ ceph_settings.admin_keyring }}


import_keyring:
  cmd.wait:
    - name: |
        ceph-authtool --cluster {{ ceph_settings.cluster }} {{ secret }} \
                      --import-keyring {{ ceph_settings.admin_keyring }}
    # FIXME: The unless statement is not right
    - unless: ceph-authtool {{ secret }} --list | grep '^\[client.admin\]'
    - watch:
      - cmd: gen_mon_secret
      - cmd: gen_admin_keyring

cp.push {{ ceph_settings.admin_keyring }}:
  module.wait:
    - name: cp.push
    - path: {{ ceph_settings.admin_keyring }}
    - watch:
      - cmd: gen_admin_keyring

gen_mon_map:
  cmd.run:
    - name: |
        monmaptool --cluster {{ ceph_settings.cluster }} \
                   --create \
                   --add {{ ceph_settings.minion_id }} {{ ip }} \
                   --fsid {{ ceph_settings.fsid }} {{ monmap }}
    - unless: test -f {{ monmap }}

populate_mon:
  cmd.run:
    - name: |
        ceph-mon --cluster {{ ceph_settings.cluster }} \
                 --mkfs -i {{ ceph_settings.minion_id }} \
                 --monmap {{ monmap }} \
                 --keyring {{ secret }}
    - unless: test -d /var/lib/ceph/mon/{{ ceph_settings.cluster }}-{{ ceph_settings.minion_id }}

start_mon:
  cmd.run:
    - name: start ceph-mon id={{ ceph_settings.minion_id }} cluster={{ ceph_settings.cluster }}
    - unless: status ceph-mon id={{ ceph_settings.minion_id }} cluster={{ ceph_settings.cluster }}
    - require:
      - cmd: populate_mon

osd_keyring_wait:
  cmd.wait:
    - name: while ! test -f {{ ceph_settings.bootstrap_osd_keyring }}; do sleep 1; done
    - timeout: 30
    - watch:
      - cmd: start_mon

cp.push {{ ceph_settings.bootstrap_osd_keyring }}:
  module.wait:
    - name: cp.push
    - path: {{ ceph_settings.bootstrap_osd_keyring }}
    - watch:
      - cmd: osd_keyring_wait

/var/lib/ceph/mon/{{ ceph_settings.cluster }}-{{ ceph_settings.minion_id }}/upstart:
  file.touch: []
