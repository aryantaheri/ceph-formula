{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import client_settings as cs with context %}
{% set mfs = gs.minionfs_dir -%}

{% if cs.get('enabled', False) -%}

include:
  - .repo
  - .install
  - .config

{% if cs.get('admin', False) -%}

{{ gs.admin_keyring }}:
  cmd.run:
    - name: echo "Getting admin keyring:"
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

{% endif -%}

{% endif -%}