# vi: set ft=yaml.jinja :

{% from "ceph/map.jinja" import ceph_settings with context %}

include:
  - .roles
  - .repo

ceph-common:
  pkg.installed:
    - require:
      - pkgrepo: ceph_repo

client_{{ ceph_settings.conf_file }}:
  cmd.run:
    - name: echo "Getting ceph configuration file:"
    - unless: test -f {{ ceph_settings.conf_file }}

{% for mon in salt['mine.get']('roles:ceph-mon','ip_map','grain') -%}

cp.get_file {{ mon }}{{ ceph_settings.conf_file }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mon }}/files{{ ceph_settings.conf_file }}
    - dest: {{ ceph_settings.conf_file }}
    - watch:
      - cmd: client_{{ ceph_settings.conf_file }}

{% endfor -%}

{{ ceph_settings.admin_keyring }}:
  cmd.run:
    - name: echo "Getting admin keyring:"
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