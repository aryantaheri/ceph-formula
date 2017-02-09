{%- if pillar.ceph is defined %}
include:
#  - ceph.roles
  - ceph.repo
  - ceph.install
  - ceph.config
{%- if pillar.ceph.mon is defined and pillar.ceph.mon.get('enabled', False) %}
  - ceph.mon
  - ceph.pools
  - ceph.users
{%- endif %}
{%- if pillar.ceph.osd is defined and pillar.ceph.osd.get('enabled', False) %}
  - ceph.osd
{%- endif %}
{%- if pillar.ceph.rgw is defined and pillar.ceph.rgw.get('enabled', False) %}
  - ceph.rgw
{%- endif %}
{%- if pillar.ceph.mds is defined and pillar.ceph.mds.get('enabled', False) %}
  - ceph.mds
{%- endif%}
{%- if pillar.ceph.client is defined and pillar.ceph.client.get('enabled', False) %}
  - ceph.client
{%- endif%}

{%- endif %}