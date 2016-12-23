{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import rgw_settings as rs with context %}
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

create_radosgw_pool_{{ name }}:
  cmd.run:
    - name: | 
        ceph --cluster {{ gs.cluster }} osd pool create {{ name }} \
        {{ pool.get('pg_num') }} \
        {{ pool.get('pgp_num') }} \
        {{ pool.get('type', 'replicated') }} \
        {{ pool.get('erasure_code_profile', '') }} \
        {{ pool.get('crush_ruleset_name', '') }} \
        {{ pool.get('expected_num_objects', '') }}
    - unless: ceph --cluster {{ gs.cluster }} osd pool stats {{ name }}

set_radosgw_pool_{{ name }}_size_{{ pool.get('size') }}:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} osd pool set {{ name }} size {{ pool.get('size') }}
    - require:
        - cmd: create_radosgw_pool_{{ name }}
    - unless: ceph --cluster {{ gs.cluster }} osd pool get {{ name }} size | grep " {{ pool.get('size') }}$"


set_radosgw_pool_{{ name }}_pg_num_{{ pool.get('pg_num') }}:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} osd pool set {{ name }} pg_num {{ pool.get('pg_num') }}
    - require:
        - cmd: create_radosgw_pool_{{ name }}
    - unless: ceph --cluster {{ gs.cluster }} osd pool get {{ name }} pg_num | grep " {{ pool.get('pg_num') }}$"

set_radosgw_pool_{{ name }}_pgp_num_{{ pool.get('pgp_num') }}:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} osd pool set {{ name }} pgp_num {{ pool.get('pgp_num') }}
    - require:
        - cmd: create_radosgw_pool_{{ name }}
    - unless: ceph --cluster {{ gs.cluster }} osd pool get {{ name }} pgp_num | grep " {{ pool.get('pgp_num') }}$"

wait_for_radosgw_pool_creation_{{ name }}:
  cmd.run:
    - name: |
        while [ $(ceph --cluster {{ gs.cluster }} -s | grep creating -c) -gt 0 ]; do echo -n .;sleep 1; done
    - require:
        - cmd: set_radosgw_pool_{{ name }}_pgp_num_{{ pool.get('pgp_num') }}


{% endfor -%}


{% endif %}