# Random vs Sequential I/O Performance Analysis

## Summary Table

| Blocks | Seq Read (ms) | Rand Read (ms) | Ratio | Seq Write (ms) | Rand Write (ms) | Ratio |
|--------|---------------|----------------|-------|----------------|-----------------|-------|
| 128 | 0.18 | 0.18 | 0.97x | 0.18 | 0.16 | 0.89x |
| 256 | 0.29 | 0.27 | 0.96x | 0.28 | 0.27 | 0.94x |
| 512 | 0.55 | 0.54 | 0.98x | 0.54 | 0.47 | 0.88x |
| 1,024 | 1.06 | 1.15 | 1.09x | 1.01 | 1.10 | 1.09x |
| 2,048 | 2.40 | 2.52 | 1.05x | 3.02 | 3.02 | 1.00x |
| 4,096 | 4.69 | 5.12 | 1.09x | 6.50 | 6.37 | 0.98x |
| 8,192 | 9.40 | 10.66 | 1.13x | 12.43 | 13.16 | 1.06x |
| 16,384 | 19.27 | 22.13 | 1.15x | 25.25 | 27.81 | 1.10x |
| 32,768 | 39.64 | 45.56 | 1.15x | 50.70 | 58.95 | 1.16x |
| 65,536 | 86.41 | 97.91 | 1.13x | 102.31 | 120.81 | 1.18x |
| 131,072 | 168.19 | 207.62 | 1.23x | 205.77 | 247.92 | 1.20x |
| 262,144 | 359.65 | 447.12 | 1.24x | 415.87 | 512.79 | 1.23x |

## Detailed Statistics by Block Size

### 128 Blocks (1 MB)

**Sequential Read:**
- Mean: 0.18 ms (±0.02)
- Median: 0.18 ms
- Range: [0.14, 0.23]
- Samples: 28

**Random Read:**
- Mean: 0.18 ms (±0.02)
- Median: 0.17 ms
- Range: [0.14, 0.24]
- Samples: 29
- **Slowdown: 0.97x**

**Sequential Write:**
- Mean: 0.18 ms (±0.01)
- Median: 0.18 ms
- Range: [0.15, 0.21]
- Samples: 29

**Random Write:**
- Mean: 0.16 ms (±0.01)
- Median: 0.16 ms
- Range: [0.14, 0.19]
- Samples: 29
- **Slowdown: 0.89x**

### 256 Blocks (2 MB)

**Sequential Read:**
- Mean: 0.29 ms (±0.01)
- Median: 0.28 ms
- Range: [0.26, 0.32]
- Samples: 28

**Random Read:**
- Mean: 0.27 ms (±0.01)
- Median: 0.27 ms
- Range: [0.26, 0.29]
- Samples: 28
- **Slowdown: 0.96x**

**Sequential Write:**
- Mean: 0.28 ms (±0.01)
- Median: 0.28 ms
- Range: [0.26, 0.31]
- Samples: 28

**Random Write:**
- Mean: 0.27 ms (±0.00)
- Median: 0.27 ms
- Range: [0.26, 0.27]
- Samples: 28
- **Slowdown: 0.94x**

### 512 Blocks (4 MB)

**Sequential Read:**
- Mean: 0.55 ms (±0.05)
- Median: 0.54 ms
- Range: [0.47, 0.67]
- Samples: 29

**Random Read:**
- Mean: 0.54 ms (±0.04)
- Median: 0.52 ms
- Range: [0.49, 0.64]
- Samples: 29
- **Slowdown: 0.98x**

**Sequential Write:**
- Mean: 0.54 ms (±0.04)
- Median: 0.53 ms
- Range: [0.47, 0.63]
- Samples: 29

**Random Write:**
- Mean: 0.47 ms (±0.02)
- Median: 0.47 ms
- Range: [0.45, 0.52]
- Samples: 27
- **Slowdown: 0.88x**

### 1,024 Blocks (8 MB)

**Sequential Read:**
- Mean: 1.06 ms (±0.04)
- Median: 1.04 ms
- Range: [1.01, 1.15]
- Samples: 28

**Random Read:**
- Mean: 1.15 ms (±0.08)
- Median: 1.15 ms
- Range: [1.02, 1.35]
- Samples: 29
- **Slowdown: 1.09x**

**Sequential Write:**
- Mean: 1.01 ms (±0.06)
- Median: 0.98 ms
- Range: [0.94, 1.15]
- Samples: 28

**Random Write:**
- Mean: 1.10 ms (±0.15)
- Median: 1.05 ms
- Range: [0.94, 1.38]
- Samples: 29
- **Slowdown: 1.09x**

### 2,048 Blocks (16 MB)

**Sequential Read:**
- Mean: 2.40 ms (±0.12)
- Median: 2.35 ms
- Range: [2.28, 2.69]
- Samples: 29

**Random Read:**
- Mean: 2.52 ms (±0.09)
- Median: 2.48 ms
- Range: [2.42, 2.77]
- Samples: 28
- **Slowdown: 1.05x**

**Sequential Write:**
- Mean: 3.02 ms (±0.11)
- Median: 3.01 ms
- Range: [2.86, 3.41]
- Samples: 29

**Random Write:**
- Mean: 3.02 ms (±0.08)
- Median: 3.03 ms
- Range: [2.87, 3.19]
- Samples: 28
- **Slowdown: 1.00x**

