#!/usr/bin/env python3
"""Regenerate hero/ability Warcraft III Object Editor binary data for 12-role Arena.

Reads checked-in source objects, preserving all non-roster records. Clones existing
Channel spell templates to add the eight new Q/W/E/R actions and updates the
ten existing custom heroes; creates two skeleton heroes without modifying JASS.
"""
from __future__ import annotations
import copy
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "object-data/party_heroes.json"

def parse(path: Path, levelled: bool):
    buf = path.read_bytes()
    at=0
    def grab(n):
        nonlocal at
        if at+n>len(buf): raise ValueError(f"Unexpected EOF in {path}")
        val=buf[at:at+n]; at+=n
        return val
    def number(): return struct.unpack("<I",grab(4))[0]
    version=number()
    groups=[]
    for _ in range(2):
        entries=[]
        for _ in range(number()):
            base=grab(4).decode("ascii")
            uid=grab(4).decode("ascii")
            mods=[]
            for _ in range(number()):
                field=grab(4).decode("ascii")
                typ=number()
                rank=number() if levelled else None
                data=number() if levelled else None
                if typ==3:
                    end=buf.find(bytes((0,)),at)
                    if end<0: raise ValueError("Bad unterminated string")
                    val=buf[at:end].decode("utf-8")
                    at=end+1
                elif typ==0: val=struct.unpack("<i",grab(4))[0]
                elif typ in (1,2): val=struct.unpack("<f",grab(4))[0]
                else: raise ValueError(f"Unexpected field type {typ}")
                original=grab(4).decode("ascii")
                mods.append(dict(field=field,type=typ,rank=rank,data=data,val=val,original=original))
            entries.append(dict(base=base,id=uid,mods=mods))
        groups.append(entries)
    if at!=len(buf): raise ValueError("Trailing bytes in object data")
    return version,groups

def encode(path,version,groups,levelled):
    out=bytearray()
    def u(v): out.extend(struct.pack("<I",v))
    u(version)
    for group in groups:
        u(len(group))
        for entry in group:
            out.extend(entry["base"].encode("ascii"))
            out.extend(entry["id"].encode("ascii"))
            u(len(entry["mods"]))
            for mod in entry["mods"]:
                out.extend(mod["field"].encode("ascii"))
                u(mod["type"])
                if levelled:
                    u(mod["rank"])
                    u(mod["data"])
                if mod["type"]==3: out.extend(mod["val"].encode("utf-8")+bytes((0,)))
                elif mod["type"]==0: out.extend(struct.pack("<i",int(mod["val"])))
                else: out.extend(struct.pack("<f",float(mod["val"])))
                out.extend(mod["original"].encode("ascii"))
    path.write_bytes(out)

def field(entry,key,val,rank=None,typ=None):
    hit=False
    for mod in entry["mods"]:
        if mod["field"]==key and (rank is None or mod["rank"]==rank):
            mod["val"]=val
            if typ is not None: mod["type"]=typ
            hit=True
    if not hit:
        entry["mods"].append(dict(
            field=key,type=typ if typ is not None else (3 if isinstance(val,str) else 0),
            rank=rank if rank is not None else 0,data=0,val=val,original=entry["id"]
        ))

def clone(source,new_id,base=None):
    obj=copy.deepcopy(source)
    obj["id"]=new_id
    if base: obj["base"]=base
    for m in obj["mods"]: m["original"]=new_id
    return obj

