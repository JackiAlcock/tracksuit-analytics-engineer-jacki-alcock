{% macro surrogate_key(field_list) %}
    {%- set hash_fields = [] -%}
    {%- for field in field_list -%}
        {%- do hash_fields.append("coalesce(" ~ field ~ "::varchar, '_surrogate_key_null_')") -%}
    {%- endfor -%}
    md5({{ hash_fields | join(" || '-' || ") }})
{% endmacro %}
