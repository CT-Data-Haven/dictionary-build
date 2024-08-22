import snakemake
from dotenv import load_dotenv
import os
load_dotenv()
from pyairtable import Api as AirtableApi
import pandas as pd
from pathlib import Path

# lookup dict of field names for indexing
labels = {
    'variables': 'variable',
    'sources': 'dataset',
    'projects': 'project',
    'vocab': 'term'
}
# find whether this is running in snakemake
def is_snakemake():
    return 'script' in dir(snakemake)

def get_base(api):
    bases = api.bases()
    base = [b for b in bases if b.name == 'Dictionary'][0]
    return base

def get_tables(api):
    base = get_base(api)
    return base.tables()

def get_table_data(table):
    return table.all(max_records = 1000)

def table_to_df(table):
    fetch = get_table_data(table)
    
    df = pd.DataFrame.from_records([r['fields'] for r in fetch],
                                   index = [r['id'] for r in fetch])
    tbl_name = table.name 
    lbl = labels[tbl_name]
    df = df.reset_index(names = f'{lbl}_id') \
        .set_index(keys = [f'{lbl}_id', lbl]) 
    return df

def unnest_df(df):
    if 'dataset' in df.columns:
        df = df.explode('dataset')
    if 'universe' in df.columns:
        df = df.explode('universe')
    to_drop = [c for c in df.columns if c in ['last_modified', 'vocab', 'variables']]
    return df.drop(columns = to_drop)

def get_dfs(api):
    tables = get_tables(api)
    return {table.name: table_to_df(table) for table in tables}

def rename_dfs(dfs):
    dfs['variables'] = dfs['variables'].rename(columns = {
        'dataset': 'dataset_id',
        'project': 'project_id',
        'universe': 'universe_id'
    })
    dfs['vocab'] = dfs['vocab'].rename(columns = {
        'project': 'project_id'
    })
    return dfs

def clean_variables(df, ids):
    univ_df = ids['variables'].rename(columns = {
        'variable': 'universe',
        'variable_id': 'universe_id'
    })
    vars_df = df \
        .explode('project_id') \
        .reset_index() \
        .merge(univ_df, on = 'universe_id', how = 'left') \
        .merge(ids['sources'], on = 'dataset_id', how = 'left') \
        .merge(ids['projects'], on = 'project_id', how = 'left')
    vars_df = vars_df.loc[:, ['variable_id', 'variable', 'display', 
                              'dataset', 'universe', 'measure_type', 
                              'question', 'detail', 'var_order', 'project']]
    vars_df = vars_df.groupby([c for c in vars_df.columns if c != 'project'],
                              dropna = False, as_index = False, sort = False) \
        .agg({'project': nest_list}) \
        .sort_values(by = 'var_order')
    return vars_df

def clean_vocab(df, ids):
    proj_df = ids['projects']
    vocab_df = df \
        .explode('project_id') \
        .reset_index() \
        .merge(proj_df, on = 'project_id', how = 'left')
    vocab_df = vocab_df.loc[:, ['term_id', 'term', 'definition', 'url',
                                'term_order', 'project']]
    vocab_df = vocab_df.groupby([c for c in vocab_df.columns if c != 'project'],
                                dropna = False, as_index = False, sort = False) \
        .agg({'project': nest_list}) \
        .sort_values(by = 'term_order')
    return vocab_df

def clean_sources(df):
    source_df = df.reset_index()
    source_df = source_df.loc[:, ['dataset_id', 'dataset', 'org', 'program',
                                  'release_year', 'data_year', 'url']]
    return source_df

def clean_projects(df):
    proj_df = df.reset_index()
    proj_df = proj_df.loc[:, ['project_id', 'project', 'repo']]
    return proj_df

def get_ids(df, tbl_name):
    lbl = labels[tbl_name]
    id = f'{lbl}_id'
    return df.index.to_frame(index = False, name = [id, lbl])

def nest_list(x):
    if x.isna().all():
        return pd.NA
    else:
        return list(x)
    
def write_json(df, tbl_name, prefix = ''):
    path = Path(prefix) / tbl_name
    path = path.with_suffix('.json')
    df.to_json(path, orient = 'records')
    return path

if __name__ == '__main__':
    running_snakemake = is_snakemake()
    
    if running_snakemake:
        api = AirtableApi(snakemake.script.snakemake.params['key'])    
    else:
        api = AirtableApi(os.getenv('AIRTABLE_API_KEY'))
    dfs = get_dfs(api)
    dfs = {k: unnest_df(v) for k, v in dfs.items()}
    dfs = rename_dfs(dfs)
    ids = {k: get_ids(v, k) for k, v in dfs.items()}
    
    # need to do manual cleanup per table
    out = {}
    out['variables'] = clean_variables(dfs['variables'], ids)
    out['vocab'] = clean_vocab(dfs['vocab'], ids)
    out['sources'] = clean_sources(dfs['sources'])
    out['projects'] = clean_projects(dfs['projects'])
    
    for k, v in out.items():
        print(write_json(v, k, 'input_data'))
    