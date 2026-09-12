* AMCAS TakeHomeLab Task 1 - 6T read: bitline discharge and sense margin
* Q=0, QB=1 stored. Cell ratio = 0.20/0.16 = 1.25
.include ../45nm_bulk.txt $ PTM BSIM4 card

.param VDD=1.1 VBL=1.1
.param WACC=0.16u          $ access transistor width

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
   meas tran dv_s  FIND dvbl AT=1.115n  $ Lecture-1 sense instant (~65 ps after WL)
   meas tran qmax  MAX  v(q) FROM=1n TO=4n
   meas tran qfin  FIND v(q)  AT=4n
   meas tran qbfin FIND v(qb) AT=4n

   plot v(q) v(qb) v(bl) v(blb) xlimit 0.5n 4n
   wrdata read1.csv v(bl) v(blb) v(q) v(qb)
.endc
.end
