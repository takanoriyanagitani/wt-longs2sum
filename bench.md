# Simple Benchmark

| unroll  | real | user | sys  | rss  | rate       | ratio  | opt | CPU% |
|:-------:|:----:|:----:|:----:|:----:|:----------:|:------:|:---:|:----:|
| yes(8x) | 3.05 | 0.86 | 1.07 | 8.2M | 5.25 GiB/s |  112%  | yes |  63% |
| yes(8x) | 3.20 | 0.88 | 1.13 | 7.7M | 5.00 GiB/s |  107%  | no  |  63% |
| no      | 3.38 | 1.48 | 1.03 | 8.1M | 4.73 GiB/s |  101%  | yes |  74% |
| no      | 3.42 | 1.49 | 1.05 | 7.7M | 4.68 GiB/s | (100%) | no  |  74% |

- CPU: M3 Max
- RAM: 48 GB
- Runtime: wazero v1.12.0
