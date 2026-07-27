from datetime import datetime, timedelta
import json
import os
import traceback
import urllib.error
import urllib.parse
import urllib.request
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

PROGRAM_ID = "114.27U3.001"
clean_id = PROGRAM_ID.lstrip("0")


def load_colors():
    """Loads colors.json if present, otherwise returns default color dictionary."""
    json_path = "colors.json"
    if os.path.exists(json_path):
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"Warning: Could not read {json_path} ({e}). Using default.")

    return {
        "J0501": "#c8a6f5",
        "J0542": "#88bef7",
        "J0722": "#88f7dd",
        "J1029": "#88f78e",
        "J2107": "#f5f1a6",
        "J0335": "#ffc185",
        "J1330": "#ff9f7a",
        "J0123": "#e4574f",
        "J2329": "#ff7f66",
    }


def get_target_color(target_name, color_map):
    """Matches target name against loaded color map."""
    for key, hex_color in color_map.items():
        # Match either key (e.g., 'J1330') or number part ('1330')
        clean_key = key.replace("J", "")
        if key in target_name or clean_key in target_name:
            return hex_color
    return "#ffffff"  # Default white for unmapped targets


def parse_utc_dt(utc_str):
    """Parses ESO UTC date string into a datetime object with -12h observing night offset."""
    clean_str = str(utc_str)[:19]
    dt = datetime.strptime(clean_str, "%Y-%m-%dT%H:%M:%S")
    return dt - timedelta(hours=12)


def generate_timeline_plot(observations):
    """Generates and saves the dark-themed timeline figure matching obs_timeline.py."""
    if not observations:
        print("No observations available to generate timeline plot.")
        return

    color_map = load_colors()

    # Parse observations into DataFrame
    data_list = []
    for row in observations:
        target = row[0].strip() if row[0] else "Unknown"
        exp_start = row[2]
        if exp_start:
            dt_display = parse_utc_dt(exp_start)
            data_list.append({"object": target, "dt_display": dt_display})

    df = pd.DataFrame(data_list)
    if df.empty:
        print("No valid timestamps found for timeline plot.")
        return

    # Determine chronological order by first observation time per object
    objects_sorted = (
        df.groupby("object")["dt_display"]
        .min()
        .sort_values(kind="mergesort")
        .index.astype(str)
        .tolist()
    )

    y_map = {obj: i for i, obj in enumerate(objects_sorted)}
    y_vals = df["object"].map(y_map)

    # Plot styling setup
    fig, ax = plt.subplots(figsize=(12, max(4, len(objects_sorted) * 0.4)))

    # Get colors per observation point
    colors = [
        get_target_color(obj, color_map) for obj in df["object"].values
    ]

    # Scatter plot
    ax.scatter(
        df["dt_display"].values,
        y_vals.values,
        s=16.0,
        alpha=1,
        edgecolor="none",
        c=colors,
    )

    # Format Axes
    ax.set_yticks(list(y_map.values()), list(y_map.keys()))
    ax.set_xlabel("Date (UTC)", labelpad=10)
    ax.set_ylabel("Target", labelpad=10)

    # X-axis date formatting (monthly ticks)
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    fig.autofmt_xdate()

    # Apply Dark Aesthetics (matching obs_timeline.py)
    fig.patch.set_facecolor("black")
    ax.set_facecolor("black")
    ax.xaxis.label.set_color("white")
    ax.yaxis.label.set_color("white")
    ax.tick_params(axis="x", colors="white")
    ax.tick_params(axis="y", colors="white")

    for spine in ax.spines.values():
        spine.set_color("white")

    # Ensure output directory exists and save
    os.makedirs("images", exist_ok=True)
    out_png = os.path.join("images", "P3_P4_timeline.png")
    fig.savefig(out_png, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print(f"Successfully generated and saved plot to: {out_png}")


# --- Main Data Sync Execution ---
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

        observations = data.get("data", [])

        # --- Automatic Name Replacement ---
        # Replaces COOL 1330 / COOL J1330 with SDSS 1330 / SDSS J1330 in all records
        for row in observations:
            if row[0]:
                row[0] = row[0].replace("COOL 1330", "SDSS 1330").replace("COOL J1330", "SDSS J1330")

        # 1. Save modified JSON dataset (table reads from this)
        with open("data.json", "w") as f:
            json.dump(data, f, indent=2)

        print(f"Saved {len(observations)} observation records to data.json.")

        # 2. Generate updated timeline plot (plot reads from this)
        generate_timeline_plot(observations)

except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.reason}")
    print("Response body:", e.read().decode("utf-8", errors="ignore"))
    traceback.print_exc()
    exit(1)
except Exception as e:
    print(f"Error executing script: {e}")
    traceback.print_exc()
    exit(1)
