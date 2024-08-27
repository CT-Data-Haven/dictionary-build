from dotenv import load_dotenv
import os
load_dotenv()

tables = ['variables', 'sources', 'projects', 'vocab']
envvars:
    'AIRTABLE_API_KEY',
    'MOTHERDUCK_TOKEN'

conda:
    'environment.yml'

rule check_dates:
    output:
        flag = touch('.needs_update'),
    shell:
        'bash scripts/compare_dates.sh .last_build .needs_update'

rule download_data:
    params:
        key=os.environ['AIRTABLE_API_KEY'],
    input:
        flag = '.needs_update',
    output:
        jsons = expand('input_data/{table}.json', table = tables),
    script:
        'scripts/fetch_tables.py'

rule build_db:
    input:
        jsons = rules.download_data.output.jsons,
    output:
        db = 'gloss.duckdb',
        flag = '.last_build',
    shell:
        'bash scripts/build_db.sh {output.db} {input.jsons}'

rule gh_release:
    input:
        meta = 'meta.toml',
        db = rules.build_db.output.db,
    output:
        flag = '.db_released.json',
    shell:
        'bash scripts/make_release.sh {input.db} {input.meta} {output.flag}'

rule md_upload:
    params:
        key=os.environ['MOTHERDUCK_TOKEN'],
    input:
        db = rules.build_db.output.db,
        # script = 'scripts/upload_to_md.sh',
    output:
        flag = '.last_upload',
    shell:
        'bash scripts/upload_to_md.sh {input.db} {params.key}'

rule all_uploads:
    input:
        gh = rules.gh_release.output.flag,
        md = rules.md_upload.output.flag,

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
        # rules.download_data.input.flag,
        '.needs_update',
        rules.gh_release.output.flag,
        rules.md_upload.output.flag,
        rules.readme.output.md,
        rules.build_db.output.db,
    default_target: True

rule clean:
    shell:
        '''
        rm -f {rules.build_db.output.flag} \
            {rules.gh_release.output.flag} \
            {rules.md_upload.output.flag} \
            {rules.readme.output.md} \
            {rules.readme.output.dag} \
            {rules.build_db.output.db} 
        '''