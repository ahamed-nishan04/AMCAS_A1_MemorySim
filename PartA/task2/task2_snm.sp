* AMCAS TakeHomeLab Task 2 - read/hold static noise margin
* Half-cell VTC: drive Q, measure QB, access device tied to a bitline held at VDD.
* Produces three VTCs -> feed to snm_extract.py for the butterfly + largest square.
.include ../45nm_bulk.txt $ PTM BSIM4 card

.param VDD=1.1

Vdd  vdd 0 'VDD'
Vwl  wl  0 'VDD'       $ wordline ON  -> read VTC (set to 0 for hold, see .control)
Vblb blb 0 'VDD'       $ bitline clamped high: worst case for read stability
Vin  q   0 0           $ swept

MP1 qb q   vdd vdd pmos W=0.15u L=0.045u
MN1 qb q   0   0   nmos W=0.20u L=0.045u
MA2 blb wl qb  0   nmos W=0.16u L=0.045u

.control
   dc Vin 0 1.1 0.002
   wrdata vtc_read_016.csv v(qb)

   alter @ma2[w]=0.24u
   dc Vin 0 1.1 0.002
   wrdata vtc_read_024.csv v(qb)

   alter @ma2[w]=0.16u
   alter Vwl 0                 $ wordline OFF -> hold VTC
   dc Vin 0 1.1 0.002
   wrdata vtc_hold.csv v(qb)
.endc
.end
