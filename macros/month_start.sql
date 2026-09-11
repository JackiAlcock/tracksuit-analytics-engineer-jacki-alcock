{% macro month_start(date_expression) %}
    date_trunc('month', {{ date_expression }})
{% endmacro %}
