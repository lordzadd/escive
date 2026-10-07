"""Read recent diagnostics without putting credentials in shell arguments."""
import json
from pathlib import Path
from urllib.request import Request, urlopen

root = Path(__file__).resolve().parent.parent
config = json.loads((root / '.diagnostics/build.json').read_text())
credentials = json.loads((root / '.diagnostics/credentials.json').read_text())
request = Request(config['DIAGNOSTICS_URL'], headers={
    'Authorization': 'Bearer ' + credentials['read'],
})
with urlopen(request, timeout=15) as response:
    print(json.dumps(json.load(response), indent=2))
