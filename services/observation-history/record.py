"""Store actual public-source checks in a local TimescaleDB hypertable. No learner data."""
import csv,datetime,io,json,pathlib,subprocess,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[2]
CONTAINER='komaku-observations'
def sql(query):
 return subprocess.check_output(['docker','exec','-i',CONTAINER,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d','komaku'],input=query.encode()).decode().strip()
sql((ROOT/'services/observation-history/schema.sql').read_text())
url='https://komaku-mission-lab.roshan-cloudmail.workers.dev/v1/solar/latest.json'
req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 KŌMAKU-Observation-Audit'.encode('ascii','ignore').decode()})
with urllib.request.urlopen(req,timeout=30) as r:data=json.load(r)
assert data['status'] in ['available','stale']
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
c=io.StringIO();csv.writer(c,lineterminator="\n").writerow([now,data['file_updated_utc'],data['source_url'],data['sha256'],data['status']])
sql('COPY observations FROM STDIN WITH (FORMAT csv);\n'+c.getvalue()+'\\.\n')
query="""SELECT json_build_object('checks',count(*),'distinct_images',count(distinct sha256),'first_check',min(checked_at),'last_check',max(checked_at),'nasa_file_updated_at',max(nasa_file_updated_at)) FROM observations;"""
summary=json.loads(sql(query))
buckets=json.loads(sql("SELECT coalesce(json_agg(t),'[]'::json) FROM (SELECT time_bucket('1 minute',checked_at) AS minute,count(*) AS checks,count(distinct sha256) AS distinct_images FROM observations GROUP BY 1 ORDER BY 1) t;"))
summary.update({'generated_at':now,'engine':'TimescaleDB '+sql("SELECT extversion FROM pg_extension WHERE extname='timescaledb';"),'license_mode':sql('SHOW timescaledb.license;'),'scope':'Export from local self-hosted TimescaleDB; not a live cloud database. Records retrieval checks, not new NASA observations or radiation measurements.','buckets':buckets})
(ROOT/'services/mission-lab/data/history.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
