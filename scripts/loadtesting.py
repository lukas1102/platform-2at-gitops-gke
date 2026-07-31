#!/usr/bin/env python3

import argparse
import json
import os
import statistics
import time
import urllib.error
import urllib.request
import webbrowser

DEFAULT_URL = "https://planka.plateng.fhbgl.study"


def send_request(url, timeout):
    """Send a single GET request and return (status_code, response_time_ms, error)."""
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            status_code = response.status
            response.read()  # drain body so the connection is fully timed
        error = None
    except urllib.error.HTTPError as exc:
        status_code = exc.code
        error = str(exc)
    except urllib.error.URLError as exc:
        status_code = None
        error = str(exc)
    elapsed_ms = (time.perf_counter() - start) * 1000
    return status_code, elapsed_ms, error


def run_load_test(url, duration, interval, timeout):
    results = []
    start_time = time.monotonic()

    while (time.monotonic() - start_time) < duration:
        request_start = time.monotonic() - start_time
        status_code, elapsed_ms, error = send_request(url, timeout)
        success = status_code is not None and 200 <= status_code < 400
        results.append(
            {
                "elapsed_s": round(request_start, 2),
                "status_code": status_code if status_code else "ERROR",
                "response_time_ms": round(elapsed_ms, 2),
                "success": success,
                "error": error or "",
            }
        )
        print(
            f"[{request_start:6.2f}s] status={status_code or 'ERROR':>5} "
            f"time={elapsed_ms:7.2f}ms {'OK' if success else 'FAIL'}"
        )

        # sleep for the remainder of the interval, if any is left
        time_spent = time.monotonic() - start_time - request_start
        sleep_time = interval - time_spent
        if sleep_time > 0:
            time.sleep(sleep_time)

    return results


def print_summary(results):
    times = [r["response_time_ms"] for r in results]
    successes = [r for r in results if r["success"]]

    print("\n--- Summary ---")
    print(f"Total requests : {len(results)}")
    print(f"Successful     : {len(successes)}")
    print(f"Failed         : {len(results) - len(successes)}")
    if times:
        print(f"Min time (ms)  : {min(times):.2f}")
        print(f"Max time (ms)  : {max(times):.2f}")
        print(f"Avg time (ms)  : {statistics.mean(times):.2f}")
        if len(times) > 1:
            print(f"Stdev (ms)     : {statistics.stdev(times):.2f}")


def plot_results(results, chart_path):
    elapsed = [r["elapsed_s"] for r in results]
    times = [r["response_time_ms"] for r in results]
    point_colors = [
        "#2e7d32" if r["success"] else "#c62828" for r in results
    ]

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Planka Load Test</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
  body {{ font-family: sans-serif; margin: 2rem; }}
  #chart {{ max-width: 1000px; }}
</style>
</head>
<body>
<h1>Planka Load Test - Responses Over Time</h1>
<canvas id="chart"></canvas>
<script>
const labels = {json.dumps(elapsed)};
const data = {json.dumps(times)};
const pointColors = {json.dumps(point_colors)};
new Chart(document.getElementById('chart'), {{
  type: 'line',
  data: {{
    labels: labels,
    datasets: [{{
      label: 'Response time (ms)',
      data: data,
      borderColor: 'steelblue',
      borderWidth: 1,
      pointBackgroundColor: pointColors,
      pointBorderColor: pointColors,
      pointRadius: 3,
      tension: 0.1
    }}]
  }},
  options: {{
    scales: {{
      x: {{ title: {{ display: true, text: 'Elapsed time (s)' }} }},
      y: {{ title: {{ display: true, text: 'Response time (ms)' }}, beginAtZero: true }}
    }}
  }}
}});
</script>
</body>
</html>
"""

    with open(chart_path, "w") as f:
        f.write(html)
    print(f"Chart written to {chart_path}")
    webbrowser.open(f"file://{os.path.abspath(chart_path)}")


def main():
    parser = argparse.ArgumentParser(description="Simple load test for Planka")
    parser.add_argument("--url", default=DEFAULT_URL, help="URL to test")
    parser.add_argument("--duration", type=int, default=60, help="Total test duration in seconds")
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds between requests")
    parser.add_argument("--timeout", type=float, default=10.0, help="Request timeout in seconds")
    parser.add_argument("--chart", default="load_test_chart.html", help="Path to save the HTML chart")
    args = parser.parse_args()

    print(f"Load testing {args.url} for {args.duration}s (every {args.interval}s)...\n")
    results = run_load_test(args.url, args.duration, args.interval, args.timeout)

    print_summary(results)
    plot_results(results, args.chart)


if __name__ == "__main__":
    main()