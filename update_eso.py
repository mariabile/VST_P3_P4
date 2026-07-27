import json
import traceback
import urllib.error
import urllib.parse
import urllib.request

PROGRAM_ID = "114.27U3.001"
clean_id = PROGRAM_ID.lstrip("0")

# Correct column for exposure start time in dbo.raw is 'exp_start'
query = f"SELECT target, instrument, exp_start, tel_airm_start, tel_ambi_fwhm_start FROM dbo.raw WHERE (prog_id LIKE '%{clean_id}%' OR prog_id LIKE '%{PROGRAM_ID}%') AND dp_cat = 'SCIENCE' ORDER BY exp_start ASC"

print(f"Connecting to ESO TAP service for program {PROGRAM_ID}...")

url = "https://archive.eso.org/tap_obs/sync"
params = {
    "REQUEST": "doQuery",
    "LANG": "ADQL",
    "FORMAT": "json",
    "QUERY": query,
}

data_bytes = urllib.parse.urlencode(params).encode("utf-8")
req = urllib.request.Request(
    url,
    data=data_bytes,
    headers={
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        ),
        "Content-Type": "application/x-www-form-urlencoded",
    },
)

try:
    with urllib.request.urlopen(req, timeout=60) as response:
        content = response.read().decode("utf-8")
        data = json.loads(content)

        # Write query result to data.json
        with open("data.json", "w") as f:
            json.dump(data, f, indent=2)

        record_count = len(data.get("data", []))
        print(
            f"Successfully updated data.json! Saved {record_count} observation"
            " records."
        )

except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.reason}")
    print("Response body:", e.read().decode("utf-8", errors="ignore"))
    traceback.print_exc()
    exit(1)
except Exception as e:
    print(f"Error fetching data from ESO: {e}")
    traceback.print_exc()
    exit(1)
