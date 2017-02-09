{% from "ceph/map.jinja" import global_settings as gs with context %}
{% from "ceph/map.jinja" import mon_settings as ms with context %}
{% from "ceph/macros.sls" import create_pool with context %}
{% from "ceph/macros.sls" import wait_for_pool with context %}
{% from "ceph/macros.sls" import set_pool_param with context %}
{% set mfs = gs.minionfs_dir -%}

{% for name, pool in ms.pools.iteritems() -%}

{%- if pool.get('action', '') == 'create' %}
{{ create_pool(name, pool) }}
{#{{ wait_for_pool(name) }}#}
{%- endif %}

{%- if pool.get('action', '') == 'update' %}
{{ set_pool_param(name, pool, 'size') }}
{{ set_pool_param(name, pool, 'pg_num') }}
{{ set_pool_param(name, pool, 'pgp_num') }}
{%- endif %}

{% endfor -%}
