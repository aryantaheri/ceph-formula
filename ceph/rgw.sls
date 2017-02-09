{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import rgw_settings as rs with context %}
{% from "ceph/macros.sls" import create_pool with context %}
{% from "ceph/macros.sls" import set_pool_param with context %}
{% from "ceph/macros.sls" import wait_for_pool with context %}
{% set mfs = gs.minionfs_dir -%}

{% if rs.get('enabled', False) -%}

include:
  - .repo
  - .install
  - .config
  - .client

{% for key, dir in rs.radosgw_dirs.iteritems() -%}
verify_dir_{{ dir }}_exists:
  file.directory:
    - name: {{ dir }}
    - user: {{ gs.ceph_user }}
    - group: {{ gs.ceph_group }}
    - makedirs: true
{% endfor -%}

{{ gs.bootstrap_keyrings.get('rgw') }}:
  cmd.run:
    - name: echo "Getting bootstrap RGW keyring"
    - unless: test -f {{ gs.bootstrap_keyrings.get('rgw') }}

{% for mon in salt['mine.get']('ceph:mon:enabled:true','ip_map','pillar') -%}

cp.get_file {{ mfs }}/{{ mon }}{{ gs.bootstrap_keyrings.get('rgw') }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mfs }}/{{ mon }}{{ gs.bootstrap_keyrings.get('rgw') }}
    - dest: {{ gs.bootstrap_keyrings.get('rgw') }}
    - watch:
      - cmd: {{ gs.bootstrap_keyrings.get('rgw') }}

{% endfor -%}

# FIXME: bootstrap-rgw doesn't work; using admin keyring. 
# Add the following to revert the behavior
#             --name client.bootstrap-rgw \
#             --keyring {{ gs.bootstrap_keyrings.get('rgw') }} \
get_or_create_{{ rs.radosgw_keyring }}:
  cmd.run:
    - name: |
        ceph --cluster {{ gs.cluster }} \
             auth get-or-create {{ rs.name }} \
             osd 'allow rwx' \
             mon 'allow rwx' \
             -o {{ rs.radosgw_keyring }}
    - creates: {{ rs.radosgw_keyring }}


{{ rs.radosgw_dirs.keyring_dir }}_done:
  file.touch:
    - name: {{ rs.radosgw_dirs.keyring_dir }}/done
    - require:
        - cmd: get_or_create_{{ rs.radosgw_keyring }}

set_rgw_keyring_permissions:
  file.managed:
    - name: {{ rs.radosgw_keyring }}
    - user: {{ gs.ceph_user }}
    - group: {{ gs.ceph_group }}
    - watch:
        - cmd: get_or_create_{{ rs.radosgw_keyring }}

{%- if rs.identity is defined and rs.identity.get('engine', '') == 'keystone' %}
create_nss_ca_for_keystone:
  cmd.run:
    - name: |
        openssl x509 -in /etc/keystone/ssl/certs/ca.pem -pubkey | \
        certutil -d {{ rs.radosgw_dirs.nss_db_dir }} -A -n ca -t "TCu,Cu,Tuw"

create_nss_signing_cert_for_keystone:
  cmd.run:
    - name: |
        openssl x509 -in /etc/keystone/ssl/certs/signing_cert.pem -pubkey | \
        certutil -A -d {{ rs.radosgw_dirs.nss_db_dir }} -n signing_cert -t "P,P,P"

set_nss_permissions:
  file.directory:
    - name: {{ rs.radosgw_dirs.nss_db_dir }}
    - user: {{ gs.ceph_user }}
    - group: {{ gs.ceph_group }}
    - recurse:
        - user
        - group
    - watch:
        - cmd: create_nss_ca_for_keystone
        - cmd: create_nss_signing_cert_for_keystone
{%- endif %}

start_rgw:
  service.running:
    - name: ceph-radosgw@{{ rs.id }}
    - enable: true
    - require:
      - file: {{ gs.conf_file }}
    - watch:
      - file: {{ gs.conf_file }}
      - cmd: get_or_create_{{ rs.radosgw_keyring }}



{% for name, pool in rs.pools.iteritems() -%}

{%- if pool.get('action', '') == 'create' %}
{{ create_pool(name, pool, 'service: start_rgw') }}
{#{{ wait_for_pool(name, 'service: start_rgw') }}#}
{%- endif %}

{%- if pool.get('action', '') == 'update' %}
{{ set_pool_param(name, pool, 'size') }}
{{ set_pool_param(name, pool, 'pg_num') }}
{{ set_pool_param(name, pool, 'pgp_num') }}
{%- endif %}

{% endfor -%}


{% endif %}