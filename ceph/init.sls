{%- if pillar.ceph is defined %}
include:
#  - ceph.roles
  - ceph.repo
  - ceph.install
  - ceph.config
{%- if pillar.ceph.mon is defined %}
  - ceph.mon
{%- endif %}
{%- if pillar.ceph.osd is defined %}
  - ceph.osd
{%- endif %}
{%- if pillar.ceph.rgw is defined %}
  - ceph.rgw
{%- endif %}
{%- if pillar.ceph.mds is defined %}
  - ceph.mds
{%- endif%}
{%- if pillar.ceph.client is defined %}
  - ceph.client
{%- endif%}

{%- endif %}