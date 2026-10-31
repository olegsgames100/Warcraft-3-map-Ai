"""Synchronize shops and craftable gear with UPDATES.md. Stats are applied by Lua."""
import struct
from pathlib import Path
from set_hero_models import read_objects,write_objects
ROOT=Path(__file__).resolve().parents[1]
# raw, base, name, gold, icon, description, Lua stats
GEAR=[
('rng1','rng1','Кольцо Закалки',350,'BTNRingGreen','+4 брони.',{'armor':4}),
('belv','belv','Пояс Титана',450,'BTNBelt','+6 силы.',{'str':6}),
('boot','boot','Сапоги Ветра',450,'BTNBoots','+55 скорости передвижения.',{'move':55}),
('rat6','rat6','Клинок Остроты',450,'BTNClawsOfAttack','+14 урона атаки.',{'damage':14}),
('glov','glov','Перчатки Проворства',400,'BTNGlove','+15% скорости атаки, +3 ловкости.',{'as':.15,'agi':3}),
('I0MA','pman','Амулет Маны',400,'BTNPendantOfMana','+150 маны, +1 маны/сек.',{'mana':150,'mpreg':1}),
('prt5','prt5','Кристалл Жизни',425,'BTNPeriapt','+200 здоровья, +2,5 HP/сек.',{'hp':200,'hpreg':2.5}),
('I000','rin1','Мантия Мудреца',450,'BTNRobeOfTheMagi','+6 интеллекта.',{'int':6}),
('I001','boot','Сапоги Скитальца',850,'BTNBootsOfSpeed','Сапоги Ветра + Перчатки Проворства.|n+70 скорости, +20% скорости атаки, +5 ко всем характеристикам.',{'move':70,'as':.2,'str':5,'agi':5,'int':5}),
('I002','rng1','Каменный Бастион',775,'BTNHumanArmorUpOne','Кольцо Закалки + Кристалл Жизни.|n+6 брони, +300 HP, +4 HP/сек. Блок 25 урона обычных атак.',{'armor':6,'hp':300,'hpreg':4,'block':25}),
('I003','rat6','Жало Пустоты',850,'BTNDaggerOfEscape','Клинок Остроты + Перчатки Проворства.|n+22 урона, +20% скорости атаки, +6 ловкости. Попадание отравляет: 12 урона/сек на 3 секунды.',{'damage':22,'as':.2,'agi':6,'poison':12}),
('I004','rin1','Кодекс Тайной Магии',850,'BTNTome','Мантия Мудреца + Амулет Маны.|n+10 интеллекта, +250 маны, +2,5 маны/сек.',{'int':10,'mana':250,'mpreg':2.5}),
('I005','rng1','Эгида Несокрушимости',2400,'BTNDivineIntervention','Каменный Бастион + Сердце Голема.|n+14 брони, +850 HP, +16 HP/сек. Блок 50 урона обычных атак.',{'armor':14,'hp':850,'hpreg':16,'block':50}),
('I006','rat6','Погибель Миров: Клык Королевы',2400,'BTNOrbOfCorruption','Жало Пустоты + Хелицера Королевы Яда.|n+55 урона, +35% скорости атаки. Яд: 18 урона/сек за стак, до 5 стаков, 3 секунды.',{'damage':55,'as':.35,'poison':18,'poisoncap':5}),
('I007','rat6','Секира Пекла',2400,'BTNFireRocks','Клинок Остроты + Пояс Титана + Пылающий Осколок.|n+60 урона, +20 силы. Атаки наносят 25% урона соседним врагам; огонь вокруг — 25 урона/сек.',{'damage':60,'str':20,'splash':.25,'burn':25}),
('I008','rin1','Астральный Скипетр Времени',2400,'BTNGem','Кодекс Тайной Магии + Око Вечности.|n+32 интеллекта, +500 маны, +15% урона заклинаний. Раз в 45 секунд попадание заклинанием сбрасывает перезарядки Q/W/E.',{'int':32,'mana':500,'magic':.15,'reset':45}),
('I009','boot','Призрачные Поступи',2400,'BTNCloak','Сапоги Скитальца + Мантия Сумерек.|n+100 скорости, +30% скорости атаки, 20% уклонения от обычных атак.',{'move':100,'as':.3,'evasion':20}),
]
RELICS=[('I00G','Сердце Голема','BTNHeartOfAszune'),('I00V','Хелицера Королевы Яда','BTNOrbOfCorruption'),('I00F','Пылающий Осколок Метеорита','BTNFireRocks'),('I00E','Око Вечности','BTNGem'),('I00C','Мантия Сумерек','BTNCloak')]
CONSUMABLES=[('phea',400,'Зелье Лечения','Восстанавливает 250 здоровья. Один заряд.'),('pman',400,'Зелье Маны','Восстанавливает 150 маны. Один заряд.'),('shea',650,'Свиток Исцеления','Восстанавливает 150 здоровья ближайшим союзникам. Один заряд.'),('spro',600,'Свиток Защиты','Повышает броню ближайших союзников на 2 на 30 секунд. Один заряд.'),('hslv',450,'Лечебная Мазь','Восстанавливает 400 здоровья за 45 секунд. Урон прерывает лечение. Один заряд.')]
def fields(changes):
 out=[]
 for f,v in changes:
  k=3 if isinstance(v,str) else (1 if isinstance(v,float) else 0)
  out.append((f.encode(),k,v.encode()+b'\0' if k==3 else struct.pack('<f' if k==1 else '<i',v),b'\0'*4))
 return out
