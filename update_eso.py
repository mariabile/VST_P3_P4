from datetime import datetime, timedelta
import json
import os
import traceback
import urllib.error
import urllib.parse
import urllib.request
import matplotlib.dates as mdates
import matplotlib.pyplot as plt

PROGRAM_ID = "114.27U3.001"
clean_id = PROGRAM_ID.lstrip("0")

# Color map provided for targets
COLOR_MAP = {
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


def get_observing_night(utc_str):
    """Offset timestamp by -12 hours to align post-midnight exposures with the observing night."""
    dt = datetime.strptime(utc_str.split(".")[0], "%Y-%m-%dT%H:%M:%S")
    offset_dt = dt - timedelta(hours=12)
    return offset_dt.date()


def get_target_color(target_name):
    """Matches target name against custom color dictionary."""
    for prefix, hex_color in COLOR_MAP.items():
        if prefix in target_name:
            return hex_color
    return "#888888"  # Fallback gray for unlisted targets


def generate_timeline_plot(observations):
    """Generates and saves the timeline figure using matplotlib."""
    if not observations:
        print("No observations available to generate timeline plot.")
        return

    # Extract unique (date, target) pairs
    night_records = []
    for row in observations:
        target = row[0].strip() if row[0] else "Unknown"
        obs_date = get_observing_night(row[2])
        night_records.append((obs_date, target))

    # Get unique sorted targets and dates
    unique_targets = sorted(list(set(t for _, t in night_records)))
    unique_dates = sorted(list(set(d for d, _ in night_records)))

    # Set up plot styling
    fig, ax = plt.subplots(figsize=(12, max(4, len(unique_targets) * 0.6)))
    ax.set_facecolor("#f8fafc")
    fig.patch.set_facecolor("#ffffff")

    # Plot observation points for each target
    for target in unique_targets:
        target_dates = [d for d, t in night_records if t == target]
        target_color = get_target_color(target)

        y_vals = [target] * len(target_dates)
        ax.scatter(
            target_dates,
            y_vals,
            color=target_color,
            s=120,
            edgecolors="#333333",
            linewidth=0.8,
            zorder=3,
            label=target,
        )

    # Format Axes
    ax.set_title(
        f"VST Program {PROGRAM_ID} - Observation Timeline",
        fontsize=14,
        fontweight="bold",
        pad=15,
        color="#003366",
    )
    ax.set_xlabel("Observing Date", fontsize=11, fontweight="bold", labelpad=10)
    ax.set_ylabel("Target", fontsize=11, fontweight="bold", labelpad=10)

    # Date formatting on X-axis
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m-%d"))
    ax.xaxis.set_major_locator(mdates.AutoDateLocator())
    fig.autofmt_xdate()

    # Gridlines & Spacing
    ax.grid(True, linestyle="--", alpha=0.5, color="#cbd5e1", zorder=1)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#94a3b8")
    ax.spines["bottom"].set_color("#94a3b8")

    plt.tight_layout()

    # Ensure images/ folder exists and save plot
    os.makedirs("images", exist_ok=True)
    plot_path = os.path.join("images", "P3_P4_timeline.png")
    plt.savefig(plot_path, dpi=200, bbox_inches="tight")
    plt.close()
    print(f"Successfully updated timeline plot at '{plot_path}'!")


# Main Execution
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

        # 1. Save JSON dataset
        with open("data.json", "w") as f:
            json.dump(data, f, indent=2)

        observations = data.get("data", [])
        print(f"Saved {len(observations)} observation records to data.json.")

        # 2. Re-generate P3_P4_timeline.png with custom colors
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
