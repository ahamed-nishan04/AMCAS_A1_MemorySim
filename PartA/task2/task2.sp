* AMCAS TakeHomeLab Task 2 - 6T read: access transistors widened to 0.24u
* Q=0, QB=1 stored. Cell ratio = 0.20/0.24 = 0.83
.include ../45nm_bulk.txt $ PTM BSIM4 card

.param VDD=1.1 VBL=1.1
.param WACC=0.24u          $ access transistor width (Task 2: widened from 0.16u)

Vdd vdd 0 'VDD'
Vwl wl  0 PWL(0 0 1n 0 1.05n 'VDD')

MP1 qb q  vdd vdd pmos W=0.15u  L=0.045u
MN1 qb q  0   0   nmos W=0.20u  L=0.045u
MP2 q  qb vdd vdd pmos W=0.15u  L=0.045u
MN2 q  qb 0   0   nmos W=0.20u  L=0.045u
MA1 bl  wl q  0   nmos W='WACC' L=0.045u
MA2 blb wl qb 0   nmos W='WACC' L=0.045u

Cbl  bl  0 180f IC='VBL'
Cblb blb 0 180f IC='VBL'

.ic v(q)=0 v(qb)='VDD'

.control
   tran 5p 4n uic

   let dvbl = v(blb)-v(bl)          $ FIND cannot take an expression - needs a vector

   meas tran dv    FIND dvbl AT=2.0n    $ assignment measurement point

   meas tran qmax  MAX  v(q) FROM=1n TO=4n
   meas tran qfin  FIND v(q)  AT=4n
   meas tran qbfin FIND v(qb) AT=4n

   plot v(q) v(qb) v(bl) v(blb) xlimit 0.5n 4n
   wrdata read2.csv v(bl) v(blb) v(q) v(qb)
.endc
.end
