# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import mon_settings as ms with context %}
{% set ip = salt['network.ip_addrs'](ms.interface)[0] -%}
{% set secret = gs.tmp_dir + '/' + gs.cluster + '.mon.keyring' -%}
{% set monmap = gs.tmp_dir + '/' + gs.cluster + 'monmap' -%}
{% set mfs = gs.minionfs_dir -%}

include:
  - .repo
  - .install
  - .config

{{ gs.admin_keyring }}:
  cmd.run:
    - name: echo "Getting admin keyring"
    - unless: test -f {{ gs.admin_keyring }}

{% for mon in salt['mine.get']('ceph:mon:enabled:true','ip_map','pillar') -%}

cp.get_file {{ mfs }}/{{ mon }}{{ gs.admin_keyring }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mfs }}/{{ mon }}{{ gs.admin_keyring }}
    - dest: {{ gs.admin_keyring }}
    - watch:
      - cmd: {{ gs.admin_keyring }}

{% endfor -%}

get_mon_secret:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} auth get mon. -o {{ secret }}
    - onlyif: test -f {{ gs.admin_keyring }}
    - unless: test -f {{ secret }}

get_mon_map:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} mon getmap -o {{ monmap }}
    - onlyif: test -f {{ gs.admin_keyring }}
    - unless: test -f {{ monmap }}

gen_mon_secret:
  cmd.run:
    - name: |
        ceph-authtool --cluster {{ gs.cluster }} \
                      --create-keyring {{ secret }} \
                      --gen-key -n mon. \
                      --cap mon 'allow *'
    - unless: test -f /var/lib/ceph/mon/{{ gs.cluster }}-{{ gs.mon_id }}/keyring || test -f {{ secret }}

set_mon_secret_permissions:
  file.managed:
    - name: {{ secret }}
    - user: {{ gs.ceph_user }}
    - group: {{ gs.ceph_group }}
    - watch:
        - cmd: gen_mon_secret
        - cmd: get_mon_secret

gen_admin_keyring:
  cmd.run:
    - name: |
        ceph-authtool --cluster {{ gs.cluster }} \
                      --create-keyring {{ gs.admin_keyring }} \
                      --gen-key -n client.admin \
                      --set-uid=0 \
                      --cap mon 'allow *' \
                      --cap osd 'allow *' \
                      --cap mds 'allow'
    - unless: test -f /var/lib/ceph/mon/{{ gs.cluster }}-{{ gs.mon_id }}/keyring || test -f {{ gs.admin_keyring }}

import_keyring:
  cmd.wait:
    - name: |
        ceph-authtool --cluster {{ gs.cluster }} {{ secret }} \
                      --import-keyring {{ gs.admin_keyring }}
    # FIXME: The unless statement is not right
    - unless: ceph-authtool {{ secret }} --list | grep '^\[client.admin\]'
    - watch:
      - cmd: gen_mon_secret
      - cmd: gen_admin_keyring

cp.push {{ gs.admin_keyring }}:
  module.wait:
    - name: cp.push
    - path: {{ gs.admin_keyring }}
    - watch:
      - cmd: gen_admin_keyring

gen_mon_map:
  cmd.run:
    - name: |
        monmaptool --cluster {{ gs.cluster }} \
                   --create \
                   --add {{ gs.mon_id }} {{ ip }} \
                   --fsid {{ gs.fsid }} {{ monmap }}
    - unless: test -f {{ monmap }}

populate_mon:
  cmd.run:
    - name: |
        ceph-mon --cluster {{ gs.cluster }} \
                 --setuser {{ gs.ceph_user }} \
                 --setgroup {{ gs.ceph_group }} \
                 --mkfs -i {{ gs.mon_id }} \
                 --monmap {{ monmap }} \
                 --keyring {{ secret }}
    - unless: test -d /var/lib/ceph/mon/{{ gs.cluster }}-{{ gs.mon_id }}

{{ gs.cluster }}_{{ gs.mon_id }}_done:
  file.touch:
    - name: /var/lib/ceph/mon/{{ gs.cluster }}-{{ gs.mon_id }}/done
    - require:
        - cmd: populate_mon

#set_cluster_name_{{ gs.cluster }}_in_/etc/default/ceph:
#  file.append:
#    - name: /etc/default/ceph
#    - text: "CLUSTER={{ gs.cluster }}"
#    - require:
#      - file: {{ gs.cluster }}_{{ gs.mon_id }}_done

start_mon:
  service.running:
    - name: ceph-mon@{{ gs.mon_id }}.service
    - enable: true
    - require:
      - file: {{ gs.cluster }}_{{ gs.mon_id }}_done
      - file: {{ gs.conf_file }}
      - service: stop_ceph-create-key_service
    - watch:
      - file: {{ gs.conf_file }}

{% for service in 'osd', 'mds', 'rgw' %}
{{ service }}_bootstrap_keyring_wait:
  cmd.wait:
    - name: while ! test -f {{ gs.bootstrap_keyrings.get(service) }}; do sleep 0.2; done
    - timeout: 30
    - watch:
      - service: start_mon

cp.push {{ gs.bootstrap_keyrings.get(service) }}:
  module.wait:
    - name: cp.push
    - path: {{ gs.bootstrap_keyrings.get(service) }}
    - watch:
      - cmd: {{ service }}_bootstrap_keyring_wait
{% endfor %}

{{ gs.cluster }}_{{ gs.mon_id }}_upstart:
  file.touch:
    - name: /var/lib/ceph/mon/{{ gs.cluster }}-{{ gs.mon_id }}/upstart
    - require:
        - service: start_mon
