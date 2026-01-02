#!/usr/bin/env python3
"""
Generate comprehensive comparison table of sequential vs random I/O performance.
"""

import re
import sys
from pathlib import Path
from collections import defaultdict
import statistics

def parse_result_file(filepath):
    """Extract sequential and random read/write times from a result file."""
    with open(filepath, 'r') as f:
        content = f.read()

    results = {}

    # Sequential read (after eviction)
    match = re.search(r'"MEASURE: Read temp table block-by-block".*?Execution Time: ([\d.]+) ms', content, re.DOTALL)
    if match:
        results['seq_read'] = float(match.group(1))

    # Sequential write (initial flush)
    match = re.search(r'"MEASURE: Flush the table block-by-block.*?Execution Time: ([\d.]+) ms', content, re.DOTALL)
    if match:
        results['seq_write'] = float(match.group(1))

    # Random read
    match = re.search(r'"MEASURE: Read blocks of the temp table randomly".*?Execution Time: ([\d.]+) ms', content, re.DOTALL)
    if match:
        results['rand_read'] = float(match.group(1))

    # Random write (flush after random read) - last flush in file
    matches = list(re.finditer(r'Function Scan on pg_flush_local_buffers.*?Execution Time: ([\d.]+) ms', content, re.DOTALL))
    if len(matches) >= 4:
        results['rand_write'] = float(matches[-1].group(1))

    return results

def remove_outliers(values):
    """Remove values beyond 2 standard deviations from mean."""
    if len(values) < 3:
        return values
    mean = statistics.mean(values)
    stdev = statistics.stdev(values)
    return [v for v in values if abs(v - mean) <= 2 * stdev]

