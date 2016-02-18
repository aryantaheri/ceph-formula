# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "ceph/map.jinja" import ceph_settings with context %}

include:
  - .roles
  - .repo
  - .install
  - .install_radosgw
  - .config
  - .client

# RGW
{{ ceph_settings.radosgw_keyring }}:
  cmd.run:
    - name: echo "Getting radosgw keyring"
    - unless: test -f {{ ceph_settings.radosgw_keyring }}

# RGW
{% for radosgw in salt['mine.get']('roles:ceph-rgw','ip_map','grain') -%}

cp.get_file {{ radosgw }}{{ ceph_settings.radosgw_keyring }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ radosgw }}/files{{ ceph_settings.radosgw_keyring }}
    - dest: {{ ceph_settings.radosgw_keyring }}
    - watch:
      - cmd: {{ ceph_settings.radosgw_keyring }}

{% endfor -%}

# RGW
gen_radosgw_keyring:
  cmd.run:
    - name: |
        ceph-authtool --cluster {{ ceph_settings.cluster }} \
                      --create-keyring {{ ceph_settings.radosgw_keyring }} \
                      --gen-key -n client.radosgw.gateway \
                      --cap mon 'allow rwx' \
                      --cap osd 'allow rwx'
    - unless: test -f /var/lib/ceph/radosgw/{{ ceph_settings.cluster }}-{{ ceph_settings.host }}/keyring || test -f {{ ceph_settings.radosgw_keyring }}

# RGW
add_radosgw_keyring:
  cmd.wait:
    - name: |
        ceph --cluster {{ ceph_settings.cluster }} \
             -k {{ ceph_settings.admin_keyring }} \
             auth add client.radosgw.gateway \
             -i {{ ceph_settings.radosgw_keyring }}
    - unless: ceph -k {{ ceph_settings.admin_keyring }} auth list | grep '^\[client.radosgw.gateway\]'
    - watch:
      - cmd: gen_radosgw_keyring

# RGW
# TODO: use dedicated parameters for each pool in the defaults.yaml
{% for pool in ceph_settings.rgw.pools -%}

create_radosgw_pool_{{ pool }}:
  cmd.run:
    - name: | 
        ceph osd pool create {{ pool }} \
        {{ ceph_settings.rgw.pool_pg_num }} \
        {{ ceph_settings.rgw.pool_pgp_num }} \
        {{ ceph_settings.rgw.pool_type }} \
        {{ ceph_settings.rgw.pool_erasure_code_profile }} \
        {{ ceph_settings.rgw.pool_ruleset_name }} \
        {{ ceph_settings.rgw.pool_ruleset_num }}
    - unless: rados lspools | grep {{ pool }}

{% endfor -%}


# RGW
cp.push {{ ceph_settings.radosgw_keyring }}:
  module.wait:
    - name: cp.push
    - path: {{ ceph_settings.radosgw_keyring }}
    - watch:
      - cmd: gen_radosgw_keyring

# RGW
start_rgw:
  cmd.run:
    - name: /etc/init.d/radosgw start
    - unless: /etc/init.d/radosgw status

