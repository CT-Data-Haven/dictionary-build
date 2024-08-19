from dotenv import load_dotenv
import os
load_dotenv()

tables = ['variables', 'sources', 'projects', 'vocab']
envvars:
    'AIRTABLE_API_KEY'

rule check_dates:
    output:
        flag = '.needs_update',
    shell:
        'bash scripts/compare_dates.sh .last_build {output.flag}'

rule download_data:
    input:
        flag = rules.check_dates.output.flag,
    output:
        jsons = expand('input_data/{table}.json', table = tables),
    script:
        'scripts/download_tables.R'

rule build_db:
    input:
        jsons = rules.download_data.output.jsons,
    output:
        db = 'dict.duckdb',
        flag = '.last_build',
    shell:
        'bash scripts/build_db.sh {output.db} {input.jsons}'

rule readme:
    input:
        qmd = 'README.qmd',
        snk = 'Snakefile',
        db = rules.build_db.output.db,
    output:
        md = 'README.md',
        dag = 'dag.png',
    shell:
        'quarto render {input.qmd}'

rule all:
    input:
        rules.check_dates.output.flag,
        rules.build_db.output.db,
        rules.readme.output.md,
    default_target: True