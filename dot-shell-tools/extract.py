import re,sys
# extract.py <dot-shell-panels.html> <outdir> <ERA HEADER WORD, e.g. GAME>: one era column per board -> <board>-<n>.html
src=open(sys.argv[1]).read(); out=sys.argv[2]
import os; os.makedirs(out, exist_ok=True)
head=src.split('<body')[0]
links='\n'.join(re.findall(r'<link[^>]*>',head))
secs=re.split(r'<section id="',src)[1:]
for s in secs:
    sid=s.split('"')[0]
    figs=re.split(r'<figure><figcaption>',s)[1:]
    for i,f in enumerate(figs):
        labs=list(re.finditer(r'<div style="font-family: \'Silkscreen\', monospace; font-size: 11px; letter-spacing: 2px; color: #8a8a96">([^<]*)</div>',f))
        for j,m in enumerate(labs):
            if m.group(1).startswith(sys.argv[3]):
                end=labs[j+1].start() if j+1<len(labs) else len(f)
                chunk=f[m.start():end]
                # balance: chunk begins mid-div; wrap
                open(f'{out}/{sid}-{i}.html','w').write(f'<!doctype html><html><head><meta charset=utf-8>{links}<style>body{{margin:0;background:#101014;padding:20px}}</style></head><body><div style="display:flex;flex-direction:column;gap:10px">'+chunk+'</div></body></html>')
