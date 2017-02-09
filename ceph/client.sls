{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import client_settings as cs with context %}
{% from "ceph/macros.sls" import get_file_from_mon with context %}
{% set mfs = gs.minionfs_dir -%}

{% if cs.get('enabled', False) -%}

include:
  - .repo
  - .install
  - .config

{% for name, user in cs.users.iteritems() -%}
{{ get_file_from_mon(user.keyring_file, user.keyring_file, gs.ceph_user, gs.ceph_group) }}
{% endfor -%}


{% endif -%}