def main():
    results_dir = Path('results')

    # Collect results by block size
    data_by_blocks = defaultdict(lambda: {
        'seq_read': [],
        'seq_write': [],
        'rand_read': [],
        'rand_write': []
    })

    for res_file in sorted(results_dir.glob('blocks-*-iter-*.res')):
        match = re.match(r'blocks-(\d+)-iter-(\d+)\.res', res_file.name)
        if not match:
            continue

        nblocks = int(match.group(1))
        results = parse_result_file(res_file)

        for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']:
            if key in results:
                data_by_blocks[nblocks][key].append(results[key])

    # Generate comparison table
    print("# Sequential vs Random I/O Performance Comparison\n")
    print("## Complete Performance Table\n")
    print("| Blocks | Size (MB) | Seq Read (ms) | Rand Read (ms) | Δ Read (ms) | Δ Read (%) | Seq Write (ms) | Rand Write (ms) | Δ Write (ms) | Δ Write (%) |")
    print("|--------|-----------|---------------|----------------|-------------|------------|----------------|-----------------|--------------|-------------|")

    for nblocks in sorted(data_by_blocks.keys()):
        data = data_by_blocks[nblocks]

        if not all(data[key] for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']):
            continue

        # Remove outliers
        seq_read = remove_outliers(data['seq_read'])
        seq_write = remove_outliers(data['seq_write'])
        rand_read = remove_outliers(data['rand_read'])
        rand_write = remove_outliers(data['rand_write'])

        if not all([seq_read, seq_write, rand_read, rand_write]):
            continue

        # Calculate means and standard deviations
        seq_read_mean = statistics.mean(seq_read)
        seq_read_std = statistics.stdev(seq_read)
        seq_write_mean = statistics.mean(seq_write)
        seq_write_std = statistics.stdev(seq_write)
        rand_read_mean = statistics.mean(rand_read)
        rand_read_std = statistics.stdev(rand_read)
        rand_write_mean = statistics.mean(rand_write)
        rand_write_std = statistics.stdev(rand_write)

        # Calculate differences
        read_diff_ms = rand_read_mean - seq_read_mean
        read_diff_pct = ((rand_read_mean / seq_read_mean) - 1) * 100 if seq_read_mean > 0 else 0
        write_diff_ms = rand_write_mean - seq_write_mean
        write_diff_pct = ((rand_write_mean / seq_write_mean) - 1) * 100 if seq_write_mean > 0 else 0

        size_mb = nblocks * 8 // 1024

        print(f"| {nblocks:,} | {size_mb:,} | "
              f"{seq_read_mean:.2f} ± {seq_read_std:.2f} | "
              f"{rand_read_mean:.2f} ± {rand_read_std:.2f} | "
              f"{read_diff_ms:+.2f} | {read_diff_pct:+.1f}% | "
              f"{seq_write_mean:.2f} ± {seq_write_std:.2f} | "
              f"{rand_write_mean:.2f} ± {rand_write_std:.2f} | "
              f"{write_diff_ms:+.2f} | {write_diff_pct:+.1f}% |")

    # Per-page performance table
    print("\n## Per-Page Performance (µs/page)\n")
    print("| Blocks | Size (MB) | Seq Read | Rand Read | Δ (µs) | Seq Write | Rand Write | Δ (µs) |")
    print("|--------|-----------|----------|-----------|--------|-----------|------------|--------|")

    for nblocks in sorted(data_by_blocks.keys()):
        data = data_by_blocks[nblocks]

        if not all(data[key] for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']):
            continue

        seq_read = remove_outliers(data['seq_read'])
        seq_write = remove_outliers(data['seq_write'])
        rand_read = remove_outliers(data['rand_read'])
        rand_write = remove_outliers(data['rand_write'])

        if not all([seq_read, seq_write, rand_read, rand_write]):
            continue

        # Calculate per-page latencies in microseconds
        seq_read_per_page = (statistics.mean(seq_read) * 1000) / nblocks
        rand_read_per_page = (statistics.mean(rand_read) * 1000) / nblocks
        seq_write_per_page = (statistics.mean(seq_write) * 1000) / nblocks
        rand_write_per_page = (statistics.mean(rand_write) * 1000) / nblocks

        read_diff_us = rand_read_per_page - seq_read_per_page
        write_diff_us = rand_write_per_page - seq_write_per_page

        size_mb = nblocks * 8 // 1024

        print(f"| {nblocks:,} | {size_mb:,} | "
              f"{seq_read_per_page:.3f} | {rand_read_per_page:.3f} | {read_diff_us:+.3f} | "
              f"{seq_write_per_page:.3f} | {rand_write_per_page:.3f} | {write_diff_us:+.3f} |")

    # Summary statistics
    print("\n## Summary Statistics\n")

    all_read_ratios = []
    all_write_ratios = []

    for nblocks in sorted(data_by_blocks.keys()):
        data = data_by_blocks[nblocks]

        if not all(data[key] for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']):
            continue

        seq_read = remove_outliers(data['seq_read'])
        seq_write = remove_outliers(data['seq_write'])
        rand_read = remove_outliers(data['rand_read'])
        rand_write = remove_outliers(data['rand_write'])

        if not all([seq_read, seq_write, rand_read, rand_write]):
            continue

        read_ratio = statistics.mean(rand_read) / statistics.mean(seq_read)
        write_ratio = statistics.mean(rand_write) / statistics.mean(seq_write)

        all_read_ratios.append(read_ratio)
        all_write_ratios.append(write_ratio)

    if all_read_ratios and all_write_ratios:
        print(f"**Random Read Performance:**")
        print(f"- Mean slowdown: {statistics.mean(all_read_ratios):.3f}x")
        print(f"- Median slowdown: {statistics.median(all_read_ratios):.3f}x")
        print(f"- Range: {min(all_read_ratios):.3f}x to {max(all_read_ratios):.3f}x")
        print(f"- Mean overhead: {(statistics.mean(all_read_ratios) - 1) * 100:.1f}%\n")

        print(f"**Random Write Performance:**")
        print(f"- Mean slowdown: {statistics.mean(all_write_ratios):.3f}x")
        print(f"- Median slowdown: {statistics.median(all_write_ratios):.3f}x")
        print(f"- Range: {min(all_write_ratios):.3f}x to {max(all_write_ratios):.3f}x")
        print(f"- Mean overhead: {(statistics.mean(all_write_ratios) - 1) * 100:.1f}%\n")

if __name__ == '__main__':
    main()
