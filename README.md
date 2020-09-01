# HaloResolv-DynamicPRSNT

Vices of Halo Resolution:

1) OUTLEN is variable
2) RAMCNT is variable
3) HALOLENGTH is variable
4) NUMFRAMES is variable
5) LEFT and UP resolve
6) EOS may be greater or smaller than FRAMELEN
7) TILE DIMENSIONS  may not be equal. (Non-square HALOLENGTH and OUTLEN)

Accelerator Hardware constraints:

1) Max use of underlying architecture (dual port rams)
2) Light-weight (Multiple instances)
3) Low-latency (Because accelerator)
4) Reuse (Efficiency of area and maximal commitment of resources.

========================================================

Prelude:

0) Why Halos
1) Pseudo 3D convolution

Main:

0) Tiles.
1) Halos in a single tile.
2) Advantage of uniformity: Multiple tiles share the same assortement, Resolution in tiles is natural.
3) RAMs - Dual Port
4) Halo arrangement in RAMs.
	-- Advantages: (uniform, compact)
	-- Disadvantage: (Haphazard Seeming)
5) Resolution in Hardware.
6) Datapath.

Extra:

0) Critical path optimization, parameterized latency.
1) RAM implementation tricks
2) Throughput parameterization, variables of throughput
3) Argument of high throughput: max usage of dual port RAMS
4) Further speed up tactics (Top/Left parallelization)
