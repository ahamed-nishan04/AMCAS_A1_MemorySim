* AMCAS TakeHomeLab Task 4 - Task 1 repeated at 85 C
* Q=0, QB=1 stored. Compares the 27 C and 85 C read transients, then re-runs the
* Task 3 VDD sweep at 85 C to see where the 25 mV sense-amp offset now bites.
.include ../45nm_bulk.txt $ PTM BSIM4 card

.param VDD=1.1 VBL=1.1
.param WACC=0.16u

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
   set noaskquit

*  IMPORTANT: every vector that must survive across analyses is created HERE,
*  before the first tran. Each tran makes tran<N> the current plot, and vectors
*  created after that die with it. Declaring them first puts them in the const
*  plot, which stays reachable throughout the run.
   let nsteps = 11
   let n      = 0
   let vnow   = 0            $ must exist in const before the loop, see note
   let vsweep = unitvec(nsteps)
   let dv_s85 = unitvec(nsteps)
   let r      = unitvec(8)   $ 0,1 dV@2n | 2,3 dV@65ps | 4,5 qmax | 6,7 v(Q)@4n

* ---------------------------------------------------------------- Part A
* Task 1 measurements at 27 C and 85 C, nominal VDD = 1.1 V
* ------------------------------------------------------------------------
   option temp=27
   tran 5p 4n uic
   let dvbl = v(blb)-v(bl)
   meas tran dv27   FIND dvbl AT=2.0n       $ assignment measurement point
   meas tran dvs27  FIND dvbl AT=1.115n     $ 65 ps sense window
   meas tran qmx27  MAX  v(q) FROM=1n TO=4n
   meas tran qfn27  FIND v(q) AT=4n
   let r[0] = dv27
   let r[2] = dvs27
   let r[4] = qmx27
   let r[6] = qfn27

   option temp=85
   tran 5p 4n uic
   let dvbl = v(blb)-v(bl)
   meas tran dv85   FIND dvbl AT=2.0n
   meas tran dvs85  FIND dvbl AT=1.115n
   meas tran qmx85  MAX  v(q) FROM=1n TO=4n
   meas tran qfn85  FIND v(q) AT=4n
   let r[1] = dv85
   let r[3] = dvs85
   let r[5] = qmx85
   let r[7] = qfn85

   echo ""
   echo "---- Task 1 repeated at 85 C, VDD = 1.1 V ----"
   echo "         27 C          85 C"
   print r[0] r[1]      $ dV at t = 2.0 ns
   print r[2] r[3]      $ dV at the 65 ps sense window
   print r[4] r[5]      $ read disturb peak, qmax
   print r[6] r[7]      $ v(Q) at 4 ns

* ---------------------------------------------------------------- Part B
* Task 3 VDD sweep re-run at 85 C: where does dV cross the 25 mV offset now?
* ------------------------------------------------------------------------
   option temp=85
   let n = 0
   while n < nsteps
      let vnow = 1.1 - n * 0.05
      alter Vdd       = vnow
      alter @cbl[ic]  = vnow
      alter @cblb[ic] = vnow
      alter Vwl pwl = [ 0 0 1n 0 1.05n $&vnow ]

      tran 5p 4n uic
      let dvbl = v(blb)-v(bl)
      meas tran m_dvs FIND dvbl AT=1.115n

      let vsweep[n] = vnow
      let dv_s85[n] = m_dvs
      let n = n + 1
   end

   setplot const                     $ sweep vectors live in the const plot
   setscale vsweep

   let offset = 0.025 * unitvec(nsteps)   $ 25 mV sense-amp offset, Lecture 5

   let k = 0
   let vcross85 = 0
   while k < nsteps-1
      if (dv_s85[k] >= 0.025) & (dv_s85[k+1] < 0.025)
         let vcross85 = vsweep[k] - 0.05 * (dv_s85[k]-0.025) / (dv_s85[k]-dv_s85[k+1])
      end
      let k = k + 1
   end

   echo ""
   echo "---- VDD at which dV crosses the 25 mV offset, 85 C ----"
   print vcross85

   plot dv_s85 offset vs vsweep
   +    xlabel 'VDD (V)' ylabel 'dV(BLB-BL) at 65 ps window (V)'
   +    title 'Task 4: sense margin vs supply at 85 C'

   wrdata task4_sweep.csv dv_s85
.endc
.end