def apply():
 path=ROOT/'war3map.w3t';tables=read_objects(path.read_bytes())
 ids={x[0].encode() for x in GEAR+RELICS+CONSUMABLES}
 tables[0]=[x for x in tables[0] if x[0] not in ids]
 tables[1]=[x for x in tables[1] if x[1] not in ids]
 for raw,base,name,gold,icon,desc,stats in GEAR:
  row=fields([('unam',name),('utip',name),('utub',desc),('ides',desc),('igol',gold),('ilum',0),('iabi',''),('iusa',0),('iuse',0),('iper',0),('ifil',r'Objects\InventoryItems\TreasureChest\treasurechest.mdl'),('iico','ReplaceableTextures/CommandButtons/'+icon+'.blp'),('icla','Permanent'),('isto',4),('istr',20),('isst',0)])
  tables[0 if raw==base else 1].append((base.encode(),b'\0'*4 if raw==base else raw.encode(),row))
 for raw,name,icon in RELICS:
  tables[1].append((b'rng1',raw.encode(),fields([('unam',name),('utip',name),('utub','Реликвия мини-босса. Используется для сборки легендарного артефакта.'),('iabi',''),('iuse',0),('igol',0),('ipaw',0),('iico','ReplaceableTextures/CommandButtons/'+icon+'.blp')])))
 for raw,gold,name,desc in CONSUMABLES:
  tables[0].append((raw.encode(),b'\0'*4,fields([('unam',name),('utip',name),('utub',desc),('igol',gold),('ilum',0),('iuse',1),('iusa',1),('isto',3),('istr',60),('isst',0)])))
 path.write_bytes(write_objects(tables))
 path=ROOT/'war3map.w3u';tables=read_objects(path.read_bytes())
 for raw,name in [('nS01','Лавка Расходников'),('nS02','Кузница Артефактов')]:
  tables[1]=[x for x in tables[1] if x[1]!=raw.encode()]
  tables[1].append((b'ngme',raw.encode(),fields([('unam',name),('utip',name),('uabi','Aneu,Asid,Apit,Avul'),('usei',''),('useu',''),('upat',''),('ucol',0.0),('ubdg',0)])))
 path.write_bytes(write_objects(tables))
 source=(ROOT/'war3map.lua').read_text(encoding='utf-8')
 marker='-- BEGIN ITEM STATS'
 if marker in source:
  begin=source.index(marker);end=source.index('-- END ITEM STATS',begin)+len('-- END ITEM STATS')
  source=source[:begin]+source[end:]
 lines=[marker,'ArenaItemStats = {']
 for raw,base,name,gold,icon,desc,stats in GEAR:
  lines.append("    [FourCC('%s')] = {%s},"%(raw,','.join("['%s']=%s"%(k,v) for k,v in stats.items())))
 lines+=['}','-- END ITEM STATS']
 (ROOT/'war3map.lua').write_text(source+'\n'+'\n'.join(lines)+'\n',encoding='utf-8')
 print('Built consumables, components, 9 artifacts, 5 relics and two shops')
if __name__=='__main__':apply()
