#!/usr/bin/env python3
"""
Analyze random vs sequential I/O performance from benchmark results.
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

    # Random write (flush after random read)
    # This is the last flush in the file
    matches = list(re.finditer(r'Function Scan on pg_flush_local_buffers.*?Execution Time: ([\d.]+) ms', content, re.DOTALL))
    if len(matches) >= 4:  # We want the last one (random write)
        results['rand_write'] = float(matches[-1].group(1))

    return results

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
        # Extract block count from filename
        match = re.match(r'blocks-(\d+)-iter-(\d+)\.res', res_file.name)
        if not match:
            continue

        nblocks = int(match.group(1))
        iteration = int(match.group(2))

        results = parse_result_file(res_file)

        for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']:
            if key in results:
                data_by_blocks[nblocks][key].append(results[key])

    # Analyze and print results
    print("# Random vs Sequential I/O Performance Analysis\n")
    print("## Summary Table\n")
    print("| Blocks | Seq Read (ms) | Rand Read (ms) | Ratio | Seq Write (ms) | Rand Write (ms) | Ratio |")
    print("|--------|---------------|----------------|-------|----------------|-----------------|-------|")

    for nblocks in sorted(data_by_blocks.keys()):
        data = data_by_blocks[nblocks]

        if not all(data[key] for key in ['seq_read', 'seq_write', 'rand_read', 'rand_write']):
            continue

        # Remove outliers (beyond 2 stddev)
        def remove_outliers(values):
            if len(values) < 3:
                return values
            mean = statistics.mean(values)
            stdev = statistics.stdev(values)
            return [v for v in values if abs(v - mean) <= 2 * stdev]

        seq_read = remove_outliers(data['seq_read'])
        seq_write = remove_outliers(data['seq_write'])
        rand_read = remove_outliers(data['rand_read'])
        rand_write = remove_outliers(data['rand_write'])

        if not all([seq_read, seq_write, rand_read, rand_write]):
            continue

        seq_read_avg = statistics.mean(seq_read)
        seq_write_avg = statistics.mean(seq_write)
        rand_read_avg = statistics.mean(rand_read)
        rand_write_avg = statistics.mean(rand_write)

        read_ratio = rand_read_avg / seq_read_avg if seq_read_avg > 0 else 0
        write_ratio = rand_write_avg / seq_write_avg if seq_write_avg > 0 else 0

        print(f"| {nblocks:,} | {seq_read_avg:.2f} | {rand_read_avg:.2f} | {read_ratio:.2f}x | "
              f"{seq_write_avg:.2f} | {rand_write_avg:.2f} | {write_ratio:.2f}x |")

    # Detailed statistics
    print("\n## Detailed Statistics by Block Size\n")

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

        print(f"### {nblocks:,} Blocks ({nblocks * 8 // 1024} MB)\n")

        print(f"**Sequential Read:**")
        print(f"- Mean: {statistics.mean(seq_read):.2f} ms (±{statistics.stdev(seq_read):.2f})")
        print(f"- Median: {statistics.median(seq_read):.2f} ms")
        print(f"- Range: [{min(seq_read):.2f}, {max(seq_read):.2f}]")
        print(f"- Samples: {len(seq_read)}\n")

        print(f"**Random Read:**")
        print(f"- Mean: {statistics.mean(rand_read):.2f} ms (±{statistics.stdev(rand_read):.2f})")
        print(f"- Median: {statistics.median(rand_read):.2f} ms")
        print(f"- Range: [{min(rand_read):.2f}, {max(rand_read):.2f}]")
        print(f"- Samples: {len(rand_read)}")
        print(f"- **Slowdown: {statistics.mean(rand_read)/statistics.mean(seq_read):.2f}x**\n")

        print(f"**Sequential Write:**")
        print(f"- Mean: {statistics.mean(seq_write):.2f} ms (±{statistics.stdev(seq_write):.2f})")
        print(f"- Median: {statistics.median(seq_write):.2f} ms")
        print(f"- Range: [{min(seq_write):.2f}, {max(seq_write):.2f}]")
        print(f"- Samples: {len(seq_write)}\n")

        print(f"**Random Write:**")
        print(f"- Mean: {statistics.mean(rand_write):.2f} ms (±{statistics.stdev(rand_write):.2f})")
        print(f"- Median: {statistics.median(rand_write):.2f} ms")
        print(f"- Range: [{min(rand_write):.2f}, {max(rand_write):.2f}]")
        print(f"- Samples: {len(rand_write)}")
        print(f"- **Slowdown: {statistics.mean(rand_write)/statistics.mean(seq_write):.2f}x**\n")

if __name__ == '__main__':
    main()
