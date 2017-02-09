{% from "ceph/map.jinja" import global_settings as gs with context %}
{% set mfs = gs.minionfs_dir -%}

{%- macro create_pool(name, pool, require_in='') -%}
create_pool_{{ name }}:
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
{%- if require_in != '' %}
    - require_in:
        - {{ require_in }}
{%- endif %}
{%- endmacro -%}

{%- macro set_pool_param(name, pool, param) -%}
set_pool_{{ name }}_param_{{ param }}_to_{{ pool.get(param) }}:
  cmd.run:
    - name: ceph --cluster {{ gs.cluster }} osd pool set {{ name }} {{ param }} {{ pool.get(param) }}
    - onlyif: ceph --cluster {{ gs.cluster }} osd pool stats {{ name }}
    - unless: ceph --cluster {{ gs.cluster }} osd pool get {{ name }} {{ param }} | grep " {{ pool.get(param) }}$"
{%- endmacro -%}

{%- macro wait_for_pool(name, require_in='') -%}
wait_for_pool_{{ name }}:
  cmd.run:  
    - name: |
        while [ $(ceph --cluster {{ gs.cluster }} -s | grep creating -c) -gt 0 ]; do echo -n .;sleep 1; done
    - watch:
      - cmd: create_pool_{{ name }}
{%- if require_in != '' %}
    - require_in:
        - {{ require_in }}
{%- endif %}
{%- endmacro -%}


{%- macro auth_get_or_create(name, user) -%}
get_or_create_{{ name }}_keyring_{{ user.keyring_file }}:
  cmd.run:
    - name: |
        ceph --cluster {{ gs.cluster }} \
             auth get-or-create {{ name }} \
             mon '{{ user.mon }}' \
             osd '{{ user.osd }}' \
             -o {{ user.keyring_file }}
{%- endmacro -%}


{%- macro get_file_from_mon(path, dest, user, group, mode='', overwrite=False)-%}
{% for mon in salt['mine.get']('ceph:mon:enabled:true','ip_map','pillar') -%}
get_file_from_master {{ mfs }}/{{ mon }}{{ path }}:
  module.run:
    - name: cp.get_file
    - path: salt://{{ mfs }}/{{ mon }}{{ path }}
    - dest: "{{ dest }}"
    - unless: 
        - test -f "{{ dest }}"
        - {% if overwrite -%} "false" {%- else -%} "true" {%- endif %}
    - watch_in:
        - file: set_permission_{{ dest }}
{% endfor -%}

set_permission_{{ dest }}:
  file.managed:
    - name: {{ dest }}
    - user: {{ user }}
    - group: {{ group }}
    - mode: {{ mode }}
    - onlyif: test -f "{{ dest }}"
{%- endmacro -%}
