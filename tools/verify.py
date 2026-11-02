"""Read-only delivery integrity and reference checks; no vendor tools required."""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
R=Path(__file__).resolve().parents[1]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def verify():
 errors=[];counts={}
 origins=json.loads((R/'metadata/origins.json').read_text(encoding='utf-8'))['files']
 for row in origins:
  p=R/row['path']
  if not p.is_file() or digest(p)!=row['sha256']:errors.append('frozen_identity: '+row['path'])
 counts['frozen_copied_files']=len(origins)
 fixtures=json.loads((R/'metadata/test_fixtures.json').read_text(encoding='utf-8'))
 for row in fixtures:
  if digest(R/row['path'])!=row['sha256']:errors.append('test_fixture: '+row['path'])
 counts['comparison_test_fixtures']=len(fixtures)
 inputs=json.loads((R/'metadata/frozen_build_inputs.json').read_text())
 for name,h in inputs.items():
  p=R/'project'/name
  if not p.is_file() or digest(p)!=h:errors.append('build_input: '+name)
 counts['frozen_build_inputs']=len(inputs)
 project=R/'project/td_project/camera_to_dsi_display.al'
 # TD .al is XML-like (unescaped vendor attributes), not strict XML.
 block=re.search(r'<Source_Files>.*?</Source_Files>',project.read_text(encoding='utf-8-sig'),re.S)[0]
 paths=re.findall(r'<File Path="([^"]+)"',block)
 for name in paths:
  p=(project.parent/name).resolve()
  if not p.is_relative_to(R) or not p.is_file():errors.append('project_reference: '+str(p))
 counts['native_project_references']=len(paths)
 # Parse IP-XACT file sets. Vendor generated source wrappers are all included.
 xmlrefs=0
 for p in (R/'project/user_source').rglob('*.xml'):
  doc=ET.parse(p)
  for node in doc.iter():
   if node.tag.split('}')[-1]!='file':continue
   names=[n.text for n in node if n.tag.split('}')[-1]=='name' and n.text]
   for name in names:
    q=(p.parent/name).resolve();xmlrefs+=1
    if not q.is_relative_to(R) or not q.is_file():errors.append('ip_reference: '+str(p.relative_to(R))+' -> '+name)
 counts['ip_file_references']=xmlrefs
 # Includes can be resolved by the containing directory or the provided IP include dirs.
 src=R/'project/user_source';includes=0;inactive=[]
 for p in src.rglob('*'):
  if p.suffix not in ['.v','.sv','.vh']:continue
  for name in re.findall(r'`include\s+"([^"\n]+)"',p.read_text(errors='replace')):
   includes+=1
   if not (p.parent/name).is_file() and not list(src.rglob(name)):
    if p.name=='alc_mc_top_all.enc.sv' and Path(name).name in ['ddr3_parameter.vh','ddr4_parameter.vh']:
     define=(src/'hdl_source/ph1p35_ddr/ddr2/src/rtl/include/ph1p_mis_define.vh').read_text()
     if '`define DRAM_DDR2' in define and not re.search(r'`define DRAM_DDR[34]',define):inactive.append(name)
     else:errors.append('DDR configuration changed: '+name)
    else:errors.append('include: '+name)
 counts['hdl_include_references']=includes
 counts['inactive_ddr3_ddr4_include_references']=len(inactive)
 for p in (R/'project/simulation').rglob('*.do'):
  variables=dict(re.findall(r'(?m)^set (\w+) (\S+)',p.read_text()))
  for line in p.read_text().splitlines():
   if not line.startswith('vlog '):continue
   for name in line.split()[1:]:
    for key,value in variables.items():name=name.replace('$'+key+'/',value+'/')
    if name.startswith(('-', '+','$env')):continue
    if name.endswith(('.v','.sv','.vh')) and not (p.parent/name).is_file():errors.append('simulation_reference: '+str(p.relative_to(R))+' -> '+name)
 bit=R/'bitstream/security_monitor_720p_ddr_fix.bit'
 if digest(bit)!='f787fd27c9d53362792d60e67884caa15f55bfa3df9f6659d756b129d1615e20':errors.append('bit_sha256')
 if len(list(R.rglob('*.bit')))!=1:errors.append('expected exactly one delivered bit')
 if (R/'MANIFEST.json').exists():
  rows=json.loads((R/'MANIFEST.json').read_text(encoding='utf-8'))['files']
  for row in rows:
   p=R/row['path']
   if not p.is_file() or p.stat().st_size!=row['bytes'] or digest(p)!=row['sha256']:errors.append('manifest: '+row['path'])
  expected={r['path'] for r in rows}|{'MANIFEST.json','SHA256SUMS.txt'}
  actual={p.relative_to(R).as_posix() for p in R.rglob('*') if p.is_file() and not set(p.relative_to(R).parts)&{'.git','_work','__pycache__'}}
  if actual!=expected:errors.append('unexpected/missing files: '+str(sorted(actual^expected)))
  counts['manifest_files']=len(rows)
  sums=R/'SHA256SUMS.txt'
  if sums.is_file():
   entries={line.split('  ',1)[1]:line.split('  ',1)[0] for line in sums.read_text(encoding='utf-8').splitlines() if line.strip()}
   if set(entries)!={r['path'] for r in rows}|{'MANIFEST.json'}:errors.append('SHA256SUMS file set')
   for name,h in entries.items():
    q=(R/name).resolve()
    if not q.is_relative_to(R) or not q.is_file() or digest(q)!=h:errors.append('SHA256SUMS: '+name)
  else:errors.append('SHA256SUMS missing')
 result={'result':'FAIL' if errors else 'PASS','checks':counts,'errors':errors,'scope':'byte identity and static references only; not synthesis, timing or hardware validation'}
 if errors:raise RuntimeError(json.dumps(result,ensure_ascii=False,indent=2))
 return result
if __name__=='__main__':print(json.dumps(verify(),ensure_ascii=False,indent=2))
