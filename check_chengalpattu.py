import json

with open('backend/app/data/road_network_data.json') as f:
    data = json.load(f)

# Count roads with Chengalpattu in districts
cheng = [r for r in data if 'Chengalpattu' in r.get('districts', [])]

print(f'Total roads with Chengalpattu: {len(cheng)}')
print('\nRoads:')
for r in cheng:
    print(f"  {r['id']} - {r['name']}")
