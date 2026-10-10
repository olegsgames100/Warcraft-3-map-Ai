#!/usr/bin/env python3
"""Print and validate real (generated) Warcraft Channel ability metadata."""
from pathlib import Path
import json
from tools.generate_party_objects import parse

root=Path(".")
heroes=json.loads((root/"object-data/party_heroes.json").read_text())["heroes"]
_,groups=parse(root/"war3map.w3a",True)
by_id={obj["id"]:obj for group in groups for obj in group}
for hero in heroes:
    line=[]
    for k,skill in enumerate(hero["skills"]):
        obj=by_id[skill["id"]]
        summary={}
        for field in ("Ncl1","Ncl2","Ncl3","Ncl4","Ncl5","Ncl6","alev","amcs","acdn","aord","ahky","abpx","abpy","aran","atar","aare","acat","anam","aart","atp1"):
            matching=[m for m in obj["mods"] if m["field"]==field and (m["rank"] in (1,0,None))]
            if matching: summary[field]=[(m["rank"],m["type"],m["val"],m["data"]) for m in matching[:3]]
        line.append({"id":skill["id"],"base":obj["base"],"slot":"QWER"[k],"fields":summary})
    print(json.dumps({"hero":hero["name"],"abilities":line},ensure_ascii=False,default=str))