### 4,096 Blocks (32 MB)

**Sequential Read:**
- Mean: 4.69 ms (±0.11)
- Median: 4.67 ms
- Range: [4.56, 4.96]
- Samples: 28

**Random Read:**
- Mean: 5.12 ms (±0.05)
- Median: 5.12 ms
- Range: [5.05, 5.22]
- Samples: 28
- **Slowdown: 1.09x**

**Sequential Write:**
- Mean: 6.50 ms (±0.23)
- Median: 6.48 ms
- Range: [6.00, 6.97]
- Samples: 29

**Random Write:**
- Mean: 6.37 ms (±0.15)
- Median: 6.31 ms
- Range: [6.16, 6.71]
- Samples: 28
- **Slowdown: 0.98x**

### 8,192 Blocks (64 MB)

**Sequential Read:**
- Mean: 9.40 ms (±0.16)
- Median: 9.37 ms
- Range: [9.16, 9.73]
- Samples: 29

**Random Read:**
- Mean: 10.66 ms (±0.24)
- Median: 10.58 ms
- Range: [10.36, 11.11]
- Samples: 29
- **Slowdown: 1.13x**

**Sequential Write:**
- Mean: 12.43 ms (±0.25)
- Median: 12.46 ms
- Range: [11.92, 12.87]
- Samples: 29

**Random Write:**
- Mean: 13.16 ms (±0.29)
- Median: 13.11 ms
- Range: [12.75, 13.68]
- Samples: 30
- **Slowdown: 1.06x**

### 16,384 Blocks (128 MB)

**Sequential Read:**
- Mean: 19.27 ms (±0.30)
- Median: 19.24 ms
- Range: [18.80, 20.02]
- Samples: 28

**Random Read:**
- Mean: 22.13 ms (±0.67)
- Median: 22.05 ms
- Range: [21.20, 23.54]
- Samples: 29
- **Slowdown: 1.15x**

**Sequential Write:**
- Mean: 25.25 ms (±0.52)
- Median: 25.31 ms
- Range: [24.37, 26.14]
- Samples: 30

**Random Write:**
- Mean: 27.81 ms (±0.42)
- Median: 27.85 ms
- Range: [26.77, 28.68]
- Samples: 29
- **Slowdown: 1.10x**

### 32,768 Blocks (256 MB)

**Sequential Read:**
- Mean: 39.64 ms (±0.92)
- Median: 39.39 ms
- Range: [38.76, 42.33]
- Samples: 28

**Random Read:**
- Mean: 45.56 ms (±0.66)
- Median: 45.35 ms
- Range: [44.52, 46.92]
- Samples: 28
- **Slowdown: 1.15x**

**Sequential Write:**
- Mean: 50.70 ms (±0.67)
- Median: 50.53 ms
- Range: [49.49, 52.05]
- Samples: 28

**Random Write:**
- Mean: 58.95 ms (±1.60)
- Median: 58.75 ms
- Range: [56.27, 63.13]
- Samples: 29
- **Slowdown: 1.16x**

### 65,536 Blocks (512 MB)

**Sequential Read:**
- Mean: 86.41 ms (±2.06)
- Median: 86.63 ms
- Range: [79.96, 90.37]
- Samples: 28

**Random Read:**
- Mean: 97.91 ms (±3.59)
- Median: 96.25 ms
- Range: [94.76, 109.21]
- Samples: 28
- **Slowdown: 1.13x**

**Sequential Write:**
- Mean: 102.31 ms (±2.05)
- Median: 102.39 ms
- Range: [98.67, 108.86]
- Samples: 29

**Random Write:**
- Mean: 120.81 ms (±2.75)
- Median: 119.85 ms
- Range: [117.89, 128.97]
- Samples: 29
- **Slowdown: 1.18x**

### 131,072 Blocks (1024 MB)

**Sequential Read:**
- Mean: 168.19 ms (±2.73)
- Median: 168.39 ms
- Range: [163.55, 173.63]
- Samples: 29

**Random Read:**
- Mean: 207.62 ms (±1.81)
- Median: 207.38 ms
- Range: [204.90, 214.03]
- Samples: 29
- **Slowdown: 1.23x**

**Sequential Write:**
- Mean: 205.77 ms (±4.89)
- Median: 204.68 ms
- Range: [197.36, 223.18]
- Samples: 29

**Random Write:**
- Mean: 247.92 ms (±2.80)
- Median: 247.79 ms
- Range: [242.74, 256.20]
- Samples: 28
- **Slowdown: 1.20x**

### 262,144 Blocks (2048 MB)

**Sequential Read:**
- Mean: 359.65 ms (±25.59)
- Median: 346.91 ms
- Range: [335.78, 423.20]
- Samples: 28

**Random Read:**
- Mean: 447.12 ms (±11.11)
- Median: 443.85 ms
- Range: [424.94, 472.12]
- Samples: 29
- **Slowdown: 1.24x**

**Sequential Write:**
- Mean: 415.87 ms (±9.10)
- Median: 416.13 ms
- Range: [395.62, 439.45]
- Samples: 28

**Random Write:**
- Mean: 512.79 ms (±5.86)
- Median: 512.92 ms
- Range: [496.68, 524.36]
- Samples: 28
- **Slowdown: 1.23x**

