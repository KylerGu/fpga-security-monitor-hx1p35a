"""Portable isolated TD/ModelSim entry points; never overwrite the released bit."""
from pathlib import Path
import argparse,datetime,hashlib,json,os,re,shutil,subprocess,tempfile
from concurrent.futures import ThreadPoolExecutor
from verify import R,verify

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('action',choices=['elaborate','build','simulate'])
 parser.add_argument('--td-root',default=os.environ.get('TD_ROOT'))
 parser.add_argument('--vsim',default=os.environ.get('VSIM'))
 parser.add_argument('--work',type=Path,required=True,help='New empty directory, outside this release')
 parser.add_argument('--jobs',type=int,default=2)
 args=parser.parse_args();verify()
 if not args.td_root:parser.error('set TD_ROOT or pass --td-root')
 td=Path(args.td_root).resolve()
 if not (td/'bin/td_commands_prompt.exe').is_file():parser.error('invalid TD root')
 if args.action=='simulate':
  expected=json.loads((R/'metadata/external_model_hashes.json').read_text(encoding='utf-8'))['sha256']
  for name,digest in expected.items():
   model=td/'sim_release/ph1p'/name
   if not model.is_file() or hashlib.sha256(model.read_bytes()).hexdigest()!=digest:parser.error('missing or different frozen vendor simulation model: '+name)
 w=args.work.resolve()
 if w.exists():parser.error('--work must not exist (no reuse of old logs or databases)')
 if w.is_relative_to(R):parser.error('work must be outside the delivered release')
 w.mkdir(parents=True);p=w/'project';shutil.copytree(R/'project',p)
 al=p/'td_project/camera_to_dsi_display.al'
 raw=al.read_bytes();raw=re.sub(rb'(<Project\b[^>]*\bPath=")[^"]*(")',lambda m:m[1]+al.parent.as_posix().encode()+m[2],raw,count=1);al.write_bytes(raw)
 env=os.environ.copy();env['TD_ROOT']=td.as_posix()
 def run(exe,script,cwd,log,marker,timeout=2400):
  private=Path(tempfile.mkdtemp(prefix='tmp_',dir=w));e=env.copy();e.update(TEMP=str(private),TMP=str(private))
  with log.open('w',encoding='utf-8') as out:
   proc=subprocess.run([str(exe),*script],cwd=cwd,env=e,stdout=out,stderr=subprocess.STDOUT,timeout=timeout)
  text=log.read_text(errors='replace')
  if proc.returncode or marker not in text or re.search(r'\*\* (?:Error|Fatal)|SIMULATION_FAIL|Errors:\s*[1-9]|(?m:^[A-Z]+-\d+\s+(?:ERROR|FATAL)\b)',text):raise RuntimeError('failed: '+str(log))
  return {'log':str(log.relative_to(w)),'sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'result':'PASS'}
 records=[]
 if args.action in ['elaborate','build']:
  exe=td/'bin/td_commands_prompt.exe';folder=p/'td_project'
  if args.action=='elaborate':
   text=(folder/'compile_security.tcl').read_text(encoding='utf-8').split('commit_param -step rtl')[0]
   (folder/'delivery_elaborate.tcl').write_text(text+'\nputs "DELIVERY_ELABORATION_COMPLETE"\nclose_project\nexit\n')
   records.append(run(exe,[(folder/'delivery_elaborate.tcl').as_posix()],p,w/'elaborate.log','DELIVERY_ELABORATION_COMPLETE'))
  else:
   records.append(run(exe,[(folder/'compile_security.tcl').as_posix()],p,w/'build.log','SECURITY_ROUTED_COMPLETE',7200))
   records.append(run(exe,[(folder/'bitgen_security.tcl').as_posix()],p,w/'bitgen.log','SECURITY_BITGEN_COMPLETE'))
   bit=folder/'security_build/security_monitor_720p_ddr_fix.bit'
   if not bit.is_file() or bit.stat().st_size<1000000:raise RuntimeError('missing build bit')
   records.append({'rebuilt_bit':str(bit.relative_to(w)),'sha256':hashlib.sha256(bit.read_bytes()).hexdigest(),'release_qualification':'NOT_PERFORMED; inspect timing, CDC reports and hardware before use'})
 else:
  if not args.vsim or not Path(args.vsim).is_file():parser.error('set VSIM or pass --vsim')
  groups=json.loads((R/'metadata/test_groups.json').read_text(encoding='utf-8'))
  # This harness is the exact integration fragment from the frozen top module.
  top=(p/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf-8')
  start=top.index('    (* async_reg="true" *)reg[3:0]S_led_sync1,S_led_sync2;')
  end=top.index('      .buzzer_n(O_buzzer_n));',start)+len('      .buzzer_n(O_buzzer_n));')
  (p/'simulation/buzzer/production_buzzer_path.v').write_text('module production_buzzer_path(input wire I_sys_clk,S_rst_sys,input wire S_capture_overflow,S_camera_interrupted,S_camera_armed,S_camera_alarm,input wire[63:0]S_control,output wire[3:0]O_security_led,output wire O_buzzer_n);\n'+top[start:end]+'\nendmodule\n')
  def group(item):
   name,tests=item;out=[]
   for script,log in tests:
    folder=p/'simulation'/name
    out.append(run(args.vsim,['-c','-do',script],folder,folder/log,'End time:' if 'syntax' in log else 'SIMULATION_PASS'))
    print('PASS '+name+'/'+script,flush=True)
   return out
  with ThreadPoolExecutor(max_workers=max(1,args.jobs)) as pool:
   for rows in pool.map(group,groups.items()):records.extend(rows)
  reference=json.loads((R/'project/simulation/render/reference_frame.json').read_text(encoding='utf-8'))
  rgb=bytes.fromhex(''.join((p/'simulation/render/actual.hex').read_text(encoding='utf-8').splitlines()))
  if len(rgb)!=reference['pixel_count']*3 or hashlib.sha256(rgb).hexdigest()!=reference['rgb_sha256']:raise RuntimeError('Full-frame render content/alignment changed')
  print('PASS render frame identity (921600 pixels)',flush=True)
  ip=p/'user_source/hdl_source/ph1p35_ddr/ddr2';rtl=ip/'src/rtl';folder=p/'simulation/ddr_clock'
  v=dict(re.findall(r'\.(\w+)\(\s*([^\n()]*)\s*\)',(ip/'ddr2.v').read_text(encoding='utf-8')))
  params=',\n'.join('.'+k+'('+value+')' for k,value in v.items() if k.startswith('PLL'))
  (folder/'generated_instance.vh').write_text('ph1p_ddrphy_clk_top #(\n'+params+'\n) dut(.sys_rst(rst),.ref_clk(refclk),.cfg_clk(cfg),.dhi_clk(userclk),.ctl_clk(ctl),.ddr_clk(ddr),.pll_lock(locked));\nlocalparam tCK='+v['tCK']+';\n')
  def tq(path):return '{'+Path(path).as_posix()+'}'
  models=[td/'sim_release/ph1p'/(n+'.v') for n in ['ph1p_phy_pll_v2','ph1p_phy_mlclk','ph1p_phy_ioclk','ph1p_logic_bufg','ph1p_phy_gsr']]
  commands=['onerror {quit -code 1 -force}','vlib work','vmap work work','vlog '+' '.join(map(tq,models)),'vlog +define+PH1P35 '+' '.join(map(tq,sorted((rtl/'clk').glob('*.v')))),'vlog -sv {+incdir+'+(rtl/'include').as_posix()+'} {+incdir+'+(rtl/'timing/ddr2').as_posix()+'} tb.v','vsim -voptargs=+acc work.tb work.PH1P_PHY_GSR','run -all','quit -code 0 -force']
  (folder/'run_generated.do').write_text('\n'.join(commands)+'\n')
  records.append(run(args.vsim,['-c','-do','run_generated.do'],folder,folder/'clock.log','SIMULATION_PASS ddr_clock',600))
  print('PASS ddr_clock',flush=True)
 verify()
 result={'action':args.action,'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'result':'PASS','records':records,'td_root':str(td),'scope':'elaboration only' if args.action=='elaborate' else ('35 functional + 1 syntax + DDR clock simulation; no full DRAM protocol or hardware tests' if args.action=='simulate' else 'tool flow only; timing/hardware acceptance not asserted')}
 (w/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'result':'PASS','action':args.action,'records':len(records),'work':str(w)}),flush=True)
if __name__=='__main__':main()