def generate(root):
    manifest=json.loads((root/"object-data/party_heroes.json").read_text())
    heroes=manifest["heroes"]
    if len(heroes)!=12: raise ValueError("Expected 12 heroes")
    ids=[h["id"] for h in heroes]
    skills=[skill for h in heroes for skill in h["skills"]]
    if len(set(ids))!=12 or len(skills)!=48 or len({s["id"] for s in skills})!=48:
        raise ValueError("IDs or skill count incorrect")
    v,groups=parse(root/"war3map.w3u",False)
    custom=groups[1]
    by_id={e["id"]:e for e in custom}
    if not all(id in by_id for id in ids[:10]): raise ValueError("Missing original heroes")
    for hero in heroes:
        ident=hero["id"]
        existing=by_id.get(ident)
        if existing is None:
            template=by_id["U002"]
            existing=clone(template,ident,hero["base"])
            custom.append(existing)
            by_id[ident]=existing
        field(existing,"unam",hero["name"])
        field(existing,"upro",hero["proper"])
        field(existing,"utip",hero["role"])
        field(existing,"utub",hero["role"]+" / "+hero["attack"]+" / QWER class")
        # Preserve inventory ability and only give QWER through Lua.
        existing_list=next((m["val"] for m in existing["mods"] if m["field"]=="uabi" and isinstance(m["val"],str)),"")
        all_qwer={entry["id"] for h in heroes for entry in h["skills"]}
        innate=[a.strip() for a in existing_list.split(",") if a.strip() and a.strip() not in all_qwer]
        if "AInv" not in innate: innate.append("AInv")
        field(existing,"uabi",",".join(innate))
        values=hero["stats"]
        for key,val in (
            ("ustr",values["str"]),("uagi",values["agi"]),("uint",values["int"]),
            ("ustp",values["strGain"]),("uagp",values["agiGain"]),("uinp",values["intGain"]),
            ("uhpm",values["hp"]),("umpm",values["mana"])
        ):
            field(existing,key,val,typ=1 if key in ("ustp","uagp","uinp") else 0)
        if hero.get("model"): field(existing,"umdl",hero["model"])
        if hero.get("unitIcon"): field(existing,"uico",hero["unitIcon"])
        # ua1w is a STRING weapon kind (normal/missile), NOT attack speed.
        # The incorrect former float wrote 1.9 into a weapon enum field and
        # caused broken basic attacks on Gelo and potentially other heroes.
        is_ranged=hero["attack"]=="ranged"
        field(existing,"uaen",1,typ=0)  # Attack 1 is enabled.
        field(existing,"ua1w","missile" if is_ranged else "normal",typ=3)
        field(existing,"ua1t","pierce" if is_ranged else "hero",typ=3)
        field(existing,"ua1c",1.85 if is_ranged else 1.75,typ=1)
        field(existing,"ua1r",650 if is_ranged else 128,typ=0)
        field(existing,"ua1b",19 if is_ranged else 24,typ=0)
        field(existing,"ua1d",2,typ=0)
        field(existing,"ua1s",6,typ=0)
        if is_ranged:
            field(existing,"ua1m",r"Abilities\Weapons\Arrow\ArrowMissile.mdl",typ=3)
            field(existing,"ua1z",1200,typ=0)  # Missile speed in units/sec.
    encode(root/"war3map.w3u",v,groups,False)

    av,ability_groups=parse(root/"war3map.w3a",True)
    custom_spells=ability_groups[1]
    spell_by_id={e["id"]:e for e in custom_spells}
    spell_template=spell_by_id.get("A11D") or custom_spells[0]
    commands=["thunderclap","roar","fanofknives","berserk"]
    for hero in heroes:
        for k,skill in enumerate(hero["skills"]):
            ident=skill["id"]
            obj=spell_by_id.get(ident)
            if obj is None:
                template=spell_by_id.get(heroes[0]["skills"][k]["id"],spell_template)
                obj=clone(template,ident)
                custom_spells.append(obj)
                spell_by_id[ident]=obj
            for rank in range(1,6):
                tag=f"{skill['name']} |cffc0c0c0[ур. {rank}]|r"
                body=(f"{skill['description']} |n|nУрон физических навыков: +1.5% за Силу."
                      if skill["type"]=="physical" else
                      f"{skill['description']} |n|nМагия и лечение: +2% за Интеллект.")
                for key,val,typ in (
                    ("anam",skill["name"],3),
                    ("atp1",tag,3),("aub1",body,3),
                    ("aart",skill["icon"],3),
                    ("ahky",skill["key"],3),
                    ("amcs",int(skill["mana"]),0),
                    ("acdn",float(skill["cooldown"]),1),
                    ("Ncl1",0.0,1),
                    ("Ncl4",0.0,1)
                ):
                    field(obj,key,val,rank,typ=typ)
                field(obj,"alev",5,typ=0)
                field(obj,"abpx",k,typ=0)
                field(obj,"abpy",2,typ=0)
                # Set Channel order ID for each of the four separate orders.
                field(obj,"Ncl6",commands[k],rank,typ=3)
            # Keep rank-dependent editor data, but overwrite all cooldowns and costs.
    encode(root/"war3map.w3a",av,ability_groups,True)
    return len(custom),len(custom_spells)

if __name__=="__main__":
    a,b=generate(ROOT)
    print(f"Generated Warcraft objects: {a} custom heroes, {b} custom spells")
