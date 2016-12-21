{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import osd_settings with context %}
{% set mfs = gs.minionfs_dir -%}

{%- if osd_settings.get('enabled', False) %}

include:
  - .repo
  - .install
  - .config

{{ gs.bootstrap_keyrings.get('osd') }}:
  cmd.run:
    - name: echo "Getting bootstrap OSD keyring"
    - unless: test -f {{ gs.bootstrap_keyrings.get('osd') }}

{% for mon in salt['mine.get']('ceph:mon:enabled:true','ip_map','pillar') -%}

cp.get_file {{ mfs }}/{{ mon }}{{ gs.bootstrap_keyrings.get('osd') }}:
  module.wait:
    - name: cp.get_file
    - path: salt://{{ mfs }}/{{ mon }}{{ gs.bootstrap_keyrings.get('osd') }}
    - dest: {{ gs.bootstrap_keyrings.get('osd') }}
    - watch:
      - cmd: {{ gs.bootstrap_keyrings.get('osd') }}

{% endfor -%}

{% for osd in osd_settings.get('osds', []) -%}
partprobe_disk_{{ osd.get('data_path') }}:
  cmd.run:
    - name: partprobe {{ osd.get('data_path') }} 

disk_prepare data:{{ osd.get('data_path') }} journal:{{ osd.get('journal_path') }} type:{{ osd.get('fs_type') }}:
  cmd.run:
    - name: |
        ceph-disk prepare --cluster {{ gs.cluster }} \
                          --cluster-uuid {{ gs.fsid }} \
                          --fs-type {{ osd.get('fs_type', 'xfs') }} \
                          {{ osd.get('data_path') }} \
                          {{ osd.get('journal_path') }}
    - unless: parted --script {{ osd.get('data_path') }} print | grep 'ceph data'
    - require:
        - cmd: partprobe_disk_{{ osd.get('data_path') }}

# TODO: execute partprobe to load partitions and then use ceph-disk activate

{% set osd_id = salt['cmd.run']("which ceph-disk > /dev/null && ceph-disk list | grep \"" ~ osd.get('data_path') ~ "\" | awk 'match($0, /.*ceph\ data.*osd\.([0-9]+)/, a) { print a[1]}'") %}

{% if osd_id != "" -%}
start_osd_{{ osd_id }}_on_{{ osd.get('data_path') }}:
  service.running:
    - name: ceph-osd@{{ osd_id }}.service
    - enable: true
    - require:
      - file: {{ gs.conf_file }}
    - watch:
        - cmd: disk_prepare data:{{ osd.get('data_path') }} journal:{{ osd.get('journal_path') }} type:{{ osd.get('fs_type') }}
        - file: {{ gs.conf_file }}
{% endif -%}        

{% endfor -%}

start_osd:
  service.running:
    - name: ceph-osd.target
    - enable: true
    - require:
      - file: {{ gs.conf_file }}
    - watch:
      - file: {{ gs.conf_file }}

{% endif %}